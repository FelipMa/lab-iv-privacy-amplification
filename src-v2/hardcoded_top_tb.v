`timescale 1ns/1ps

module hardcoded_top_tb();

    // Parâmetros do novo módulo top
    parameter W = 32;
    parameter P = 32;
    parameter N = 128;
    parameter L = 64;

    // Sinais do testbench
    reg clk_fpga;
    reg rst_fpga;
    wire LED_done;

    // Instanciação do módulo Top
    hardcoded_top #(
        .W(W), .P(P), .N(N), .L(L)
    ) uut (
        .clk_fpga(clk_fpga),
        .rst_fpga(rst_fpga),
        .LED_done(LED_done)
    );

    // Geração de Clock: 100MHz = período de 10ns (5ns em alto, 5ns em baixo)
    always #5 clk_fpga = ~clk_fpga;

    // =========================================================================
    // Bloco 1: Fluxo Principal (Inicialização e Validação)
    // =========================================================================
    initial begin
        // Inicialização
        clk_fpga = 0;
        rst_fpga = 1;

        $display("=== INICIANDO TESTBENCH ===");
        $display("Parametros: W=%0d, P=%0d, N=%0d, L=%0d", W, P, N, L);

        // Aguarda alguns ciclos e libera o reset
        #25;
        rst_fpga = 0;
        $display("Tempo: %0t | Reset liberado. Aguardando processamento...", $time);

        // Espera o sinal LED_done ir para nível lógico alto
        wait(LED_done == 1'b1);
        
        // Aguarda mais um ciclo de clock para garantir a estabilidade da leitura
        #10; 
        
        $display("\nTempo: %0t | --- PROCESSAMENTO CONCLUIDO ---", $time);
        // Lê diretamente o registrador interno simulando a memória externa
        $display("Resultado Final (final_result) [HEX] : 64'h%h", uut.final_result);
        $display("Resultado Final (final_result) [BIN] : %b", uut.final_result);
        $display("=== FIM DA SIMULACAO ===");
        
        // Encerra a simulação
        $stop; 
    end

    // =========================================================================
    // Bloco 2: Watchdog Timer (Roda em paralelo com o bloco 1)
    // =========================================================================
    initial begin
        // Timeout de 5000ns (500 ciclos)
        // Se o processamento demorar mais que isso, a máquina travou.
        #5000; 
        $display("\n[ERRO] Tempo: %0t | Timeout atingido! O sinal LED_done nao foi ativado.", $time);
        $stop;
    end

endmodule