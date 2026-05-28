`timescale 1ns/1ps

module top_tb();

    // Parâmetros
    parameter W = 32;
    parameter P = 32;
    parameter N = 128;
    parameter L = 64;

    // Sinais do testbench
    reg clk_fpga;
    reg rst_fpga;
    wire LED_done;

    // Instanciação do módulo Top
    top #(
        .W(W), .P(P), .N(N), .L(L)
    ) uut (
        .clk_fpga(clk_fpga),
        .rst_fpga(rst_fpga),
        .LED_done(LED_done)
    );

    // Geração de Clock: 100MHz = período de 10ns (5ns em alto, 5ns em baixo)
    always #5 clk_fpga = ~clk_fpga;

    /* =========================================================================
       DADOS HARDCODED (CHAVE E MATRIZ)
       ========================================================================= */
    // Chave de 128 bits
    localparam [127:0] KEY  = 128'h7F4D92B1C0E8A3549B62F10D85A7C3E9;
    
    // Seed de 192 bits (48 caracteres HEX). O algoritmo consumirá até N+L-1 (191 bits).
    localparam [191:0] SEED = 192'h6A2F8B10C5D4E92A3B84F716D09E5C3B2A1F8D4E76B093C1;

    // Cálculo automático do hash esperado para validação do pipeline
    reg [L-1:0] expected_hash_full;
    integer i, j;
    initial begin
        expected_hash_full = {L{1'b0}};
        for (i = 0; i < L; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                expected_hash_full[i] = expected_hash_full[i] ^ (KEY[j] & SEED[i + j]);
            end
        end
    end

    // Fios para monitorar o estado interno de maneira limpa
    wire [15:0] hc = uut.hash_counter;
    reg [15:0]  hc_prev;
    reg [1:0]   batch_reg;

    initial begin
        // Inicialização
        clk_fpga = 0;
        rst_fpga = 1;
        hc_prev = 0;
        batch_reg = 0;

        $display("=== INICIANDO TESTBENCH ===");
        $display("Parametros: W=%0d, P=%0d, N=%0d, L=%0d", W, P, N, L);

        // Aguarda alguns ciclos e libera o reset
        #25;
        rst_fpga = 0;

        // Tempo suficiente para os 2 batches terminarem (cerca de 8 a 10 clocks de processamento)
        #300;
        $display("=== FIM DA SIMULACAO ===");
        $stop;
    end

    // 1. Lógica de injeção de dados
    // Atualizamos no negedge para não causar metaestabilidade nos registradores do top.v que leem no posedge
    always @(negedge clk_fpga) begin
        if (!rst_fpga) begin
            // Detecta quando um batch de P linhas termina
            // Como N/W = 128/32 = 4, o contador vai de 0 a 3.
            if (hc_prev == 3 && hc == 0) begin
                batch_reg <= batch_reg + 1;
            end
            hc_prev <= hc;
            
            // Força a chave para o chunk atual (32 bits de deslocamento)
            force uut.current_key_chunk_reg = KEY[(hc * 32) +: 32];
            
            // Força a matriz deslizando a janela corretamente (W+P-1 = 63 bits)
            force uut.current_matrix_window_reg = SEED[(batch_reg * 32) + (hc * 32) +: 63];
        end
    end

    // 2. Captura e validação dos resultados
    always @(negedge clk_fpga) begin
        // Devido aos 2 estágios do pipeline, a acumulação final de uma linha termina 
        // 2 ciclos após o último chunk ser alimentado (quando hc == 1 do batch seguinte).
        if (!rst_fpga && hc_prev == 0 && hc == 1 && batch_reg > 0) begin
            
            if (batch_reg == 1) begin
                $display("\nTempo: %0t | --- FIM DO BATCH 0 (Linhas 0 a 31) ---", $time);
                $display("Saida Real do Pipeline (current_hash_out) : %h", uut.current_hash_out);
                $display("Valor Esperado Dinâmico                   : %h", expected_hash_full[0 +: 32]);
                if (uut.current_hash_out === expected_hash_full[0 +: 32]) $display("-> RESULTADO: SUCESSO!");
                else $display("-> RESULTADO: FALHA!");
                $display("Valor capturado pelo hash_register        : %h", uut.hash_register);
            end
            else if (batch_reg == 2) begin
                $display("\nTempo: %0t | --- FIM DO BATCH 1 (Linhas 32 a 63) ---", $time);
                $display("Saida Real do Pipeline (current_hash_out) : %h", uut.current_hash_out);
                $display("Valor Esperado Dinâmico                   : %h", expected_hash_full[32 +: 32]);
                if (uut.current_hash_out === expected_hash_full[32 +: 32]) $display("-> RESULTADO: SUCESSO!");
                else $display("-> RESULTADO: FALHA!");
                $display("Valor capturado pelo hash_register        : %h", uut.hash_register);
            end
        end
    end

endmodule