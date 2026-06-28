`timescale 1ns/1ps

module CTR_seed_controller_tb;

    reg         clk;
    reg         reset_n;
    reg         start;

    reg [127:0] key;
    reg [95:0]  nonce;
    reg [31:0]  initial_counter;

    wire [127:0] seed_block;
    wire         seed_valid;
    wire [31:0]  seed_counter;

    wire         running;
    wire [31:0]  accepted_blocks;
    wire [31:0]  generated_blocks;

    wire         counter_accepted_valid;
    wire [31:0]  counter_accepted;

    localparam NUM_BLOCKS = 3;
    localparam EXPECTED_LATENCY = 20;

    integer errors;
    integer cycle_count;
    integer recv_count;
    integer idx;

    integer accept_cycle [0:NUM_BLOCKS-1];
    integer output_cycle [0:NUM_BLOCKS-1];

    reg [31:0]  exp_counter [0:NUM_BLOCKS-1];
    reg [127:0] exp_seed    [0:NUM_BLOCKS-1];

    CTR_seed_controller dut (
        .clock                  (clk),
        .reset_n                (reset_n),
        .start                  (start),

        .key                    (key),
        .nonce                  (nonce),
        .initial_counter         (initial_counter),

        .seed_block             (seed_block),
        .seed_valid             (seed_valid),
        .seed_counter           (seed_counter),

        .running                (running),
        .accepted_blocks        (accepted_blocks),
        .generated_blocks       (generated_blocks),

        .counter_accepted_valid (counter_accepted_valid),
        .counter_accepted       (counter_accepted)
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

    initial begin
        errors = 0;
        cycle_count = 0;
        recv_count = 0;

        accept_cycle[0] = -1;
        accept_cycle[1] = -1;
        accept_cycle[2] = -1;
        output_cycle[0] = -1;
        output_cycle[1] = -1;
        output_cycle[2] = -1;

        // Vetores CTR do NIST SP 800-38A.
        // seed = AES_K(nonce || counter)
        key             = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        nonce           = 96'hf0f1f2f3f4f5f6f7f8f9fafb;
        initial_counter = 32'hfcfdfeff;

        exp_counter[0] = 32'hfcfdfeff;
        exp_counter[1] = 32'hfcfdff00;
        exp_counter[2] = 32'hfcfdff01;

        exp_seed[0] = 128'hec8cdf7398607cb0f2d21675ea9ea1e4;
        exp_seed[1] = 128'h362b7c3c6773516318a077d7fc5073ae;
        exp_seed[2] = 128'h6a2cc3787889374fbeb4c81b17ba6c44;

        reset_n = 1'b0;
        start   = 1'b0;

        repeat (5) @(posedge clk);
        reset_n = 1'b1;

        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        while (recv_count < NUM_BLOCKS) begin
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;

            if (counter_accepted_valid) begin
                idx = counter_accepted - initial_counter;

                $display("\nCOUNTER ACEITO no ciclo %0d: %08h", cycle_count, counter_accepted);

                if (idx >= 0 && idx < NUM_BLOCKS) begin
                    accept_cycle[idx] = cycle_count;
                    check32("counter aceito", counter_accepted, exp_counter[idx]);
                end
            end

            if (seed_valid) begin
                idx = seed_counter - initial_counter;
                output_cycle[idx] = cycle_count;

                $display("\nSEED GERADA %0d no ciclo %0d", idx, cycle_count);
                check32 ("seed_counter", seed_counter, exp_counter[idx]);
                check128("seed_block", seed_block, exp_seed[idx]);

                if (accept_cycle[idx] < 0) begin
                    $display("ERRO   seed gerada antes do counter correspondente ser aceito");
                    errors = errors + 1;
                end else begin
                    check_integer("latencia counter->seed",
                                  output_cycle[idx] - accept_cycle[idx],
                                  EXPECTED_LATENCY);
                end

                if (idx > 0) begin
                    check_integer("intervalo entre seeds",
                                  output_cycle[idx] - output_cycle[idx-1],
                                  EXPECTED_LATENCY);
                end

                recv_count = recv_count + 1;
            end
        end

        $display("\nRESUMO");
        $display("Counter 0 aceito no ciclo: %0d", accept_cycle[0]);
        $display("Seed 0 gerada no ciclo:    %0d", output_cycle[0]);
        $display("Counter 1 aceito no ciclo: %0d", accept_cycle[1]);
        $display("Seed 1 gerada no ciclo:    %0d", output_cycle[1]);
        $display("Counter 2 aceito no ciclo: %0d", accept_cycle[2]);
        $display("Seed 2 gerada no ciclo:    %0d", output_cycle[2]);

        check_integer("tempo total counter0->seed2",
                      output_cycle[2] - accept_cycle[0],
                      NUM_BLOCKS * EXPECTED_LATENCY);

        if (errors == 0) begin
            $display("\nTESTE CTR SEED CONTROLLER CONCLUIDO: dados e tempos batem.");
        end else begin
            $display("\nTESTE CTR SEED CONTROLLER CONCLUIDO COM %0d ERRO(S).", errors);
        end

        $finish;
    end

endmodule
