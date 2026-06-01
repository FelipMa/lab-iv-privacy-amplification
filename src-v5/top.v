module top #(
    parameter N = 128,
    parameter W = 32,
    parameter P = 32,
    parameter L = 64,
    parameter ROM_ADDR_BITS = 2, // Cobrir CYCLES_PER_BATCH = 4
    parameter LUT_ADDR_BITS = 3  // Cobrir CYCLES_PER_BATCH * BATCHES = 8 posições
)(
    input wire clock,
    input wire reset,	 

    // Saída de Controle
    output reg done
);
    localparam CYCLES_PER_BATCH = (N + W - 1) / W;
    localparam BATCHES = (L + P - 1) / P;

    reg [(P-1):0] hash_register;
    reg batch_ready;

    // =========================================================================
    // Sinais internos para a Memória ROM (Chaves)
    // =========================================================================
    wire [(ROM_ADDR_BITS-1):0] rom_addr;
    wire [(W-1):0] rom_q;

    // Instanciação da ALTSYNCRAM configurada como ROM
    altsyncram #(
        .operation_mode("ROM"),
        .width_a(W),
        .widthad_a(ROM_ADDR_BITS),
        .numwords_a(CYCLES_PER_BATCH),
        .outdata_reg_a("UNREGISTERED"),
        .lpm_type("altsyncram"),
        .init_file("key.mif")
    ) key_rom (
        .clock0 (clock),
        .address_a (rom_addr),
        .q_a (rom_q)
    );

    wire buf_ready, buf_out_valid, buf_done;
    wire [(W-1):0] buf_out_data;
    
    reg buf_prepare, buf_go;

    input_buffer #(
        .DEPTH(CYCLES_PER_BATCH),        
        .ADDR_BITS(ROM_ADDR_BITS),         
        .DATA_BITS(W),         
        .REPEAT_COUNT(BATCHES)       
    ) u_input_buffer (
        .clk(clock),
        .rst_n(!reset),
        .prepare(buf_prepare),
        .go(buf_go),
        .rom_q(rom_q),
        .rom_addr(rom_addr),
        .rom_clock(),          
        .out_data(buf_out_data),
        .out_valid(buf_out_valid),
        .ready_to_stream(buf_ready),
        .done(buf_done)
    );

    reg [(LUT_ADDR_BITS-1):0] matrix_addr_reg;
    wire [(W+P-2):0] current_matrix_window;

    matrix_lut u_matrix_lut(
        .clock(clock),
        .address(matrix_addr_reg),
        .q(current_matrix_window)
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
        .reset(reset),
        .enable(enable),
        .clear_acc(clear_acc),
        .key(safe_key), 
        .matrix_window(safe_window),
        .hash_out(current_hash_out)
    );

    // =========================================================================
    // Configuração da ALTSYNCRAM para armazenar os hashes finalizados
    // =========================================================================
    localparam RAM_ADDR_BITS = (BATCHES > 1) ? $clog2(BATCHES) : 1;
    reg [RAM_ADDR_BITS-1:0] ram_addr_reg;

    altsyncram #(
        .operation_mode("SINGLE_PORT"),
        .width_a(P),                     
        .widthad_a(RAM_ADDR_BITS),          
        .numwords_a(BATCHES),     
        .outdata_reg_a("UNREGISTERED"),
        .lpm_type("altsyncram"),
        .lpm_hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=RES") 
    ) result_ram (
        .clock0 (clock),
        .wren_a (batch_ready),
        .address_a (ram_addr_reg),
        .data_a (hash_register),
        .q_a ()
    );

    localparam S_IDLE       = 4'd0;
    localparam S_PREPARE    = 4'd1;
    localparam S_WAIT_RDY   = 4'd2;
    localparam S_RUN        = 4'd3;
    localparam S_BATCH_DONE = 4'd4;
    localparam S_DONE       = 4'd5;

    reg [3:0] current_state, next_state;

    localparam WORD_BITS = $clog2(CYCLES_PER_BATCH);
    localparam BATCH_BITS = $clog2(BATCHES);
	 
    reg [BATCH_BITS:0] batch_idx;
    reg [WORD_BITS:0] words_idx;

    always @(posedge clock) begin
        if (reset) begin
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
            ram_addr_reg <= 0;
        end else begin
            current_state <= next_state;

            if (batch_ready) begin
                ram_addr_reg <= ram_addr_reg + 1;
            end

            case(current_state)
                S_IDLE: begin
                    batch_ready <= 0;
                end
                S_PREPARE: begin
                    buf_prepare <= 1;
                end		
                S_WAIT_RDY: begin
                    buf_prepare <= 0;
                    if (buf_ready) buf_go <= 1;
                end
                S_RUN: begin
                    batch_ready <= 0;
                    if(words_idx < CYCLES_PER_BATCH) begin
                        matrix_addr_reg <= matrix_addr_reg + 1;
                        words_idx <= words_idx + 1;
                    end
                    
                    clear_acc <= 0;
                    if (words_idx == CYCLES_PER_BATCH - 1) begin
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
                if(words_idx == CYCLES_PER_BATCH) begin
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

endmodule