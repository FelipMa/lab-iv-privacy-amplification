`timescale 1ns/1ps

module top_tb();

    // Parâmetros solicitados
    parameter W = 2;
    parameter P = 3;
    parameter N = 10;
    parameter L = 6;

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
       =========================================================================
       Tamanho da chave (N) = 10 bits.
       Tamanho da hash final (L) = 6 bits.
       Matriz NxL (10x6).

       A matriz de Toeplitz precisa de uma "seed" de (N + L - 1) = 15 bits.
       
       --- Chave Hardcoded (10 bits) ---
       KEY = 10'b10_11_00_11_01
       Chunks (W=2): K[1:0]=01, K[3:2]=11, K[5:4]=00, K[7:6]=11, K[9:8]=10

       --- Matriz Hardcoded (Seed de 15 bits) ---
       SEED = 15'b010_101_001_110_110
       S[0]=0, S[1]=1, S[2]=1, S[3]=0, S[4]=1, S[5]=1, S[6]=1, S[7]=0, 
       S[8]=0, S[9]=1, S[10]=0, S[11]=1, S[12]=0, S[13]=1, S[14]=0

       Matriz 10x6 (M[linha][coluna] = S[linha + coluna]):
       Linha 0 (S[0..9])  : 0 1 1 0 1 1 1 0 0 1
       Linha 1 (S[1..10]) : 1 1 0 1 1 1 0 0 1 0
       Linha 2 (S[2..11]) : 1 0 1 1 1 0 0 1 0 1
       Linha 3 (S[3..12]) : 0 1 1 1 0 0 1 0 1 0
       Linha 4 (S[4..13]) : 1 1 1 0 0 1 0 1 0 1
       Linha 5 (S[5..14]) : 1 1 0 0 1 0 1 0 1 0

       Resultados Esperados (H = XOR(K AND Linha)):
       H0 = 1, H1 = 0, H2 = 1  => Batch 0 (H2, H1, H0) = 3'b101
       H3 = 1, H4 = 0, H5 = 0  => Batch 1 (H5, H4, H3) = 3'b001
    ========================================================================= */

    localparam [9:0]  KEY  = 10'b10_11_00_11_01;
    localparam [14:0] SEED = 15'b010_101_001_110_110;

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

        // Tempo suficiente para os 2 batches terminarem
        #200;
        $display("=== FIM DA SIMULACAO ===");
        $stop;
    end

    // 1. Lógica de injeção de dados
    // Atualizamos no negedge para não causar metaestabilidade nos registradores do top.v que leem no posedge
    always @(negedge clk_fpga) begin
        if (!rst_fpga) begin
            // Detecta quando um batch de P linhas termina (hc reseta de 4 para 0)
            if (hc_prev == 4 && hc == 0) begin
                batch_reg <= batch_reg + 1;
            end
            hc_prev <= hc;

            // Força a chave para o chunk atual
            force uut.current_key_chunk_reg = KEY[(hc * 2) +: 2];

            // Força a matriz deslizando a janela corretamente
            force uut.current_matrix_window_reg = SEED[(batch_reg * 3) + (hc * 2) +: 4];
        end
    end

    // 2. Captura e validação dos resultados
    always @(negedge clk_fpga) begin
        // Devido aos 2 estágios do pipeline, a acumulação final de uma linha termina 
        // 2 ciclos após o último chunk ser alimentado (quando hc == 1 do batch seguinte).
        if (!rst_fpga && hc_prev == 0 && hc == 1 && batch_reg > 0) begin
            
            if (batch_reg == 1) begin
                $display("\nTempo: %0t | --- FIM DO BATCH 0 (Linhas 0, 1 e 2) ---", $time);
                $display("Saida Real do Pipeline (current_hash_out) : %b", uut.current_hash_out);
                $display("Valor Esperado                              : 3'b101");
                
                if (uut.current_hash_out === 3'b101) $display("-> RESULTADO: SUCESSO!");
                else $display("-> RESULTADO: FALHA!");
                
                $display("Valor capturado pelo hash_register        : %b", uut.hash_register);
            end
            else if (batch_reg == 2) begin
                $display("\nTempo: %0t | --- FIM DO BATCH 1 (Linhas 3, 4 e 5) ---", $time);
                $display("Saida Real do Pipeline (current_hash_out) : %b", uut.current_hash_out);
                $display("Valor Esperado                              : 3'b001");
                
                if (uut.current_hash_out === 3'b001) $display("-> RESULTADO: SUCESSO!");
                else $display("-> RESULTADO: FALHA!");
                
                $display("Valor capturado pelo hash_register        : %b", uut.hash_register);
            end
        end
    end

endmodule