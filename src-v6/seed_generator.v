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

    // Para nao expor uma janela invalida logo apos o warmup, o registrador de
    // janela precisa cobrir tambem os ciclos sem chegada de novo bloco AES.
    // A margem extra de W bits cobre o ciclo adicional de pipeline entre a
    // leitura da FIFO e a insercao no gearbox (ver pending_valid abaixo).
    localparam WARMUP_BITS  = WIN + ((AES_INTERVAL > 0) ? ((AES_INTERVAL - 1) * W) : 0) + W;

    // ------------------------------------------------------------
    // Buffer em 3 estagios, todos com deslocamento de largura fixa ou de
    // granularidade grande (nunca bit-a-bit sobre milhares de bits, que era
    // a causa do caminho critico do buffer monolitico anterior):
    //
    //   FIFO de staging (128b/slot, sem shift, so indexacao) ->
    //   gearbox (256b, unico shift variavel, confinado a <=128 posicoes) ->
    //   registrador de janela (WINREG bits, shift sempre em multiplos de W)
    // ------------------------------------------------------------
    localparam FIFO_DEPTH     = (AES_QTD + 2 < 4) ? 4 : (AES_QTD + 2);
    localparam FIFO_PTR_BITS  = $clog2(FIFO_DEPTH);
    localparam FIFO_CNT_BITS  = $clog2(FIFO_DEPTH + 1);

    localparam GB_WIDTH       = 256;
    localparam GB_CNT_BITS    = 9;

    localparam WINREG         = W * (((WARMUP_BITS + W - 1) / W) + 1);
    localparam WIN_CNT_BITS   = $clog2(WINREG + 1);

    // ============================================================
    // Estados da FSM principal
    // ============================================================
    localparam S_IDLE       = 3'd0;
    localparam S_CALC_START = 3'd1;
    localparam S_WARMUP     = 3'd2;
    localparam S_STREAMING  = 3'd3;
    localparam S_DONE       = 3'd4;

    localparam CYCLES_BITS  = $clog2(CYCLES);
    localparam BATCHES_BITS = $clog2(BATCHES);

    reg [2:0]              state;
    reg [BATCHES_BITS:0]   batch_idx;
    reg [CYCLES_BITS:0]    cycles_done;

    wire [63:0] calc_start_idx    = batch_idx * P;
    wire [31:0] calc_base_counter = calc_start_idx[63:7]; // start_idx / 128
    wire [6:0]  calc_offset       = calc_start_idx[6:0];  // start_idx % 128

    reg [31:0] base_counter;
    reg [6:0]  offset;
    reg        is_first_block;

    // ============================================================
    // Registrador de janela (saida) e FSM auxiliares
    // ============================================================
    reg [WINREG-1:0]      window_reg;
    reg [WIN_CNT_BITS-1:0] win_valid_bits;

    assign matrix_window   = window_reg[WIN-1:0];
    assign ready_to_stream = (state == S_STREAMING) && (win_valid_bits >= WIN[WIN_CNT_BITS-1:0]);
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

    // Registra a saida do mux de prioridade das lanes AES antes de usa-la
    // para escrever na FIFO: sem isso, o mux 10:1 de 128 bits ficava
    // encadeado no mesmo ciclo com a escrita indexada em 1-de-FIFO_DEPTH
    // slots, virando o novo caminho critico depois das correcoes anteriores.
    reg         captured_valid_r;
    reg [127:0] captured_block_r;

    always @(posedge clock) begin
        if (!reset_n || state == S_CALC_START) begin
            // Descarta explicitamente qualquer output_valid tardio do rabo
            // do lote anterior (mesmo efeito que o design original tinha
            // "de graca": a escrita na FIFO so roda no branch
            // S_WARMUP/S_STREAMING, entao um pulso chegando durante
            // S_CALC_START nunca era escrito). Sem isso, esse pulso
            // sobreviveria 1 ciclo no registrador e contaminaria o
            // fifo_mem[0] do lote novo.
            captured_valid_r <= 1'b0;
            captured_block_r <= 128'd0;
        end else begin
            captured_valid_r <= captured_valid;
            captured_block_r <= captured_block;
        end
    end

    // ============================================================
    // FIFO de staging: cada bloco AES capturado vai para um slot indexado
    // por ponteiro (sem shift nenhum). Substitui o antigo controle de
    // "espaco restante" em bits por uma contagem de slots livres.
    // ============================================================
    (* ramstyle = "logic" *) reg [127:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [FIFO_PTR_BITS-1:0]  fifo_wr_ptr;
    reg [FIFO_PTR_BITS-1:0]  fifo_rd_ptr;
    reg [FIFO_CNT_BITS-1:0]  fifo_count;

    wire [127:0] fifo_rd_data = fifo_mem[fifo_rd_ptr];

    // ============================================================
    // Gearbox: registrador de 256 bits que absorve o (unico) shift de
    // distancia variavel do sistema, confinado a no maximo 128 posicoes,
    // e monta o fluxo de W bits/ciclo a partir das palavras de 128 bits da
    // FIFO. O alinhamento de offset do primeiro bloco do lote e aplicado
    // aqui, uma vez por lote.
    //
    // A leitura da FIFO (fifo_rd_ptr -> mux -> shift-insere em gb_reg) e
    // dividida em 2 estagios de registrador (pending_*) para nao encadear o
    // mux de leitura com o barrel shift no mesmo ciclo: isso so adiciona 1
    // ciclo de latencia por palavra, nao reduz o throughput (um pop pode
    // ser emitido a cada ciclo, o pipeline nao trava).
    // ============================================================
    reg [GB_WIDTH-1:0]     gb_reg;
    reg [GB_CNT_BITS-1:0]  gb_valid_bits;

    reg         pending_valid;
    reg [127:0] pending_word;
    reg         pending_is_first;

    wire [7:0]   w_comb           = (pending_is_first) ? (8'd128 - {1'b0, offset}) : 8'd128;
    wire [127:0] padded_data_comb = (pending_is_first) ? (pending_word >> offset) : pending_word;
    wire [GB_WIDTH-1:0] padded_data_ext = {{(GB_WIDTH-128){1'b0}}, padded_data_comb};

    // Reserva espaco para a palavra que ja foi lida da FIFO mas ainda nao
    // foi inserida no gearbox (pending_valid), para nao estourar GB_WIDTH.
    wire gb_has_room = (gb_valid_bits + (pending_valid ? 9'd128 : 9'd0)) <= (GB_WIDTH - 128);
    wire fifo_pop     = (state == S_STREAMING || state == S_WARMUP) &&
                        (fifo_count != 0) && gb_has_room;

    wire win_has_room = (win_valid_bits + W <= WINREG[WIN_CNT_BITS-1:0]);
    wire feed_window  = (state == S_STREAMING || state == S_WARMUP) &&
                        (gb_valid_bits >= W) && win_has_room;

    // ============================================================
    // Feeder dos AES em modo CTR intercalado
    // ============================================================
    localparam LANE_BITS = (AES_QTD > 1) ? $clog2(AES_QTD) : 1;

    reg [31:0]              current_aes_counter;
    reg [LANE_BITS-1:0]     lane_to_feed;
    reg [7:0]               timer_interval;
    reg [FIFO_CNT_BITS-1:0] blocks_in_flight;

    // Decisao (can_launch, que le aes_ready[lane_to_feed] - um mux 10:1 sobre
    // o round/fsm de cada lane) e execucao (escrita indexada em
    // aes_input_block_array/aes_input_valid) ficavam encadeadas no mesmo
    // ciclo, virando o novo caminho critico apos as correcoes anteriores.
    // Mesma tecnica de pending_valid/captured_valid_r: separa em 2 estagios.
    reg                  launch_pending;
    reg [LANE_BITS-1:0]  launch_lane;
    reg [31:0]           launch_counter;

    wire can_launch = aes_active && (timer_interval == 0) &&
                      aes_ready[lane_to_feed] &&
                      ((fifo_count + blocks_in_flight) < FIFO_DEPTH[FIFO_CNT_BITS-1:0]);

    always @(posedge clock) begin
        if (!reset_n) begin
            aes_input_valid     <= {AES_QTD{1'b0}};
            lane_to_feed        <= 0;
            timer_interval      <= 0;
            current_aes_counter <= 0;
            blocks_in_flight    <= 0;
            launch_pending       <= 1'b0;
            launch_lane          <= 0;
            launch_counter        <= 0;
        end else if (state == S_CALC_START) begin
            aes_input_valid     <= {AES_QTD{1'b0}};
            lane_to_feed        <= 0;
            timer_interval      <= 0;
            current_aes_counter <= calc_base_counter;
            blocks_in_flight    <= 0;
            launch_pending       <= 1'b0;
            launch_lane          <= 0;
            launch_counter        <= 0;
        end else if (aes_active) begin
            // Estagio 2: comete a decisao registrada no ciclo anterior.
            aes_input_valid <= {AES_QTD{1'b0}};
            if (launch_pending) begin
                aes_input_valid[launch_lane]       <= 1'b1;
                aes_input_block_array[launch_lane] <= {nonce, launch_counter};
            end

            // Estagio 1: decide e reserva (lane/contador/timer avancam aqui,
            // igual antes; so a escrita de fato foi para o estagio 2).
            launch_pending <= can_launch;

            if (can_launch && !captured_valid_r)
                blocks_in_flight <= blocks_in_flight + 1;
            else if (!can_launch && captured_valid_r && (blocks_in_flight != 0))
                blocks_in_flight <= blocks_in_flight - 1;

            if (can_launch) begin
                launch_lane          <= lane_to_feed;
                launch_counter       <= current_aes_counter;
                current_aes_counter  <= current_aes_counter + 1;

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
    // Proximo valor do gearbox e do registrador de janela
    // ============================================================
    reg [GB_WIDTH-1:0]      next_gb;
    reg [GB_CNT_BITS-1:0]   next_gb_valid;
    reg [WINREG-1:0]        next_win;
    reg [WIN_CNT_BITS-1:0]  next_win_valid;

    always @(*) begin
        next_gb        = gb_reg;
        next_gb_valid  = gb_valid_bits;
        next_win       = window_reg;
        next_win_valid = win_valid_bits;

        if (state == S_STREAMING || state == S_WARMUP) begin
            if (stream_fire) begin
                next_win       = next_win >> W;
                next_win_valid = next_win_valid - W;
            end

            if (feed_window) begin
                next_gb       = next_gb >> W;
                next_gb_valid = next_gb_valid - W;

                next_win       = next_win | ({{(WINREG-W){1'b0}}, gb_reg[W-1:0]} << next_win_valid);
                next_win_valid = next_win_valid + W;
            end

            if (pending_valid) begin
                next_gb       = next_gb | (padded_data_ext << next_gb_valid);
                next_gb_valid = next_gb_valid + w_comb;
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
            is_first_block <= 1'b1;

            fifo_wr_ptr    <= 0;
            fifo_rd_ptr    <= 0;
            fifo_count     <= 0;
            gb_reg         <= 0;
            gb_valid_bits  <= 0;
            window_reg     <= 0;
            win_valid_bits <= 0;
            pending_valid  <= 1'b0;
            pending_word   <= 0;
            pending_is_first <= 1'b0;
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
                    is_first_block <= 1'b1;

                    fifo_wr_ptr    <= 0;
                    fifo_rd_ptr    <= 0;
                    fifo_count     <= 0;
                    gb_reg         <= 0;
                    gb_valid_bits  <= 0;
                    window_reg     <= 0;
                    win_valid_bits <= 0;
                    pending_valid  <= 1'b0;
                    pending_word   <= 0;
                    pending_is_first <= 1'b0;

                    state          <= S_WARMUP;
                end

                S_WARMUP, S_STREAMING: begin
                    gb_reg         <= next_gb;
                    gb_valid_bits  <= next_gb_valid;
                    window_reg     <= next_win;
                    win_valid_bits <= next_win_valid;

                    if (captured_valid_r) begin
                        fifo_mem[fifo_wr_ptr] <= captured_block_r;
                        fifo_wr_ptr           <= (fifo_wr_ptr == FIFO_DEPTH-1) ? 0 : fifo_wr_ptr + 1;
                    end

                    pending_valid <= fifo_pop;

                    if (fifo_pop) begin
                        fifo_rd_ptr      <= (fifo_rd_ptr == FIFO_DEPTH-1) ? 0 : fifo_rd_ptr + 1;
                        pending_word     <= fifo_rd_data;
                        pending_is_first <= is_first_block;

                        if (is_first_block)
                            is_first_block <= 1'b0;
                    end

                    case ({captured_valid_r, fifo_pop})
                        2'b10:   fifo_count <= fifo_count + 1'b1;
                        2'b01:   fifo_count <= fifo_count - 1'b1;
                        default: fifo_count <= fifo_count;
                    endcase

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
                    end else if (state == S_WARMUP && next_win_valid >= WARMUP_BITS[WIN_CNT_BITS-1:0]) begin
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
