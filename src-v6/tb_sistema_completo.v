`timescale 1ns/1ps

module tb_sistema_completo;

    parameter N = 640;
    parameter W = 64;
    parameter P = 32;
    parameter L = 64;
    parameter ROM_ADDR_BITS = 5;
    parameter MEM_DEPTH = 32;
    parameter AES_CYCLES = 20;
    parameter [127:0] SEED_KEY   = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
    parameter [95:0]  SEED_NONCE = 96'h000000000000000000000001;

    localparam CYCLES  = (N + W - 1) / W;
    localparam BATCHES = (L + P - 1) / P;

    reg clock;
    reg reset;

    wire [P-1:0] hash_register;
    wire         batch_ready;
    wire         done;

    integer batch_count;
    integer cycle_count;
    reg [L-1:0] chave_final;
    reg [L-1:0] chave_final_next;

    top #(
        .N(N),
        .W(W),
        .P(P),
        .L(L),
        .ROM_ADDR_BITS(ROM_ADDR_BITS),
        .MEM_DEPTH(MEM_DEPTH),
        .AES_CYCLES(AES_CYCLES),
        .SEED_KEY(SEED_KEY),
        .SEED_NONCE(SEED_NONCE)
    ) uut_top (
        .clock(clock),
        .reset(reset),
        .hash_register(hash_register),
        .batch_ready(batch_ready),
        .done(done)
    );

    initial begin
        clock = 1'b0;
        forever #5 clock = ~clock; // 100 MHz
    end

    initial begin
        reset       = 1'b1;
        batch_count = 0;
        cycle_count = 0;
        chave_final = {L{1'b0}};
        chave_final_next = {L{1'b0}};

        $display("============================================================");
        $display(" TB SIMPLES - CAPTURA DA CHAVE FINAL");
        $display(" N=%0d L=%0d W=%0d P=%0d CYCLES=%0d BATCHES=%0d", N, L, W, P, CYCLES, BATCHES);
        $display("============================================================");

        repeat (5) @(posedge clock);
        reset = 1'b0;
        $display("[%0t] Reset liberado. Aguardando batches...", $time);
    end

    always @(posedge clock) begin
        if (!reset) begin
            cycle_count <= cycle_count + 1;

            if (batch_ready) begin
                chave_final_next = chave_final;
                chave_final_next[batch_count*P +: P] = hash_register;
                chave_final <= chave_final_next;

                $display("[%0t] LOTE %0d pronto: hash_out = 0x%0h", $time, batch_count, hash_register);

                batch_count <= batch_count + 1;

                if (batch_count + 1 == BATCHES) begin
                    @(posedge clock);
                    $display("============================================================");
                    $display(" CHAVE FINAL CONCATENADA = 0x%0h", chave_final_next);
                    $display(" Batches capturados      = %0d / %0d", BATCHES, BATCHES);
                    $display(" done do top             = %0b", done);
                    $display("============================================================");
                    $finish;
                end
            end

            // Timeout simples para nao rodar para sempre se o DUT travar.
            if (cycle_count == 200000) begin
                $display("============================================================");
                $display(" TIMEOUT: a simulacao nao capturou todos os batches.");
                $display(" Batches capturados = %0d / %0d", batch_count, BATCHES);
                $display(" Chave parcial      = 0x%0h", chave_final);
                $display(" done               = %0b", done);
                $display(" ctrl_state         = %0d", uut_top.u_controlador.current_state);
                $display(" ctrl_batch_idx     = %0d", uut_top.u_controlador.batch_idx);
                $display(" ctrl_words_idx     = %0d", uut_top.u_controlador.words_idx);
                $display(" buf_ready          = %0b", uut_top.buf_ready);
                $display(" buf_out_valid      = %0b", uut_top.buf_out_valid);
                $display(" seed_ready         = %0b", uut_top.seed_ready);
                $display("============================================================");
                $finish;
            end
        end
    end

endmodule
