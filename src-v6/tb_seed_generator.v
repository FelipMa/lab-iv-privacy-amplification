`timescale 1ns/1ps

module tb_seed_generator;

    // Parametrizacao de validacao descrita no relatorio.
    parameter N = 640;
    parameter L = 64;
    parameter W = 64;
    parameter P = 32;

    localparam CYCLES       = (N + W - 1) / W;
    localparam BATCHES      = (L + P - 1) / P;
    localparam WIN          = W + P - 1;
    localparam TOTAL_WINDOWS = CYCLES * BATCHES;

    // Ultimo bit efetivamente acessado pelas janelas (Hankel):
    // start_idx = b*P + c*W; janela = W+P-1 bits.
    localparam REF_BITS     = ((BATCHES - 1) * P) + ((CYCLES - 1) * W) + WIN;
    localparam REF_BLOCKS   = (REF_BITS + 127) / 128;

    reg clock;
    reg reset_n;
    reg prepare;
    reg [95:0]  nonce;
    reg [127:0] key;
    reg go;

    wire ready_to_stream;
    wire [W+P-2:0] matrix_window;
    wire busy;

    seed_generator #(
        .N(N),
        .L(L),
        .W(W),
        .P(P)
    ) dut (
        .clock(clock),
        .reset_n(reset_n),
        .prepare(prepare),
        .key(key),
        .nonce(nonce),
        .go(go),
        .ready_to_stream(ready_to_stream),
        .matrix_window(matrix_window),
        .busy(busy)
    );

    // AES de referencia usado apenas pelo testbench para montar o stream s.
    reg         ref_input_valid;
    reg [127:0] ref_input_block;
    wire        ref_input_ready;
    wire [127:0] ref_output_block;
    wire        ref_output_valid;
    wire        ref_busy;

    AES ref_aes (
        .clock        (clock),
        .reset_n      (reset_n),
        .input_valid  (ref_input_valid),
        .input_block  (ref_input_block),
        .input_ready  (ref_input_ready),
        .key          (key),
        .output_block (ref_output_block),
        .output_valid (ref_output_valid),
        .busy         (ref_busy)
    );

    always #5 clock = ~clock; // 100 MHz

    reg [REF_BITS-1:0] reference_stream;
    reg [127:0]        tmp_block;
    reg [WIN-1:0]      expected_window;

    integer i;
    integer bit_idx;
    integer batch_exp;
    integer cycle_exp;
    integer seen_windows;
    integer errors;
    integer safety;

    task aes_encrypt_counter;
        input  [31:0] ctr;
        output [127:0] block;
        begin
            @(negedge clock);
            while (!ref_input_ready) @(negedge clock);

            ref_input_block = {nonce, ctr};
            ref_input_valid = 1'b1;

            @(negedge clock);
            ref_input_valid = 1'b0;
            ref_input_block = 128'd0;

            wait (ref_output_valid == 1'b1);
            block = ref_output_block;
            @(negedge clock);
        end
    endtask

    task build_reference_stream;
        begin
            reference_stream = {REF_BITS{1'b0}};
            for (i = 0; i < REF_BLOCKS; i = i + 1) begin
                aes_encrypt_counter(i[31:0], tmp_block);
                for (bit_idx = 0; bit_idx < 128; bit_idx = bit_idx + 1) begin
                    if ((i * 128 + bit_idx) < REF_BITS)
                        reference_stream[i * 128 + bit_idx] = tmp_block[127 - bit_idx];
                end
            end
        end
    endtask

    function [WIN-1:0] get_expected_window;
        input integer batch;
        input integer cyc;
        integer k;
        integer start_idx;
        begin
            start_idx = batch * P + cyc * W;
            get_expected_window = {WIN{1'b0}};
            for (k = 0; k < WIN; k = k + 1) begin
                get_expected_window[k] = reference_stream[start_idx + k];
            end
        end
    endfunction

    initial begin
        clock           = 0;
        reset_n         = 0;
        prepare         = 0;
        go              = 0;
        ref_input_valid = 0;
        ref_input_block = 0;

        nonce = 96'h00000000_00000000_00000001;
        key   = 128'h2B7E151628AED2A6ABF7158809CF4F3C;

        errors       = 0;
        seen_windows = 0;
        batch_exp    = 0;
        cycle_exp    = 0;
        safety       = 0;

        $display("=================================================");
        $display("TB Seed Generator - AES-128 CTR + Hankel windows");
        $display("N=%0d L=%0d W=%0d P=%0d WIN=%0d CYCLES=%0d BATCHES=%0d", N, L, W, P, WIN, CYCLES, BATCHES);
        $display("Reference stream bits=%0d blocks AES=%0d", REF_BITS, REF_BLOCKS);
        $display("=================================================");

        repeat (4) @(negedge clock);
        reset_n = 1'b1;

        $display("[%0t ns] Construindo stream de referencia AES-CTR...", $time);
        build_reference_stream();
        $display("[%0t ns] Stream de referencia concluido.", $time);

        @(negedge clock);
        prepare = 1'b1;
        @(negedge clock);
        prepare = 1'b0;

        while ((seen_windows < TOTAL_WINDOWS) && (safety < 200000)) begin
            @(negedge clock);
            safety = safety + 1;
            go = 1'b0;

            if (ready_to_stream) begin
                expected_window = get_expected_window(batch_exp, cycle_exp);

                if (matrix_window !== expected_window) begin
                    $display("[%0t ns] ERRO batch=%0d ciclo=%0d", $time, batch_exp, cycle_exp);
                    $display("  esperado = %0h", expected_window);
                    $display("  obtido   = %0h", matrix_window);
                    errors = errors + 1;
                end else begin
                    $display("[%0t ns] OK batch=%0d ciclo=%0d janela=%0h", $time, batch_exp, cycle_exp, matrix_window);
                end

                go = 1'b1;
                seen_windows = seen_windows + 1;

                if (cycle_exp + 1 == CYCLES) begin
                    cycle_exp = 0;
                    batch_exp = batch_exp + 1;
                end else begin
                    cycle_exp = cycle_exp + 1;
                end
            end
        end

        // Permite que o ultimo pulso de go seja amostrado pelo DUT.
        @(posedge clock);
        @(negedge clock);
        go = 1'b0;

        repeat (10) @(posedge clock);

        $display("=================================================");
        $display("Janelas verificadas: %0d / %0d", seen_windows, TOTAL_WINDOWS);
        $display("Erros encontrados : %0d", errors);
        $display("Estado final DUT   : %0d | busy=%0b | ready=%0b", dut.state, busy, ready_to_stream);
        $display("=================================================");

        if (seen_windows != TOTAL_WINDOWS) begin
            $display("FALHA: timeout antes de verificar todas as janelas.");
            $finish;
        end

        if (errors == 0)
            $display("PASS: seed_generator manteve o mapeamento Hankel esperado.");
        else
            $display("FAIL: ha divergencias no mapeamento das janelas.");

        $finish;
    end

endmodule
