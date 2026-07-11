`timescale 1ns/1ps

module seed_generator #(
    parameter integer N              = 640,
    parameter integer L              = 64,
    parameter integer W              = 64,
    parameter integer P              = 32,

    parameter integer AES_CYCLES     = 20,
    parameter integer BITS_PER_AES   = 128,

    // Para W=64 e AES_CYCLES=20:
    // ceil((20*64 + 127)/128) = 11 AES.
    parameter integer AES_QTD        = ((AES_CYCLES * W + 127) + BITS_PER_AES - 1) / BITS_PER_AES,

    parameter integer WIN            = W + P - 1,

    // Cada rajada gera exatamente os bits necessarios para AES_CYCLES ciclos.
    parameter integer SLOT_WORDS     = AES_CYCLES,
    parameter integer SLOT_BITS      = SLOT_WORDS * W,

    // A janela fisica e arredondada para multiplo de SLOT_WORDS para que o
    // warmup seja feito por chunks inteiros, sem escrita em posicao variavel.
    parameter integer WINDOW_WORDS_MIN = (WIN + W - 1) / W,
    parameter integer WINDOW_CHUNKS    = (WINDOW_WORDS_MIN + SLOT_WORDS - 1) / SLOT_WORDS,
    parameter integer WINDOW_PAD_WORDS = WINDOW_CHUNKS * SLOT_WORDS,
    parameter integer WINDOW_PAD_BITS  = WINDOW_PAD_WORDS * W,

    parameter integer INDEX_BITS     = 32,
    parameter integer AES_MSB_FIRST  = 1,

    parameter integer CYCLES_PER_BATCH = (N + W - 1) / W,
    parameter integer TOTAL_BATCHES    = (L + P - 1) / P
)(
    input  wire           clock,
    input  wire           reset_n,

    input  wire           prepare,
    input  wire [127:0]   key,
    input  wire [95:0]    nonce,
    input  wire           go,

    output wire           ready_to_stream,
    output wire [WIN-1:0] matrix_window,
    output wire           busy
);

    //janela e slots

    reg [WINDOW_PAD_BITS-1:0] window_reg;
    reg [SLOT_BITS-1:0]       active_slot;
    reg [SLOT_BITS-1:0]       standby_slot;
    reg                       standby_valid;

    reg [31:0] init_chunk_count;
    reg        active_loaded;

    // Chunk registrado entre AES e escrita na janela/slots.
    reg [SLOT_BITS-1:0] chunk_bits_r;
    reg                 chunk_valid_r;

    function integer clog2_int;
        input integer value;
        integer v;
        begin
            v = value - 1;
            clog2_int = 0;
            while (v > 0) begin
                v = v >> 1;
                clog2_int = clog2_int + 1;
            end
        end
    endfunction

    function [INDEX_BITS-1:0] batch_start_idx_fn;
        input [31:0] batch;
        begin
            // Para matriz de Hankel, o lote b comeca em b*P.
            batch_start_idx_fn = batch * P;
        end
    endfunction

    function [31:0] counter_from_bit_idx_fn;
        input [INDEX_BITS-1:0] idx;
        begin
            counter_from_bit_idx_fn = idx >> 7; // divide por 128
        end
    endfunction

    function [6:0] offset_from_bit_idx_fn;
        input [INDEX_BITS-1:0] idx;
        begin
            offset_from_bit_idx_fn = idx[6:0]; // mod 128
        end
    endfunction

    function get_burst_stream_bit;
        input [(AES_QTD*128)-1:0] blocks_flat;
        input integer stream_pos;
        integer block_idx;
        integer bit_idx;
        integer flat_idx;
        begin
            block_idx = stream_pos / 128;
            bit_idx   = stream_pos - (block_idx * 128);

            if (AES_MSB_FIRST != 0)
                flat_idx = (block_idx * 128) + (127 - bit_idx);
            else
                flat_idx = (block_idx * 128) + bit_idx;

            get_burst_stream_bit = blocks_flat[flat_idx];
        end
    endfunction


    function [WINDOW_PAD_BITS-1:0] append_chunk_to_window;
        input [WINDOW_PAD_BITS-1:0] win;
        input [SLOT_BITS-1:0]       chunk;
        integer f;
        begin
            append_chunk_to_window = {WINDOW_PAD_BITS{1'b0}};
            for (f = 0; f < (WINDOW_PAD_BITS - SLOT_BITS); f = f + 1) begin
                append_chunk_to_window[f] = win[f + SLOT_BITS];
            end
            for (f = 0; f < SLOT_BITS; f = f + 1) begin
                append_chunk_to_window[(WINDOW_PAD_BITS - SLOT_BITS) + f] = chunk[f];
            end
        end
    endfunction

    function [WINDOW_PAD_BITS-1:0] append_word_to_window;
        input [WINDOW_PAD_BITS-1:0] win;
        input [W-1:0]               word;
        integer f;
        begin
            append_word_to_window = {WINDOW_PAD_BITS{1'b0}};

            // Descarta os W bits mais antigos e desloca o restante para baixo.
            for (f = 0; f < (WINDOW_PAD_BITS - W); f = f + 1) begin
                append_word_to_window[f] = win[f + W];
            end

            ///palavra nova entra no topo.
            for (f = 0; f < W; f = f + 1) begin
                append_word_to_window[(WINDOW_PAD_BITS - W) + f] = word[f];
            end
        end
    endfunction

    localparam [31:0] SLOT_WORDS_32       = SLOT_WORDS;
    localparam [31:0] WINDOW_CHUNKS_32    = WINDOW_CHUNKS;
    localparam [31:0] CYCLES_PER_BATCH_32 = CYCLES_PER_BATCH;
    localparam [31:0] TOTAL_BATCHES_32    = TOTAL_BATCHES;


    localparam S_IDLE  = 3'd0;
    localparam S_RESET = 3'd1;
    localparam S_INIT  = 3'd2;
    localparam S_RUN   = 3'd3;
    localparam S_WAIT  = 3'd4;
    localparam S_DONE  = 3'd5;

    reg [2:0] state;

    assign busy            = (state != S_IDLE) && (state != S_DONE);
    assign ready_to_stream = (state == S_RUN);
    assign matrix_window   = window_reg[WIN-1:0];

    reg [31:0]           batch_idx;
    reg [31:0]           cycle_in_batch;
    reg [31:0]           slot_word_idx;
    reg [INDEX_BITS-1:0] batch_start_idx;

    wire consume_fire;
    wire last_cycle_in_batch;
    wire last_batch;
    wire slot_end_fire;

    assign consume_fire        = (state == S_RUN) && go;
    assign last_cycle_in_batch = consume_fire && (cycle_in_batch == (CYCLES_PER_BATCH_32 - 32'd1));
    assign last_batch          = (batch_idx == (TOTAL_BATCHES_32 - 32'd1));
    assign slot_end_fire       = consume_fire && (slot_word_idx == (SLOT_WORDS_32 - 32'd1));

    wire aes_local_reset_n;
    assign aes_local_reset_n = reset_n && (state != S_RESET);

    reg [31:0] aes_next_word_start;
    reg [31:0] aes_current_word_start;

    wire [INDEX_BITS-1:0] aes_next_bit_start;
    wire [31:0]           aes_next_base_counter;

    assign aes_next_bit_start    = batch_start_idx + (aes_next_word_start * W);
    assign aes_next_base_counter = counter_from_bit_idx_fn(aes_next_bit_start);

    wire aes_feed_enable;
    assign aes_feed_enable = (state == S_INIT) || (state == S_RUN);

    wire [AES_QTD-1:0]       aes_input_ready;
    wire [AES_QTD-1:0]       aes_output_valid;
    wire [(AES_QTD*128)-1:0] aes_output_block_flat;

    wire all_aes_ready;
    wire all_aes_output_valid;
    wire aes_accept_burst;

    assign all_aes_ready        = &aes_input_ready;
    assign all_aes_output_valid = &aes_output_valid;
    assign aes_accept_burst     = aes_feed_enable && all_aes_ready;

    genvar ai;
    generate
        for (ai = 0; ai < AES_QTD; ai = ai + 1) begin : gen_aes_lanes
            wire [127:0] aes_out_block;
            wire [31:0]  lane_counter;

            localparam [31:0] LANE_OFFSET = ai;

            assign lane_counter = aes_next_base_counter + LANE_OFFSET;

            AES u_aes_lane (
                .clock        (clock),
                .reset_n      (aes_local_reset_n),

                .input_valid  (aes_feed_enable),
                .input_block  ({nonce, lane_counter}),
                .input_ready  (aes_input_ready[ai]),

                .key          (key),

                .output_block (aes_out_block),
                .output_valid (aes_output_valid[ai]),
                .busy         ()
            );

            assign aes_output_block_flat[ai*128 +: 128] = aes_out_block;
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Conversao da rajada AES para chunk util

    wire [INDEX_BITS-1:0] current_chunk_bit_start;
    wire [6:0]            current_chunk_offset;

    assign current_chunk_bit_start = batch_start_idx + (aes_current_word_start * W);
    assign current_chunk_offset    = offset_from_bit_idx_fn(current_chunk_bit_start);

    reg [SLOT_BITS-1:0] chunk_bits_comb;
    integer cb_i;

    always @(*) begin
        for (cb_i = 0; cb_i < SLOT_BITS; cb_i = cb_i + 1) begin
            chunk_bits_comb[cb_i] = get_burst_stream_bit(
                aes_output_block_flat,
                current_chunk_offset + cb_i
            );
        end
    end

    always @(posedge clock) begin
        if (!reset_n) begin
            state                  <= S_IDLE;
            batch_idx              <= 32'd0;
            cycle_in_batch         <= 32'd0;
            slot_word_idx          <= 32'd0;
            batch_start_idx        <= {INDEX_BITS{1'b0}};

            // Registradores grandes propositalmente nao sao zerados no reset.
            // Eles sao completamente sobrescritos no warmup antes de ready_to_stream.
            standby_valid          <= 1'b0;
            init_chunk_count       <= 32'd0;
            active_loaded          <= 1'b0;
            chunk_valid_r          <= 1'b0;

            aes_next_word_start    <= 32'd0;
            aes_current_word_start <= 32'd0;
        end else begin

            if (aes_accept_burst) begin
                aes_current_word_start <= aes_next_word_start;
                aes_next_word_start    <= aes_next_word_start + SLOT_WORDS_32;
            end
            if (all_aes_output_valid) begin
                chunk_bits_r  <= chunk_bits_comb;
                chunk_valid_r <= 1'b1;
            end

            case (state)

                S_IDLE: begin
                    if (prepare) begin
                        batch_idx <= 32'd0;
                        state     <= S_RESET;
                    end
                end

                S_RESET: begin
                    // Reinicio logico de lote. Os registradores de dados serao
                    // sobrescritos durante S_INIT.
                    batch_start_idx        <= batch_start_idx_fn(batch_idx);
                    cycle_in_batch         <= 32'd0;
                    slot_word_idx          <= 32'd0;
                    init_chunk_count       <= 32'd0;
                    active_loaded          <= 1'b0;
                    standby_valid          <= 1'b0;
                    chunk_valid_r          <= 1'b0;
                    aes_next_word_start    <= 32'd0;
                    aes_current_word_start <= 32'd0;

                    state <= S_INIT;
                end

                S_INIT: begin
                    if (chunk_valid_r) begin
                        if (init_chunk_count < WINDOW_CHUNKS_32) begin
                            window_reg       <= append_chunk_to_window(window_reg, chunk_bits_r);
                            init_chunk_count <= init_chunk_count + 32'd1;
                            chunk_valid_r    <= 1'b0;

                        end else if (!active_loaded) begin
                            active_slot    <= chunk_bits_r;
                            active_loaded  <= 1'b1;
                            chunk_valid_r  <= 1'b0;

                        end else if (!standby_valid) begin
                            standby_slot   <= chunk_bits_r;
                            standby_valid  <= 1'b1;
                            chunk_valid_r  <= 1'b0;
                            state          <= S_RUN;
                        end
                    end
                end

                S_RUN: begin
                    // Se chegou um chunk novo, guarda como standby quando houver vaga.
                    if (chunk_valid_r && !standby_valid) begin // Com a cadencia ideal, ele chega logo apos a promocao do slot
                        standby_slot  <= chunk_bits_r;
                        standby_valid <= 1'b1;
                        chunk_valid_r <= 1'b0;
                    end

                    if (consume_fire) begin
                        // A compression_unit amostra matrix_window nesta borda!! A proxima janela e preparada para o ciclo seguinte
                        
                        window_reg  <= append_word_to_window(window_reg, active_slot[W-1:0]);
                        active_slot <= {{W{1'b0}}, active_slot[SLOT_BITS-1:W]};

                        if (last_cycle_in_batch) begin
                            cycle_in_batch <= 32'd0;
                            slot_word_idx  <= 32'd0;

                            if (last_batch) begin
                                state <= S_DONE;
                            end else begin
                                batch_idx <= batch_idx + 32'd1;
                                state     <= S_RESET;
                            end

                        end else begin
                            cycle_in_batch <= cycle_in_batch + 32'd1;

                            if (slot_word_idx == (SLOT_WORDS_32 - 32'd1)) begin
                                slot_word_idx <= 32'd0;

                                if (standby_valid) begin
                                    active_slot   <= standby_slot;
                                    standby_valid <= 1'b0;
                                end else begin
                                    
                                    state <= S_WAIT; // provaavel ser raro/impossivel se a cadencia AES estiver correta!!!
                                end
                            end else begin
                                slot_word_idx <= slot_word_idx + 32'd1;
                            end
                        end
                    end
                end

                S_WAIT: begin
                    // Estado de seguranca. Aguarda um chunk registrado para retomar.
                    if (chunk_valid_r) begin
                        active_slot   <= chunk_bits_r;
                        standby_valid <= 1'b0;
                        chunk_valid_r <= 1'b0;
                        slot_word_idx <= 32'd0;
                        state         <= S_RUN;
                    end
                end

                S_DONE: begin
                    if (prepare) begin
                        batch_idx <= 32'd0;
                        state     <= S_RESET;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end

            endcase
        end
    end

endmodule