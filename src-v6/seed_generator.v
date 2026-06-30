`timescale 1ns/1ps

module seed_generator #(
    parameter N              = 640,
    parameter L              = 64,
    parameter W              = 64,
    parameter P              = 32,
    parameter AES_CYCLES     = 20,
    parameter BITS_PER_AES   = 128
)(
    input  wire                  clock,
    input  wire                  reset_n,

    input  wire                  prepare,
    input  wire [127:0]          key,
    input  wire [95:0]           nonce,
    input  wire                  go,

    output wire                  ready_to_stream,
    output wire [W+P-2:0]        matrix_window,
    output wire                  busy
);

    // ============================================================
    // Parametrizacao e constantes derivadas
    // ============================================================
    localparam CYCLES       = (N + W - 1) / W;
    localparam BATCHES      = (L + P - 1) / P;
    localparam WIN          = W + P - 1;

    // Quantidade de instancias AES necessarias para sustentar, em regime,
    // uma janela consumida a cada ciclo. A arquitetura assume W <= 128.
    localparam AES_QTD      = (W * AES_CYCLES + 127) / 128;
    localparam AES_INTERVAL = (W >= 128) ? 1 : (128 / W);

    // Para nao expor uma janela invalida logo apos o warmup, o buffer inicial
    // precisa cobrir tambem os ciclos sem chegada de novo bloco AES.
    localparam WARMUP_BITS  = WIN + ((AES_INTERVAL > 0) ? ((AES_INTERVAL - 1) * W) : 0);

    // Dimensionamento dinamico do buffer.
    localparam MIN_BUF      = 128 + WARMUP_BITS + (AES_QTD * 128);
    localparam BUFFER_SIZE  = (MIN_BUF <= 512)  ? 512  :
                              (MIN_BUF <= 1024) ? 1024 :
                              (MIN_BUF <= 2048) ? 2048 : 4096;

    // ============================================================
    // Estados da FSM principal
    // ============================================================
    localparam S_IDLE       = 3'd0;
    localparam S_CALC_START = 3'd1;
    localparam S_WARMUP     = 3'd2;
    localparam S_STREAMING  = 3'd3;
    localparam S_DONE       = 3'd4;

    reg [2:0]  state;
    reg [31:0] batch_idx;
    reg [31:0] cycles_done;

    wire [63:0] calc_start_idx    = batch_idx * P;
    wire [31:0] calc_base_counter = calc_start_idx[63:7]; // start_idx / 128
    wire [6:0]  calc_offset       = calc_start_idx[6:0];  // start_idx % 128

    reg [31:0] base_counter;
    reg [6:0]  offset;
    reg        is_first_block;

    // ============================================================
    // Shift register e saidas
    // ============================================================
    reg [BUFFER_SIZE-1:0] shift_reg;
    reg [12:0]            valid_bits;

    assign matrix_window   = shift_reg[WIN-1:0];
    assign ready_to_stream = (state == S_STREAMING) && (valid_bits >= WIN);
    assign busy            = (state != S_IDLE) && (state != S_DONE);

    wire stream_fire = go && ready_to_stream;
    wire aes_active  = (state == S_WARMUP) || (state == S_STREAMING);
    wire aes_reset_n = reset_n & ~(state == S_CALC_START);

    // ============================================================
    // AES lanes
    // ============================================================
    reg  [AES_QTD-1:0] aes_input_valid;
    reg  [127:0]       aes_input_block_array [0:AES_QTD-1];
    wire [127:0]       aes_out_block_array   [0:AES_QTD-1];
    wire [AES_QTD-1:0] aes_ready;
    wire [AES_QTD-1:0] aes_out_valid;

    genvar gi;
    generate
        for (gi = 0; gi < AES_QTD; gi = gi + 1) begin : aes_lanes
            AES u_aes (
                .clock        (clock),
                .reset_n      (aes_reset_n),
                .input_valid  (aes_input_valid[gi]),
                .input_block  (aes_input_block_array[gi]),
                .input_ready  (aes_ready[gi]),
                .key          (key),
                .output_block (aes_out_block_array[gi]),
                .output_valid (aes_out_valid[gi]),
                .busy         ()
            );
        end
    endgenerate

    // ============================================================
    // Captura combinacional das saidas AES
    // Como os lancamentos sao escalonados, espera-se no maximo um
    // output_valid por ciclo. Caso duas lanes coincidam, a de maior indice
    // prevalece; o testbench acusa desalinhamento se isso afetar a ordem.
    // ============================================================
    reg         captured_valid;
    reg [127:0] captured_block;
    integer idx;

    always @(*) begin
        captured_valid = 1'b0;
        captured_block = 128'd0;
        for (idx = 0; idx < AES_QTD; idx = idx + 1) begin
            if (aes_out_valid[idx]) begin
                captured_valid = 1'b1;
                captured_block = aes_out_block_array[idx];
            end
        end
    end

    // ============================================================
    // Feeder dos AES em modo CTR intercalado
    // ============================================================
    reg [31:0] current_aes_counter;
    reg [31:0] lane_to_feed;
    reg [7:0]  timer_interval;
    reg [31:0] blocks_in_flight;

    wire [12:0] space_remaining = BUFFER_SIZE - valid_bits;
    wire [12:0] space_needed    = (blocks_in_flight + 1) * 128;
    wire        can_launch      = aes_active && (timer_interval == 0) &&
                                  aes_ready[lane_to_feed] &&
                                  (space_remaining >= space_needed);

    always @(posedge clock) begin
        if (!reset_n) begin
            aes_input_valid     <= {AES_QTD{1'b0}};
            lane_to_feed        <= 0;
            timer_interval      <= 0;
            current_aes_counter <= 0;
            blocks_in_flight    <= 0;
        end else if (state == S_CALC_START) begin
            aes_input_valid     <= {AES_QTD{1'b0}};
            lane_to_feed        <= 0;
            timer_interval      <= 0;
            current_aes_counter <= calc_base_counter;
            blocks_in_flight    <= 0;
        end else if (aes_active) begin
            aes_input_valid <= {AES_QTD{1'b0}};

            if (can_launch && !captured_valid)
                blocks_in_flight <= blocks_in_flight + 1;
            else if (!can_launch && captured_valid && (blocks_in_flight != 0))
                blocks_in_flight <= blocks_in_flight - 1;

            if (can_launch) begin
                aes_input_valid[lane_to_feed]       <= 1'b1;
                aes_input_block_array[lane_to_feed] <= {nonce, current_aes_counter};
                current_aes_counter                 <= current_aes_counter + 1;

                if (lane_to_feed == AES_QTD - 1)
                    lane_to_feed <= 0;
                else
                    lane_to_feed <= lane_to_feed + 1;

                timer_interval <= (AES_INTERVAL > 0) ? (AES_INTERVAL - 1) : 0;
            end else if (timer_interval > 0) begin
                timer_interval <= timer_interval - 1;
            end
        end else begin
            aes_input_valid <= {AES_QTD{1'b0}};
        end
    end

    // ============================================================
    // Proximo valor do sliding window buffer
    // ============================================================
    reg [BUFFER_SIZE-1:0] next_sr;
    reg [12:0]            next_vb;
    wire [7:0]            w_comb           = (is_first_block) ? (8'd128 - {1'b0, offset}) : 8'd128;
    wire [127:0]          padded_data_comb = (is_first_block) ? (captured_block >> offset) : captured_block;

    always @(*) begin
        next_sr = shift_reg;
        next_vb = valid_bits;

        if (state == S_STREAMING || state == S_WARMUP) begin
            // Consome a janela atual somente quando o consumidor realmente
            // aceitou uma janela valida.
            if (stream_fire) begin
                next_sr = next_sr >> W;
                next_vb = next_vb - W;
            end

            // Anexa o proximo bloco do keystream AES-CTR ao fim do buffer.
            if (captured_valid) begin
                next_sr = next_sr | (padded_data_comb << next_vb);
                next_vb = next_vb + w_comb;
            end
        end
    end

    // ============================================================
    // FSM principal
    // ============================================================
    always @(posedge clock) begin
        if (!reset_n) begin
            state          <= S_IDLE;
            batch_idx      <= 0;
            cycles_done    <= 0;
            base_counter   <= 0;
            offset         <= 0;
            shift_reg      <= 0;
            valid_bits     <= 0;
            is_first_block <= 1'b1;
        end else begin
            case (state)
                S_IDLE: begin
                    if (prepare) begin
                        batch_idx <= 0;
                        state     <= S_CALC_START;
                    end
                end

                S_CALC_START: begin
                    base_counter   <= calc_base_counter;
                    offset         <= calc_offset;
                    cycles_done    <= 0;
                    shift_reg      <= 0;
                    valid_bits     <= 0;
                    is_first_block <= 1'b1;
                    state          <= S_WARMUP;
                end

                S_WARMUP, S_STREAMING: begin
                    shift_reg  <= next_sr;
                    valid_bits <= next_vb;

                    if (captured_valid && is_first_block)
                        is_first_block <= 1'b0;

                    if (stream_fire) begin
                        if (cycles_done + 1 == CYCLES) begin
                            if (batch_idx + 1 == BATCHES) begin
                                state <= S_DONE;
                            end else begin
                                batch_idx <= batch_idx + 1;
                                state     <= S_CALC_START;
                            end
                        end else begin
                            cycles_done <= cycles_done + 1;
                        end
                    end else if (state == S_WARMUP && next_vb >= WARMUP_BITS) begin
                        state <= S_STREAMING;
                    end
                end

                S_DONE: begin
                    if (prepare) begin
                        batch_idx <= 0;
                        state     <= S_CALC_START;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
