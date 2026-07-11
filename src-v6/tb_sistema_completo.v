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

    // Timeout mais folgado porque o novo seed_generator tem warmup por rajadas AES.
    localparam TIMEOUT_CYCLES = 500000;

    reg clock;
    reg reset;

    wire [P-1:0] hash_register;
    wire         batch_ready;
    wire         done;

    integer batch_count;
    integer cycle_count;
    integer i;

    reg [L-1:0] chave_final;
    reg [L-1:0] chave_final_next;

    // Para capturar somente os bits validos do ultimo lote,
    // caso L nao seja multiplo de P.
    integer bit_global;

    top #(
        .N(N),
        .W(W),
        .P(P),
        .L(L),
        .AES_CYCLES(AES_CYCLES),
        .SEED_KEY(SEED_KEY),
        .SEED_NONCE(SEED_NONCE)
    ) uut_top (
        .clock         (clock),
        .reset         (reset),
        .hash_register (hash_register),
        .batch_ready   (batch_ready),
        .done          (done)
    );

    // Clock de 100 MHz: periodo de 10 ns.
    initial begin
        clock = 1'b0;
        forever #5 clock = ~clock;
    end

    initial begin
        reset            = 1'b1;
        batch_count      = 0;
        cycle_count      = 0;
        chave_final      = {L{1'b0}};
        chave_final_next = {L{1'b0}};

        $display("============================================================");
        $display(" TB SISTEMA COMPLETO - NOVO SEED GENERATOR BURST AES");
        $display(" N=%0d L=%0d W=%0d P=%0d", N, L, W, P);
        $display(" CYCLES por lote = %0d", CYCLES);
        $display(" BATCHES         = %0d", BATCHES);
        $display(" AES_CYCLES      = %0d", AES_CYCLES);
        $display("============================================================");

        repeat (5) @(posedge clock);
        reset = 1'b0;

        $display("[%0t] Reset liberado. Aguardando processamento...", $time);
    end

    // Contador geral de ciclos e timeout.
    always @(posedge clock) begin
        if (reset) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            if (cycle_count == TIMEOUT_CYCLES) begin
                $display("============================================================");
                $display(" TIMEOUT: a simulacao nao capturou todos os batches.");
                $display(" Ciclos simulados       = %0d", cycle_count);
                $display(" Batches capturados     = %0d / %0d", batch_count, BATCHES);
                $display(" Chave parcial          = 0x%0h", chave_final);
                $display(" done                   = %0b", done);

                $display("------------------------------------------------------------");
                $display(" DEBUG CONTROLADOR");
                $display(" ctrl_state             = %0d", uut_top.u_controlador.current_state);
                $display(" ctrl_batch_idx         = %0d", uut_top.u_controlador.batch_idx);
                $display(" ctrl_words_idx         = %0d", uut_top.u_controlador.words_idx);
                $display(" buf_ready              = %0b", uut_top.buf_ready);
                $display(" seed_ready             = %0b", uut_top.seed_ready);
                $display(" buf_go                 = %0b", uut_top.buf_go);
                $display(" seed_go                = %0b", uut_top.seed_go);
                $display(" enable                 = %0b", uut_top.enable);

                $display("------------------------------------------------------------");
                $display(" DEBUG SEED GENERATOR");
                $display(" seed_state             = %0d", uut_top.u_seed_generator.state);
                $display(" seed_batch_idx         = %0d", uut_top.u_seed_generator.batch_idx);
                $display(" seed_cycle_in_batch    = %0d", uut_top.u_seed_generator.cycle_in_batch);
                $display(" seed_slot_word_idx     = %0d", uut_top.u_seed_generator.slot_word_idx);
                $display(" seed_standby_valid     = %0b", uut_top.u_seed_generator.standby_valid);
                $display(" seed_chunk_valid_r     = %0b", uut_top.u_seed_generator.chunk_valid_r);
                $display(" seed_busy              = %0b", uut_top.seed_busy);
                $display("============================================================");

                $finish;
            end
        end
    end

    // Captura dos lotes prontos.
    always @(posedge clock) begin
        if (reset) begin
            batch_count      <= 0;
            chave_final      <= {L{1'b0}};
            chave_final_next <= {L{1'b0}};
        end else begin
            if (batch_ready) begin
                chave_final_next = chave_final;

                // Copia apenas os bits validos.
                // Para L multiplo de P, copia P bits normalmente.
                // Para ultimo lote parcial, ignora bits acima de L-1.
                for (i = 0; i < P; i = i + 1) begin
                    bit_global = batch_count * P + i;

                    if (bit_global < L) begin
                        chave_final_next[bit_global] = hash_register[i];
                    end
                end

                chave_final <= chave_final_next;

                $display("[%0t] LOTE %0d pronto: hash_out = 0x%0h",
                         $time, batch_count, hash_register);

                batch_count <= batch_count + 1;

                if (batch_count + 1 == BATCHES) begin
                    @(posedge clock);

                    $display("============================================================");
                    $display(" CHAVE FINAL CONCATENADA = 0x%0h", chave_final_next);
                    $display(" Batches capturados      = %0d / %0d", BATCHES, BATCHES);
                    $display(" done do top             = %0b", done);
                    $display(" Ciclos simulados        = %0d", cycle_count);
                    $display("============================================================");

                    $finish;
                end
            end
        end
    end

endmodule