`timescale 1ns / 1ps

module controlador #(
    parameter N         = 640,
    parameter W         = 64,
    parameter P         = 32,
    parameter L         = 64,
    parameter LUT_DEPTH = 5
)(
    input  wire                   clock,
    input  wire                   reset,

    // Realimentacao dos modulos de dados
    input  wire                   buf_ready,          
    input  wire [(P-1):0]         current_hash_out,

    // Reset sincronizado
    output reg                    sys_reset,

    // Controle do Input_Buffer
    output reg                    buf_prepare,
    output reg                    buf_go,

    // Endereco da janela Toeplitz
    output reg  [(LUT_DEPTH-1):0] matrix_addr_reg,

    // Controle da compression_unit
    output reg                    clear_acc,
    output reg                    enable,

    // Saidas finais
    output reg  [(P-1):0]         hash_register,
    output reg                    batch_ready,
    output reg                    done,
    output wire                          ram_we,
    output reg  [$clog2((L+P-1)/P):0]    ram_address
);	 
    localparam CYCLES     = (N + W - 1) / W;
    localparam BATCHES    = (L + P - 1) / P;
    localparam WORD_BITS  = $clog2(CYCLES);
    localparam BATCH_BITS = $clog2(BATCHES);

    // Sincronizador de reset (2 FF)
	 
    reg reset_sync_0;
    always @(posedge clock) begin
        reset_sync_0 <= reset;
        sys_reset    <= reset_sync_0;
    end


    // Maquina de estados
    
    localparam S_IDLE       = 4'd0;
    localparam S_PREPARE    = 4'd1;
    localparam S_WAIT_RDY   = 4'd2;
    localparam S_RUN        = 4'd3;
    localparam S_BATCH_DONE = 4'd4;
    localparam S_DONE       = 4'd5;

    reg [3:0] current_state, next_state;

    reg [BATCH_BITS:0] batch_idx;
    reg [WORD_BITS:0]  words_idx;

    always @(posedge clock) begin
        if (sys_reset) begin
            current_state   <= S_IDLE;
            batch_idx       <= 0;
            words_idx       <= 0;
            matrix_addr_reg <= 0;
            hash_register   <= 0;
            buf_prepare     <= 0;
            buf_go          <= 0;
            done            <= 0;
            clear_acc       <= 0;
            batch_ready     <= 0;
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

    // Controle de escrita do ram_dump

    assign ram_we = (batch_ready || done) && (ram_address < BATCHES);

    always @(posedge clock) begin
        if (sys_reset) begin
            ram_address <= 0;
        end else if (ram_we) begin
            ram_address <= ram_address + 1;
        end
    end

endmodule
