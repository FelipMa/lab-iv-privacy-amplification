`timescale 1ns/1ps

module CTR_seed_controller_tb;

    reg         clk;
    reg         reset_n;

    reg         counter_load_valid;
    reg [31:0]  counter_load_value;
    wire        counter_load_ready;

    reg [127:0] key;
    reg [95:0]  nonce;

    wire [127:0] seed_block;
    wire         seed_valid;
    wire [31:0]  seed_counter;

    wire         running;
    wire [31:0]  accepted_blocks;
    wire [31:0]  generated_blocks;

    wire         counter_accepted_valid;
    wire [31:0]  counter_accepted;

    wire [31:0]  next_counter_debug;
    wire         aes_input_ready_debug;

    localparam [31:0] STEP = 32'd4;
    localparam integer EXPECTED_LATENCY = 20;
    localparam integer NUM_EXPECTED = 4;

    integer errors;
    integer cycle_count;
    integer output_count;
    integer i;
    integer idx;

    integer accept_cycle [0:NUM_EXPECTED-1];
    integer output_cycle [0:NUM_EXPECTED-1];

    reg [31:0]  exp_counter [0:NUM_EXPECTED-1];
    reg [127:0] exp_seed    [0:NUM_EXPECTED-1];

    reg reload_done;

    CTR_seed_controller #(
        .COUNTER_STEP(STEP)
    ) dut (
        .clock                  (clk),
        .reset_n                (reset_n),

        .counter_load_valid     (counter_load_valid),
        .counter_load_value     (counter_load_value),
        .counter_load_ready     (counter_load_ready),

        .key                    (key),
        .nonce                  (nonce),

        .seed_block             (seed_block),
        .seed_valid             (seed_valid),
        .seed_counter           (seed_counter),

        .running                (running),
        .accepted_blocks        (accepted_blocks),
        .generated_blocks       (generated_blocks),

        .counter_accepted_valid (counter_accepted_valid),
        .counter_accepted       (counter_accepted),

        .next_counter_debug     (next_counter_debug),
        .aes_input_ready_debug  (aes_input_ready_debug)
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

    task check32;
        input [1023:0] name;
        input [31:0]   got;
        input [31:0]   expected;
        begin
            if (got !== expected) begin
                $display("ERRO   %-32s got=%08h expected=%08h", name, got, expected);
                errors = errors + 1;
            end else begin
                $display("OK     %-32s %08h", name, got);
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

    function integer find_counter_index;
        input [31:0] counter;
        integer k;
        begin
            find_counter_index = -1;
            for (k = 0; k < NUM_EXPECTED; k = k + 1) begin
                if (counter == exp_counter[k]) begin
                    find_counter_index = k;
                end
            end
        end
    endfunction

    // Monitor principal.
    always @(posedge clk) begin
        #1;

        if (reset_n) begin
            cycle_count = cycle_count + 1;

            if (counter_accepted_valid) begin
                idx = find_counter_index(counter_accepted);

                $display("\nCOUNTER ACEITO no ciclo %0d: %08h", cycle_count, counter_accepted);

                if (idx >= 0) begin
                    accept_cycle[idx] = cycle_count;
                    check32("counter aceito", counter_accepted, exp_counter[idx]);
                end else begin
                    $display("AVISO  counter aceito fora da lista verificada: %08h", counter_accepted);
                end
            end

            if (seed_valid) begin
                idx = find_counter_index(seed_counter);

                $display("\nSEED GERADA no ciclo %0d para counter %08h", cycle_count, seed_counter);

                if (idx >= 0) begin
                    output_cycle[idx] = cycle_count;

                    check32 ("seed_counter", seed_counter, exp_counter[idx]);
                    check128("seed_block", seed_block, exp_seed[idx]);

                    if (accept_cycle[idx] >= 0) begin
                        check_integer("latencia counter->seed",
                                      output_cycle[idx] - accept_cycle[idx],
                                      EXPECTED_LATENCY);
                    end else begin
                        $display("ERRO   seed saiu antes do counter correspondente ser aceito");
                        errors = errors + 1;
                    end

                    output_count = output_count + 1;
                end else begin
                    $display("AVISO  seed de counter nao verificado neste TB: %08h", seed_counter);
                end
            end
        end
    end

    initial begin
        errors = 0;
        cycle_count = 0;
        output_count = 0;
        reload_done = 0;

        for (i = 0; i < NUM_EXPECTED; i = i + 1) begin
            accept_cycle[i] = -1;
            output_cycle[i] = -1;
        end

        key   = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        nonce = 96'hf0f1f2f3f4f5f6f7f8f9fafb;

        // Teste com STEP = 4.
        //
        // Primeiro carregamos fcfdfeff.
        // Com step 4, o proximo seria fcfdff03.
        //
        // Depois que a primeira seed sai, fazemos reload para fcfdff00
        // enquanto o AES processa fcfdff03.
        //
        // Sequencia esperada de saidas:
        //   fcfdfeff
        //   fcfdff03
        //   fcfdff00
        //   fcfdff04

        exp_counter[0] = 32'hfcfdfeff;
        exp_counter[1] = 32'hfcfdff03;
        exp_counter[2] = 32'hfcfdff00;
        exp_counter[3] = 32'hfcfdff04;

        exp_seed[0] = 128'hec8cdf7398607cb0f2d21675ea9ea1e4;
        exp_seed[1] = 128'hb00d47f8148a910ef0683097904ba502;
        exp_seed[2] = 128'h362b7c3c6773516318a077d7fc5073ae;
        exp_seed[3] = 128'h5899445a4de101f513cad1987d89e91b;

        reset_n = 1'b0;
        counter_load_valid = 1'b0;
        counter_load_value = 32'd0;

        repeat (5) @(posedge clk);
        reset_n = 1'b1;

        // Carrega o primeiro contador.
        @(negedge clk);
        counter_load_value = 32'hfcfdfeff;
        counter_load_valid = 1'b1;

        @(negedge clk);
        counter_load_valid = 1'b0;

        // Espera a primeira seed e entao reposiciona para fcfdff00.
        // Isso demonstra que o counter pode ser alterado por input.
        wait (seed_valid && seed_counter == 32'hfcfdfeff);

        @(negedge clk);
        counter_load_value = 32'hfcfdff00;
        counter_load_valid = 1'b1;
        reload_done = 1'b1;

        @(negedge clk);
        counter_load_valid = 1'b0;

        wait (output_count >= NUM_EXPECTED);

        $display("\nRESUMO");
        $display("COUNTER_STEP configurado: %0d", STEP);
        $display("Sequencia verificada:");
        $display("  %08h", exp_counter[0]);
        $display("  %08h", exp_counter[1]);
        $display("  %08h", exp_counter[2]);
        $display("  %08h", exp_counter[3]);

        $display("\nCiclos:");
        for (i = 0; i < NUM_EXPECTED; i = i + 1) begin
            $display("counter %08h aceito=%0d seed=%0d latencia=%0d",
                     exp_counter[i],
                     accept_cycle[i],
                     output_cycle[i],
                     output_cycle[i] - accept_cycle[i]);
        end

        if (errors == 0) begin
            $display("\nTESTE CTR CONTROLLER CONCLUIDO: dados e tempos batem.");
        end else begin
            $display("\nTESTE CTR CONTROLLER CONCLUIDO COM %0d ERRO(S).", errors);
        end

        $finish;
    end

endmodule
