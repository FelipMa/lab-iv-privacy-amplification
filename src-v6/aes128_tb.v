`timescale 1ns/1ps

module aes128_tb;

    reg         clk;
    reg         reset_n;

    reg         input_valid;
    reg [127:0] input_block;
    wire        input_ready;

    reg [127:0] key;

    wire [127:0] output_block;
    wire         output_valid;
    wire         busy;

    integer r;
    integer errors;
    integer aes_cycles;
    integer aes_edges_including_start;
    integer edge_count;
    integer edge_at_start;

    localparam TB_ST_ROUND_COMMIT = 2'd2;

    reg [127:0] start_round      [0:10];
    reg [127:0] after_subbytes   [1:10];
    reg [127:0] after_shiftrows  [1:10];
    reg [127:0] after_mixcolumns [1:9];
    reg [127:0] round_key_value  [0:10];
    reg [127:0] after_addroundkey[0:10];

    reg [127:0] exp_start_round      [0:10];
    reg [127:0] exp_after_subbytes   [1:10];
    reg [127:0] exp_after_shiftrows  [1:10];
    reg [127:0] exp_after_mixcolumns [1:9];
    reg [127:0] exp_round_key_value  [0:10];
    reg [127:0] exp_after_addroundkey[0:10];
    reg [127:0] exp_ciphertext;

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

    always @(posedge clk) begin
        if (!reset_n)
            edge_count = 0;
        else
            edge_count = edge_count + 1;
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

    initial begin
        errors = 0;
        aes_cycles = 0;
        aes_edges_including_start = 0;
        edge_count = 0;
        edge_at_start = 0;

        key         = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        input_block = 128'h3243f6a8885a308d313198a2e0370734;

        exp_ciphertext = 128'h3925841d02dc09fbdc118597196a0b32;

        exp_start_round[0]       = 128'h3243f6a8885a308d313198a2e0370734;
        exp_round_key_value[0]   = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        exp_after_addroundkey[0] = 128'h193de3bea0f4e22b9ac68d2ae9f84808;

        exp_round_key_value[1]  = 128'ha0fafe1788542cb123a339392a6c7605;
        exp_round_key_value[2]  = 128'hf2c295f27a96b9435935807a7359f67f;
        exp_round_key_value[3]  = 128'h3d80477d4716fe3e1e237e446d7a883b;
        exp_round_key_value[4]  = 128'hef44a541a8525b7fb671253bdb0bad00;
        exp_round_key_value[5]  = 128'hd4d1c6f87c839d87caf2b8bc11f915bc;
        exp_round_key_value[6]  = 128'h6d88a37a110b3efddbf98641ca0093fd;
        exp_round_key_value[7]  = 128'h4e54f70e5f5fc9f384a64fb24ea6dc4f;
        exp_round_key_value[8]  = 128'head27321b58dbad2312bf5607f8d292f;
        exp_round_key_value[9]  = 128'hac7766f319fadc2128d12941575c006e;
        exp_round_key_value[10] = 128'hd014f9a8c9ee2589e13f0cc8b6630ca6;

        exp_start_round[1]       = 128'h193de3bea0f4e22b9ac68d2ae9f84808;
        exp_after_subbytes[1]    = 128'hd42711aee0bf98f1b8b45de51e415230;
        exp_after_shiftrows[1]   = 128'hd4bf5d30e0b452aeb84111f11e2798e5;
        exp_after_mixcolumns[1]  = 128'h046681e5e0cb199a48f8d37a2806264c;
        exp_after_addroundkey[1] = 128'ha49c7ff2689f352b6b5bea43026a5049;

        exp_start_round[2]       = 128'ha49c7ff2689f352b6b5bea43026a5049;
        exp_after_subbytes[2]    = 128'h49ded28945db96f17f39871a7702533b;
        exp_after_shiftrows[2]   = 128'h49db873b453953897f02d2f177de961a;
        exp_after_mixcolumns[2]  = 128'h584dcaf11b4b5aacdbe7caa81b6bb0e5;
        exp_after_addroundkey[2] = 128'haa8f5f0361dde3ef82d24ad26832469a;

        exp_start_round[3]       = 128'haa8f5f0361dde3ef82d24ad26832469a;
        exp_after_subbytes[3]    = 128'hac73cf7befc111df13b5d6b545235ab8;
        exp_after_shiftrows[3]   = 128'hacc1d6b8efb55a7b1323cfdf457311b5;
        exp_after_mixcolumns[3]  = 128'h75ec0993200b633353c0cf7cbb25d0dc;
        exp_after_addroundkey[3] = 128'h486c4eee671d9d0d4de3b138d65f58e7;

        exp_start_round[4]       = 128'h486c4eee671d9d0d4de3b138d65f58e7;
        exp_after_subbytes[4]    = 128'h52502f2885a45ed7e311c807f6cf6a94;
        exp_after_shiftrows[4]   = 128'h52a4c89485116a28e3cf2fd7f6505e07;
        exp_after_mixcolumns[4]  = 128'h0fd6daa9603138bf6fc0106b5eb31301;
        exp_after_addroundkey[4] = 128'he0927fe8c86363c0d9b1355085b8be01;

        exp_start_round[5]       = 128'he0927fe8c86363c0d9b1355085b8be01;
        exp_after_subbytes[5]    = 128'he14fd29be8fbfbba35c89653976cae7c;
        exp_after_shiftrows[5]   = 128'he1fb967ce8c8ae9b356cd2ba974ffb53;
        exp_after_mixcolumns[5]  = 128'h25d1a9adbd11d168b63a338e4c4cc0b0;
        exp_after_addroundkey[5] = 128'hf1006f55c1924cef7cc88b325db5d50c;

        exp_start_round[6]       = 128'hf1006f55c1924cef7cc88b325db5d50c;
        exp_after_subbytes[6]    = 128'ha163a8fc784f29df10e83d234cd503fe;
        exp_after_shiftrows[6]   = 128'ha14f3dfe78e803fc10d5a8df4c632923;
        exp_after_mixcolumns[6]  = 128'h4b868d6d2c4a8980339df4e837d218d8;
        exp_after_addroundkey[6] = 128'h260e2e173d41b77de86472a9fdd28b25;

        exp_start_round[7]       = 128'h260e2e173d41b77de86472a9fdd28b25;
        exp_after_subbytes[7]    = 128'hf7ab31f02783a9ff9b4340d354b53d3f;
        exp_after_shiftrows[7]   = 128'hf783403f27433df09bb531ff54aba9d3;
        exp_after_mixcolumns[7]  = 128'h1415b5bf461615ec274656d7342ad843;
        exp_after_addroundkey[7] = 128'h5a4142b11949dc1fa3e019657a8c040c;

        exp_start_round[8]       = 128'h5a4142b11949dc1fa3e019657a8c040c;
        exp_after_subbytes[8]    = 128'hbe832cc8d43b86c00ae1d44dda64f2fe;
        exp_after_shiftrows[8]   = 128'hbe3bd4fed4e1f2c80a642cc0da83864d;
        exp_after_mixcolumns[8]  = 128'h00512fd1b1c889ff54766dcdfa1b99ea;
        exp_after_addroundkey[8] = 128'hea835cf00445332d655d98ad8596b0c5;

        exp_start_round[9]       = 128'hea835cf00445332d655d98ad8596b0c5;
        exp_after_subbytes[9]    = 128'h87ec4a8cf26ec3d84d4c46959790e7a6;
        exp_after_shiftrows[9]   = 128'h876e46a6f24ce78c4d904ad897ecc395;
        exp_after_mixcolumns[9]  = 128'h473794ed40d4e4a5a3703aa64c9f42bc;
        exp_after_addroundkey[9] = 128'heb40f21e592e38848ba113e71bc342d2;

        exp_start_round[10]       = 128'heb40f21e592e38848ba113e71bc342d2;
        exp_after_subbytes[10]    = 128'he9098972cb31075f3d327d94af2e2cb5;
        exp_after_shiftrows[10]   = 128'he9317db5cb322c723d2e895faf090794;
        exp_after_addroundkey[10] = 128'h3925841d02dc09fbdc118597196a0b32;

        reset_n     = 1'b0;
        input_valid = 1'b0;

        repeat (3) @(posedge clk);
        reset_n = 1'b1;

        // Apresenta o bloco de entrada quando o AES está pronto.
        @(negedge clk);
        input_valid = 1'b1;

        @(posedge clk);
        #1;
        edge_at_start = edge_count;

        @(negedge clk);
        input_valid = 1'b0;

        start_round[0]       = input_block;
        round_key_value[0]   = key;
        after_addroundkey[0] = input_block ^ key;

        check128("input", start_round[0], exp_start_round[0]);
        check128("round_key[0]", round_key_value[0], exp_round_key_value[0]);
        check128("after_addroundkey[0]", after_addroundkey[0], exp_after_addroundkey[0]);

        for (r = 1; r <= 10; r = r + 1) begin

            // No estado ROUND_COMMIT os dados da S-box já chegaram das ROMs.
            wait (dut.fsm == TB_ST_ROUND_COMMIT);
            #1;

            start_round[r]      = dut.state;
            after_subbytes[r]   = dut.sub_state;
            after_shiftrows[r]  = dut.shifted_state;
            round_key_value[r]  = dut.next_round_key;

            if (r < 10) begin
                after_mixcolumns[r]  = dut.MixColumns(after_shiftrows[r]);
                after_addroundkey[r] = dut.middle_round_state;
            end else begin
                after_addroundkey[r] = dut.final_round_state;
            end

            $display("\nROUND %0d", r);

            check128("start_round",       start_round[r],       exp_start_round[r]);
            check128("after_subbytes",    after_subbytes[r],    exp_after_subbytes[r]);
            check128("after_shiftrows",   after_shiftrows[r],   exp_after_shiftrows[r]);

            if (r < 10) begin
                check128("after_mixcolumns", after_mixcolumns[r], exp_after_mixcolumns[r]);
            end

            check128("round_key",         round_key_value[r],   exp_round_key_value[r]);
            check128("after_addroundkey", after_addroundkey[r], exp_after_addroundkey[r]);

            @(posedge clk);
            #1;
        end

        check128("ciphertext final", output_block, exp_ciphertext);

        if (output_valid !== 1'b1) begin
            $display("ERRO   output_valid nao ficou em 1 no final da rodada 10");
            errors = errors + 1;
        end else begin
            $display("OK     output_valid ficou em 1 no final da rodada 10");
        end

        aes_cycles = edge_count - edge_at_start;
        aes_edges_including_start = aes_cycles + 1;

        $display("\nTEMPO DO AES");
        $display("Ciclos entre input_block aceito e output_valid: %0d", aes_cycles);
        $display("Bordas de clock ativas incluindo a borda que capturou input_block: %0d", aes_edges_including_start);

        if (aes_cycles !== 20) begin
            $display("AVISO  Esperava-se 20 ciclos apos o bloco ser aceito nesta arquitetura M9K10.");
        end else begin
            $display("OK     Latencia bateu com 20 ciclos apos o bloco ser aceito.");
        end

        if (errors == 0) begin
            $display("\nTESTE CONCLUIDO: todos os valores batem com o exemplo AES.");
        end else begin
            $display("\nTESTE CONCLUIDO COM %0d ERRO(S).", errors);
        end

        $finish;
    end

endmodule