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
        // Garante que só validamos os batches 1 e 2
        if (!rst_fpga && batch_reg > 0 && batch_reg <= 2) begin
            
            // =========================================================
            // INSTANTE 1: O pipeline exibe o valor final (hc == 1)
            // =========================================================
            if (hc_prev == 0 && hc == 1) begin
                $display("\nTempo: %0t | --- FIM DO BATCH %0d (Linhas %0d a %0d) ---", 
                          $time, batch_reg - 1, (batch_reg-1)*32, (batch_reg*32)-1);
                $display("Saida Real do Pipeline (current_hash_out) : %h", uut.current_hash_out);
                $display("Valor Esperado Dinâmico                   : %h", expected_hash_full[((batch_reg-1)*32) +: 32]);
                
                if (uut.current_hash_out === expected_hash_full[((batch_reg-1)*32) +: 32]) 
                    $display("-> STATUS PIPELINE    : SUCESSO!");
                else 
                    $display("-> STATUS PIPELINE    : FALHA!");
            end
            
            // =========================================================
            // INSTANTE 2: O registrador gravou a saída (hc == 2)
            // =========================================================
            if (hc_prev == 1 && hc == 2) begin
                $display("Valor capturado pelo hash_register        : %h", uut.hash_register);
                
                if (uut.hash_register === expected_hash_full[((batch_reg-1)*32) +: 32]) 
                    $display("-> STATUS REGISTRADOR : SUCESSO!");
                else 
                    $display("-> STATUS REGISTRADOR : FALHA!");
            end
            
        end
    end

endmodule