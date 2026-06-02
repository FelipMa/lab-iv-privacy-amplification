`timescale 1ns / 1ps

module top #(
    // Parâmetros Globais do Privacy Amplification
    parameter N = 640,
    parameter W = 64,
    parameter P = 32,
    parameter L = 64,
    parameter ROM_ADDR_BITS = 5,
    parameter LUT_DEPTH = 5,
	 parameter MEM_DEPTH = 32
)(
    input wire clock,
    input wire reset,     
    output reg [(P-1):0] hash_register,
    output reg batch_ready, 
    output reg done
);

    localparam CYCLES = (N + W - 1) / W;
    localparam BATCHES = (L + P - 1) / P;

    reg reset_sync_0, sys_reset;
    always @(posedge clock) begin
        reset_sync_0 <= reset;
        sys_reset    <= reset_sync_0;
    end             

	 wire [(ROM_ADDR_BITS-1):0] rom_key_addr;
	 wire [(W-1):0] rom_key_q;
	 
    wire buf_ready, buf_out_valid, buf_done;
    wire [(W-1):0] buf_out_data;
    
    reg buf_prepare, buf_go;

    Input_Buffer #(
        .DEPTH(CYCLES),        
        .ADDR_BITS(ROM_ADDR_BITS),         
        .DATA_BITS(W),         
        .REPEAT_COUNT(BATCHES)       
    ) u_input_buffer (
        .clk(clock),
        .rst_n(!sys_reset),    
        .prepare(buf_prepare),
        .go(buf_go),
        .rom_q(rom_key_q),
        .rom_addr(rom_key_addr),
        .rom_clock(),          
        .out_data(buf_out_data),
        .out_valid(buf_out_valid),
        .ready_to_stream(buf_ready),
        .done(buf_done)
    );
     
     
    reg [(LUT_DEPTH-1):0] matrix_addr_reg;
    wire [(W+P-2):0] current_matrix_window;

    matrix_lut u_matrix_lut(
        .clock(clock),
        .address(matrix_addr_reg),
        .q(current_matrix_window)
    );
	 
	 
	 rom_key #(
        .DATA_BITS(W),
        .ADDR_BITS(ROM_ADDR_BITS),
        .DEPTH(MEM_DEPTH)       
    ) uut_rom_key (
        .address (rom_key_addr),
        .clock   (clock),
        .q       (rom_key_q)
    );
	 

    reg clear_acc, enable;
 
    wire [(W-1):0] safe_key = buf_out_valid ? buf_out_data : {W{1'b0}};
    wire [(W+P-2):0] safe_window = buf_out_valid ? current_matrix_window : {(W+P-1){1'b0}};
    
    wire [(P-1):0] current_hash_out;

    compression_unit #(
        .P(P),
        .W(W)
    ) u_compression_unit(
        .clock(clock),
        .reset(sys_reset),
        .clear_acc(clear_acc),
        .enable(enable),
        .key(safe_key), 
        .matrix_window(safe_window),
        .hash_out(current_hash_out)
    );


    localparam S_IDLE       = 4'd0;
    localparam S_PREPARE    = 4'd1;
    localparam S_WAIT_RDY   = 4'd2;
    localparam S_RUN        = 4'd3;
    localparam S_BATCH_DONE = 4'd4;
    localparam S_DONE       = 4'd5;

    reg [3:0] current_state, next_state;
     
    localparam WORD_BITS = $clog2(CYCLES);
    localparam BATCH_BITS = $clog2(BATCHES);
     
    reg [BATCH_BITS:0] batch_idx;
    reg [WORD_BITS:0] words_idx; 
         
    always @(posedge clock) begin
        if (sys_reset) begin
            current_state <= S_IDLE;
            batch_idx <= 0;
            words_idx <= 0;
            matrix_addr_reg <= 0;
            hash_register <= 0;
            buf_prepare <= 0;
            buf_go <= 0;
            done <= 0;
            clear_acc <= 0;
            batch_ready <= 0;
        end else begin
            current_state <= next_state;
            case(current_state)
                S_PREPARE: begin
                    buf_prepare <= 1;
                end     
                S_WAIT_RDY: begin
                    buf_prepare <= 0;                  
                    if (buf_ready) buf_go <= 1;
                end
                S_RUN: begin
                    batch_ready <= 0;
                    
                    if(words_idx < CYCLES) begin
                        matrix_addr_reg <= matrix_addr_reg + 1;
                        words_idx <= words_idx + 1;
                    end
                    
                    clear_acc <= 0;
                
                    if (words_idx == CYCLES - 1) begin
                        buf_go <= 0;
                    end else begin
                        buf_go <= 1;
                    end         
                    
                    if(batch_idx && (words_idx == 1)) begin
                        hash_register <= current_hash_out;
                        batch_ready <= 1;
                    end
                    
                end
                S_BATCH_DONE: begin
                    if (batch_idx < BATCHES - 1) begin
                        batch_idx <= batch_idx + 1;
                        words_idx <= 1;
                        clear_acc <= 1;
                        buf_go <= 1;
                        matrix_addr_reg <= matrix_addr_reg + 1;
                    end
                end
                S_DONE: begin
                    hash_register <= current_hash_out;
                    batch_ready <= 1;
                    done <= 1;
                end
            endcase
        end
    end
     
    always @(*) begin
        next_state = current_state;
        enable = 0;
        case(current_state)         
            S_IDLE: begin
                if (!done) begin
                    next_state = S_PREPARE;
                end
            end

            S_PREPARE: begin
                next_state  = S_WAIT_RDY;
            end

            S_WAIT_RDY: begin
                if (buf_ready) begin
                    next_state = S_RUN;
                end
            end

            S_RUN: begin 
                if(words_idx == CYCLES) begin
                    next_state = S_BATCH_DONE;
                end
                enable = 1'b1;
            end
            S_BATCH_DONE: begin
                if(batch_idx == BATCHES - 1) begin
                    next_state = S_DONE;
                end else begin
                    next_state = S_RUN;
                end
                enable = 1'b1;
            end
            default: next_state = S_IDLE;
        endcase
    end

// =========================================================================
    // SINAIS E INSTANCIAÇÃO COMPATÍVEL DA RAM NATIVA DE DUMP
    // =========================================================================

    reg [BATCH_BITS:0] ram_write_addr;
    wire ram_we;

    // Dispara a escrita na RAM assim que um lote estabilizar na saída
    assign ram_we = (batch_ready || done) && (ram_write_addr < BATCHES);

    always @(posedge clock) begin
        if (sys_reset) begin
            ram_write_addr <= 0;
        end else if (ram_we) begin
            ram_write_addr <= ram_write_addr + 1;
        end
    end

    ram_dump #(
        .DATA_BITS(P),               
        .ADDR_BITS(BATCH_BITS + 1)   
    ) u_ram_dump (
        .clock   (clock),
        .we      (ram_we),
        .address (ram_write_addr),
        .data_in (hash_register)
    );

endmodule