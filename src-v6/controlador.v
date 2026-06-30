`timescale 1ns / 1ps

module controlador #(
    parameter N = 640,
    parameter W = 64,
    parameter P = 32,
    parameter L = 64
)(
    input  wire                   clock,
    input  wire                   reset,

    input  wire                   buf_ready,
    input  wire                   seed_ready,
    input  wire [(P-1):0]         current_hash_out,

    // Reset sincronizado
    output reg                    sys_reset,

    // Controle do Input_Buffer
    output reg                    buf_prepare,
    output reg                    buf_go,

    // Controle do Seed Generator AES-CTR/Hankel
    output reg                    seed_prepare,
    output reg                    seed_go,

    // Controle da compression_unit
    output reg                    clear_acc,
    output reg                    enable,

    // Saidas finais
    output reg  [(P-1):0]         hash_register,
    output reg                    batch_ready,
    output reg                    done,
    output wire                   ram_we,
    output reg  [$clog2((L+P-1)/P):0] ram_address
);

    localparam CYCLES     = (N + W - 1) / W;
    localparam BATCHES    = (L + P - 1) / P;
    localparam WORD_BITS  = $clog2(CYCLES);
    localparam BATCH_BITS = $clog2(BATCHES);

    // ============================================================
    // Sincronizador de reset (2 FF)
    // ============================================================
    reg reset_sync_0;

    always @(posedge clock) begin
        reset_sync_0 <= reset;
        sys_reset    <= reset_sync_0;
    end

    localparam S_IDLE    = 3'd0;
    localparam S_PREPARE = 3'd1;
    localparam S_RUN     = 3'd2;
    localparam S_DRAIN   = 3'd3;
    localparam S_CAPTURE = 3'd4;
    localparam S_WRITE   = 3'd5;
    localparam S_DONE    = 3'd6;

    reg [2:0] current_state, next_state;

    reg [BATCH_BITS:0] batch_idx;
    reg [WORD_BITS:0]  words_idx;

    wire consume_fire = (current_state == S_RUN) && buf_ready && seed_ready;
    wire last_word    = consume_fire && (words_idx == CYCLES - 1);

    assign ram_we = batch_ready && (ram_address < BATCHES);

    always @(*) begin
        next_state   = current_state;

        buf_prepare  = 1'b0;
        buf_go       = 1'b0;
        seed_prepare = 1'b0;
        seed_go      = 1'b0;
        clear_acc    = 1'b0;
        enable       = 1'b0;
        batch_ready  = 1'b0;
        done         = 1'b0;

        case (current_state)
            S_IDLE: begin
                clear_acc  = 1'b1;
                next_state = S_PREPARE;
            end

            S_PREPARE: begin
                buf_prepare  = 1'b1;
                seed_prepare = 1'b1;
                clear_acc    = 1'b1;
                next_state   = S_RUN;
            end

            S_RUN: begin
                if (consume_fire) begin
                    enable  = 1'b1;
                    buf_go  = 1'b1;
                    seed_go = 1'b1;

                    // Limpa/substitui o acumulador somente no primeiro item do lote.
                    if (words_idx == 0)
                        clear_acc = 1'b1;

                    if (words_idx == CYCLES - 1)
                        next_state = S_DRAIN;
                end
                // Se algum produtor nao estiver pronto, permanece em S_RUN sem consumir.
            end

            S_DRAIN: begin
                // Bolha de um ciclo para o ultimo enable atravessar o pipeline do hash_engine.
                next_state = S_CAPTURE;
            end

            S_CAPTURE: begin
                // current_hash_out ja contem o batch completo.
                next_state = S_WRITE;
            end

            S_WRITE: begin
                batch_ready = 1'b1;

                if (batch_idx == BATCHES - 1)
                    next_state = S_DONE;
                else
                    next_state = S_RUN;
            end

            S_DONE: begin
                done       = 1'b1;
                next_state = S_DONE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    always @(posedge clock) begin
        if (sys_reset) begin
            current_state <= S_IDLE;
            batch_idx     <= {BATCH_BITS+1{1'b0}};
            words_idx     <= {WORD_BITS+1{1'b0}};
            hash_register <= {P{1'b0}};
            ram_address   <= {(BATCH_BITS+1){1'b0}};
        end else begin
            current_state <= next_state;

            if (current_state == S_PREPARE) begin
                batch_idx     <= {BATCH_BITS+1{1'b0}};
                words_idx     <= {WORD_BITS+1{1'b0}};
                hash_register <= {P{1'b0}};
                ram_address   <= {(BATCH_BITS+1){1'b0}};
            end else begin
                if (consume_fire) begin
                    if (words_idx == CYCLES - 1)
                        words_idx <= {WORD_BITS+1{1'b0}};
                    else
                        words_idx <= words_idx + 1'b1;
                end

                if (current_state == S_CAPTURE) begin
                    hash_register <= current_hash_out;
                end

                if (current_state == S_WRITE) begin
                    if (batch_idx < BATCHES - 1)
                        batch_idx <= batch_idx + 1'b1;
                end

                if (ram_we) begin
                    ram_address <= ram_address + 1'b1;
                end
            end
        end
    end

endmodule
