`timescale 1ns / 1ps

module top #(
    // ============================================================
    // Parametros globais do Privacy Amplification
    // ============================================================
    parameter N = 1200,
    parameter W = 128,
    parameter P = 660,
    parameter L = 660,
    // ============================================================
    // Parametros do Seed Generator AES-128 CTR
    // Atualize estes valores com os gerados pelo gerar_dados.py
    // ============================================================
    parameter AES_CYCLES = 20,
    parameter [127:0] SEED_KEY   = 128'h2b7e151628aed2a6abf7158809cf4f3c,
    parameter [95:0]  SEED_NONCE = 96'h000000000000000000000001,
    parameter USE_LFSR_SEED = 1,
    parameter [31:0] LFSR_INIT = 32'hACE12B7D
)(
    input  wire           clock,
    input  wire           reset,

    output wire [(P-1):0] hash_register,
    output wire           batch_ready,
    output wire           done
);

    // ============================================================
    // Constantes derivadas
    // ============================================================
    localparam CYCLES     = (N + W - 1) / W;
    localparam BATCHES    = (L + P - 1) / P;
    localparam BATCH_BITS = $clog2(BATCHES);

    localparam ROM_ADDR_BITS = (CYCLES <= 32)    ? 5 : 
                               (CYCLES <= 64)    ? 6 : 
                               (CYCLES <= 128)   ? 7 : 
                               (CYCLES <= 256)   ? 8 : 
                               (CYCLES <= 512)   ? 9 : 
                               (CYCLES <= 1024)  ? 10 : 
                               (CYCLES <= 2048)  ? 11 : 
                               (CYCLES <= 4096)  ? 12 : 
                               (CYCLES <= 8192)  ? 13 : 
                               (CYCLES <= 16384) ? 14 : 
                               (CYCLES <= 32768) ? 15 : 16;
                               
    localparam MEM_DEPTH = (CYCLES <= 32)    ? 32 : 
                           (CYCLES <= 64)    ? 64: 
                           (CYCLES <= 128)   ? 128: 
                           (CYCLES <= 256)   ? 256: 
                           (CYCLES <= 512)   ? 512: 
                           (CYCLES <= 1024)  ? 1024: 
                           (CYCLES <= 2048)  ? 2048: 
                           (CYCLES <= 4096)  ? 4096: 
                           (CYCLES <= 8192)  ? 8192: 
                           (CYCLES <= 16384) ? 16384: 
                           (CYCLES <= 32768) ? 32768 : 65536;

    // ============================================================
    // Reset interno sincronizado pelo controlador
    // ============================================================
    wire sys_reset;

    // ============================================================
    // ROM da chave <-> Input Buffer
    // ============================================================
    wire [(ROM_ADDR_BITS-1):0] rom_key_addr;
    wire [(W-1):0]             rom_key_q;

    // ============================================================
    // Input Buffer <-> Controlador
    // ============================================================
    wire             buf_ready_to_stream;
    wire             buf_out_valid;
    wire             buf_done;
    wire [(W-1):0]   buf_out_data;
    wire             buf_prepare;
    wire             buf_go;

    /*
        IMPORTANTE:

        O Input_Buffer possui dois momentos relevantes:

        1) ready_to_stream = 1:
           indica que o buffer saiu do warmup e a primeira palavra da ROM
           ja pode ser usada.

        2) out_valid = 1:
           indica regime normal de streaming apos o primeiro go.

        O erro observado acontecia porque o controlador consumia a janela
        do seed_generator enquanto safe_key ainda ficava zerado, pois antes
        usavamos apenas buf_out_valid para liberar a chave.

        Agora, para o controlador e para a compression_unit, consideramos
        chave disponivel quando:

            buf_ready_to_stream || buf_out_valid
    */
    wire buf_ready;
    assign buf_ready = buf_ready_to_stream || buf_out_valid;

    // ============================================================
    // Seed Generator <-> Controlador
    // ============================================================
    wire             seed_ready;
    wire             seed_prepare;
    wire             seed_go;
    wire [(W+P-2):0] current_matrix_window;
    wire             seed_busy;

    wire [127:0]     lfsr_seed_key;
    wire [95:0]      lfsr_seed_nonce;

    wire [127:0]     aes_key   = USE_LFSR_SEED ? lfsr_seed_key   : SEED_KEY;
    wire [95:0]      aes_nonce = USE_LFSR_SEED ? lfsr_seed_nonce : SEED_NONCE;

    // ============================================================
    // Controlador <-> Compression Unit
    // ============================================================
    wire             clear_acc;
    wire             enable;
    wire [(P-1):0]   current_hash_out;

    // ============================================================
    // Controlador <-> RAM Dump
    // ============================================================
    wire                  ram_we;
    wire [BATCH_BITS:0]   ram_address;

    // ============================================================
    // Sinais seguros para a operacao
    //
    // A compression_unit so recebe dados reais quando:
    //   - a chave esta disponivel;
    //   - a janela Hankel esta disponivel.
    // ============================================================
    wire stream_valid;
    assign stream_valid = buf_ready && seed_ready;

    wire [(W-1):0]   safe_key;
    wire [(W+P-2):0] safe_window;

    assign safe_key    = stream_valid ? buf_out_data          : {W{1'b0}};
    assign safe_window = stream_valid ? current_matrix_window : {(W+P-1){1'b0}};

    // ============================================================
    // Registrador de fronteira seed_generator/Input_Buffer -> compression_unit
    //
    // stream_valid depende de seed_ready (win_valid_bits do seed_generator),
    // um sinal com fanout alto que precisa alcançar as P instancias do
    // hash_engine. Sem esse registrador, a decisao de "pronto" + o
    // roteamento ate essas instancias + a reducao AND/XOR de cada uma
    // aconteciam tudo no mesmo ciclo. Registrando key/window/enable/
    // clear_acc juntos (mantendo-os em lockstep, como o proprio hash_engine
    // ja faz entre seus 2 estagios internos), a decisao de pronto tem um
    // ciclo inteiro soh para chegar fisicamente aos destinos.
    // ============================================================
    reg [(W-1):0]   safe_key_r;
    reg [(W+P-2):0] safe_window_r;
    reg             enable_r;
    reg             clear_acc_r;

    always @(posedge clock) begin
        if (sys_reset) begin
            safe_key_r    <= {W{1'b0}};
            safe_window_r <= {(W+P-1){1'b0}};
            enable_r      <= 1'b0;
            clear_acc_r   <= 1'b0;
        end else begin
            safe_key_r    <= safe_key;
            safe_window_r <= safe_window;
            enable_r      <= enable;
            clear_acc_r   <= clear_acc;
        end
    end

    // ============================================================
    // Controlador principal
    // ============================================================
    controlador #(
        .N(N),
        .W(W),
        .P(P),
        .L(L),
        .LFSR_INIT(LFSR_INIT)
    ) u_controlador (
        .clock            (clock),
        .reset            (reset),

        // Aqui buf_ready significa: existe palavra de chave disponivel.
        // Nao e apenas o ready inicial do Input_Buffer.
        .buf_ready        (buf_ready),
        .seed_ready       (seed_ready),
        .current_hash_out (current_hash_out),

        .sys_reset        (sys_reset),

        .buf_prepare      (buf_prepare),
        .buf_go           (buf_go),

        .seed_prepare     (seed_prepare),
        .seed_go          (seed_go),

        .seed_key         (lfsr_seed_key),
        .seed_nonce       (lfsr_seed_nonce),

        .clear_acc        (clear_acc),
        .enable           (enable),

        .hash_register    (hash_register),
        .batch_ready      (batch_ready),
        .done             (done),

        .ram_we           (ram_we),
        .ram_address      (ram_address)
    );

    // ============================================================
    // Input Buffer da chave reconciliada
    // ============================================================
    Input_Buffer #(
        .DEPTH        (CYCLES),
        .ADDR_BITS    (ROM_ADDR_BITS),
        .DATA_BITS    (W),
        .REPEAT_COUNT (BATCHES)
    ) u_input_buffer (
        .clk             (clock),
        .rst_n           (!sys_reset),

        .prepare         (buf_prepare),
        .go              (buf_go),

        .rom_q           (rom_key_q),
        .rom_addr        (rom_key_addr),
        .rom_clock       (),

        .out_data        (buf_out_data),
        .out_valid       (buf_out_valid),

        // Sinal bruto do Input_Buffer.
        // Nao ligar diretamente no controlador.
        .ready_to_stream (buf_ready_to_stream),

        .done            (buf_done)
    );

    // ============================================================
    // ROM da chave reconciliada
    //
    // Usa key.mif gerado pelo script Python.
    // ============================================================
    rom_key #(
        .DATA_BITS (W),
        .ADDR_BITS (ROM_ADDR_BITS),
        .DEPTH     (MEM_DEPTH)
    ) uut_rom_key (
        .address (rom_key_addr),
        .clock   (clock),
        .q       (rom_key_q)
    );

    // ============================================================
    // Seed Generator AES-128 CTR
    //
    // Substitui a antiga matrix_lut.
    // Gera current_matrix_window = janela Hankel de W+P-1 bits.
    // ============================================================
    seed_generator #(
        .N          (N),
        .L          (L),
        .W          (W),
        .P          (P),
        .AES_CYCLES (AES_CYCLES)
    ) u_seed_generator (
        .clock           (clock),
        .reset_n         (!sys_reset),

        .prepare         (seed_prepare),
        .key             (aes_key),
        .nonce           (aes_nonce),
        .go              (seed_go),

        .ready_to_stream (seed_ready),
        .matrix_window   (current_matrix_window),
        .busy            (seed_busy)
    );

    // ============================================================
    // Unidade de compressao / hash
    //
    // Recebe o pedaco da chave e a janela Hankel alinhados.
    // ============================================================
    compression_unit #(
        .P(P),
        .W(W)
    ) u_compression_unit (
        .clock         (clock),
        .reset         (sys_reset),

        .clear_acc     (clear_acc_r),
        .enable        (enable_r),

        .key           (safe_key_r),
        .matrix_window (safe_window_r),

        .hash_out      (current_hash_out)
    );

    // ============================================================
    // RAM Dump dos hashes por lote
    // ============================================================
    ram_dump #(
        .DATA_BITS (P),
        .ADDR_BITS (BATCH_BITS + 1)
    ) u_ram_dump (
        .clock   (clock),
        .we      (ram_we),
        .address (ram_address),
        .data_in (hash_register)
    );

endmodule