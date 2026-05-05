`timescale 1ns/1ps

module top_tb;
    // Parâmetros do teste
    parameter W_TB = 64;
    parameter P_TB = 1042; // Valor calculado para 150MHz/10%
    parameter N_TB = 1000000;

    reg clk_fpga;
    reg rst_fpga;
    wire LED_done;

    // Instanciação do Top com parâmetros sobrescritos
    top #(
        .W(W_TB),
        .P(P_TB),
        .N(N_TB)
    ) uut (
        .clk_fpga(clk_fpga),
        .rst_fpga(rst_fpga),
        .LED_done(LED_done)
    );

    // Geração do Clock de 150 MHz (Período ~6.666 ns)
    initial clk_fpga = 0;
    always #3.333 clk_fpga = ~clk_fpga;

    initial begin
        // Inicialização
        rst_fpga = 1;
        $display("Iniciando Simulação: f=150MHz, W=%0d, P=%0d", W_TB, P_TB);
        
        #20;
        rst_fpga = 0;

        // Aguarda o processamento de uma linha (N/W ciclos)
        // Para W=64, N=10^6 -> 15625 ciclos
        repeat (15630) @(posedge clk_fpga);

        $display("Simulação concluída para uma iteração de linha.");
        $stop;
    end
endmodule