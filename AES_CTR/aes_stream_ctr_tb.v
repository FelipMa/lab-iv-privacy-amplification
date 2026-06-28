`timescale 1ns/1ps

module aes_stream_ctr_tb;

    reg         clk;
    reg         reset_n;
    reg         input_valid;
    wire        input_ready;
    reg [127:0] input_block;
    reg [127:0] key;

    wire [127:0] output_block;
    wire         output_valid;
    wire         busy;

    localparam NUM_BLOCKS = 3;
    localparam EXPECTED_LATENCY = 20;

    integer errors;
    integer send_idx;
    integer recv_idx;
    integer cycle_count;

    integer accept_cycle [0:NUM_BLOCKS-1];
    integer output_cycle [0:NUM_BLOCKS-1];

    reg [127:0] ctr_block [0:NUM_BLOCKS-1];
    reg [127:0] exp_out   [0:NUM_BLOCKS-1];

    reg     handshake_before_edge;
    integer accepted_index_before_edge;

    AES dut (
        .clock        (clk),
        .reset_n      (reset_n),

        .input_valid  (input_valid),
        .input_block  (input_block),
        .input_ready  (input_ready),

        .key          (key),

        .output_block (output_block),
        .output_valid (output_valid),
        .busy         (busy)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task check128;
        input [1023:0] name;
        input [127:0]  got;
        input [127:0]  expected;
        begin
            if (got !== expected) begin
                $display("ERRO   %-32s got=%032h expected=%032h", name, got, expected);
                errors = errors + 1;
            end else begin
                $display("OK     %-32s %032h", name, got);
            end
        end
    endtask

    task check_integer;
        input [1023:0] name;
        input integer  got;
        input integer  expected;
        begin
            if (got !== expected) begin
                $display("ERRO   %-32s got=%0d expected=%0d", name, got, expected);
                errors = errors + 1;
            end else begin
                $display("OK     %-32s %0d", name, got);
            end
        end
    endtask

    initial begin
        errors = 0;
        send_idx = 0;
        recv_idx = 0;
        cycle_count = 0;
        handshake_before_edge = 1'b0;
        accepted_index_before_edge = 0;

        accept_cycle[0] = -1;
        accept_cycle[1] = -1;
        accept_cycle[2] = -1;
        output_cycle[0] = -1;
        output_cycle[1] = -1;
        output_cycle[2] = -1;

        key = 128'h2b7e151628aed2a6abf7158809cf4f3c;

        // Vetores CTR do NIST SP 800-38A:
        // output_block = AES_K(counter_block)
        ctr_block[0] = 128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdfeff;
        ctr_block[1] = 128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdff00;
        ctr_block[2] = 128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdff01;

        exp_out[0] = 128'hec8cdf7398607cb0f2d21675ea9ea1e4;
        exp_out[1] = 128'h362b7c3c6773516318a077d7fc5073ae;
        exp_out[2] = 128'h6a2cc3787889374fbeb4c81b17ba6c44;

        reset_n     = 1'b0;
        input_valid = 1'b0;
        input_block = 128'd0;

        repeat (5) @(posedge clk);
        reset_n = 1'b1;

        // Apresenta o primeiro bloco antes da primeira borda em que ele pode ser aceito.
        @(negedge clk);
        input_valid = 1'b1;
        input_block = ctr_block[0];
        send_idx    = 0;

        while (recv_idx < NUM_BLOCKS) begin
            // IMPORTANTE:
            // Este teste precisa amostrar input_valid && input_ready ANTES da borda.
            // Se fizermos @(negedge clk) aqui no começo do loop, perdemos o primeiro handshake.
            handshake_before_edge = input_valid && input_ready;
            accepted_index_before_edge = send_idx;

            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;

            if (handshake_before_edge) begin
                accept_cycle[accepted_index_before_edge] = cycle_count;

                $display("\nINPUT ACEITO %0d no ciclo %0d: %032h",
                         accepted_index_before_edge,
                         cycle_count,
                         ctr_block[accepted_index_before_edge]);
            end

            if (output_valid) begin
                output_cycle[recv_idx] = cycle_count;

                $display("\nOUTPUT %0d no ciclo %0d", recv_idx, cycle_count);
                check128("AES(counter)", output_block, exp_out[recv_idx]);

                if (accept_cycle[recv_idx] < 0) begin
                    $display("ERRO   output %0d ocorreu antes do input correspondente ser aceito", recv_idx);
                    errors = errors + 1;
                end else begin
                    check_integer("latencia input->output",
                                  output_cycle[recv_idx] - accept_cycle[recv_idx],
                                  EXPECTED_LATENCY);
                end

                if (recv_idx > 0) begin
                    check_integer("intervalo entre outputs",
                                  output_cycle[recv_idx] - output_cycle[recv_idx-1],
                                  EXPECTED_LATENCY);

                    check_integer("intervalo entre inputs aceitos",
                                  accept_cycle[recv_idx] - accept_cycle[recv_idx-1],
                                  EXPECTED_LATENCY);
                end

                recv_idx = recv_idx + 1;
            end

            // Atualiza o driver depois da borda, em tempo seguro,
            // sem alterar o input_block que acabou de ser capturado.
            @(negedge clk);
            if (handshake_before_edge) begin
                if (send_idx < NUM_BLOCKS-1) begin
                    send_idx    = send_idx + 1;
                    input_block = ctr_block[send_idx + 1];
                    input_valid = 1'b1;
                end else begin
                    input_valid = 1'b0;
                end
            end
        end

        $display("\nRESUMO DE TEMPO");
        $display("Latencia esperada por bloco: %0d ciclos", EXPECTED_LATENCY);

        $display("Input 0 aceito no ciclo:   %0d", accept_cycle[0]);
        $display("Output 0 valido no ciclo:  %0d", output_cycle[0]);
        $display("Latencia bloco 0:          %0d ciclos", output_cycle[0] - accept_cycle[0]);

        $display("Input 1 aceito no ciclo:   %0d", accept_cycle[1]);
        $display("Output 1 valido no ciclo:  %0d", output_cycle[1]);
        $display("Latencia bloco 1:          %0d ciclos", output_cycle[1] - accept_cycle[1]);

        $display("Input 2 aceito no ciclo:   %0d", accept_cycle[2]);
        $display("Output 2 valido no ciclo:  %0d", output_cycle[2]);
        $display("Latencia bloco 2:          %0d ciclos", output_cycle[2] - accept_cycle[2]);

        $display("Tempo total do primeiro input aceito ao ultimo output: %0d ciclos",
                 output_cycle[NUM_BLOCKS-1] - accept_cycle[0]);

        check_integer("tempo total esperado",
                      output_cycle[NUM_BLOCKS-1] - accept_cycle[0],
                      NUM_BLOCKS * EXPECTED_LATENCY);

        if (errors == 0) begin
            $display("\nTESTE STREAM CTR CONCLUIDO: dados e tempos batem.");
        end else begin
            $display("\nTESTE STREAM CTR CONCLUIDO COM %0d ERRO(S).", errors);
        end

        $finish;
    end

endmodule