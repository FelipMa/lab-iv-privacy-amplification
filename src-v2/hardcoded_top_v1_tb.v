`timescale 1ns/1ps

module hardcoded_top_v1_tb();

    // Parâmetros do módulo top
    parameter W = 32;
    parameter P = 32;
    parameter N = 128;
    parameter L = 64;

    // Sinais do testbench
    reg clk_fpga;
    reg rst_fpga;
    wire LED_done;

    // Variável local do testbench para reconstruir o que foi salvo na RAM
    reg [L-1:0] tb_reconstructed_result;

    // Instanciação do módulo Top
    hardcoded_top_v1 #(
        .W(W), .P(P), .N(N), .L(L)
    ) uut (
        .clk_fpga(clk_fpga),
        .rst_fpga(rst_fpga),
        .LED_done(LED_done)
    );

    // Geração de Clock: 100MHz = período de 10ns (5ns em alto, 5ns em baixo)
    always #5 clk_fpga = ~clk_fpga;

    // =========================================================================
    // Monitor de Gravação da RAM (Espião Sincronizado com o Pipeline)
    // =========================================================================
    // A altsyncram grava os dados na borda de subida do clock quando wren_a está alto.
    // Vamos imitar exatamente esse comportamento espionando os registradores de delay.
    always @(posedge clk_fpga) begin
        // O write enable agora é o estágio 1 do nosso shift register
        if (!rst_fpga && uut.capture_shift_reg[1]) begin
            
            // Salva na nossa variável local usando o endereço atrasado (delay_2)
            tb_reconstructed_result[uut.row_group_delay_2 * P +: P] <= uut.current_hash_out;
            
            $display("Tempo: %0t | RAM Write -> Endereco: %0d | Dado [HEX]: %h", 
                     $time, uut.row_group_delay_2, uut.current_hash_out);
        end
    end

    // =========================================================================
    // Bloco 1: Fluxo Principal (Inicialização e Validação)
    // =========================================================================
    initial begin
        // Inicialização
        clk_fpga = 0;
        rst_fpga = 1;
        tb_reconstructed_result = {L{1'b0}};

        $display("=== INICIANDO TESTBENCH ===");
        $display("Parametros: W=%0d, P=%0d, N=%0d, L=%0d", W, P, N, L);

        // Aguarda alguns ciclos e libera o reset
        #25;
        rst_fpga = 0;
        $display("Tempo: %0t | Reset liberado. Aguardando processamento...", $time);

        // Espera o sinal LED_done ir para nível lógico alto
        wait(LED_done == 1'b1);
        
        // Aguarda mais um ciclo de clock para garantir a estabilidade da leitura final
        #10; 
        
        $display("\nTempo: %0t | --- PROCESSAMENTO CONCLUIDO ---", $time);
        // Exibe a reconstrução local dos dados que foram gravados na altsyncram
        $display("Resultado Reconstruido da RAM [HEX] : 64'h%h", tb_reconstructed_result);
        $display("Resultado Reconstruido da RAM [BIN] : %b", tb_reconstructed_result);
        $display("=== FIM DA SIMULACAO ===");
        
        // Encerra a simulação
        $stop; 
    end

    // =========================================================================
    // Bloco 2: Watchdog Timer (Segurança contra loops infinitos)
    // =========================================================================
    initial begin
        // Timeout de 5000ns (500 ciclos)
        #5000; 
        $display("\n[ERRO] Tempo: %0t | Timeout atingido! O sinal LED_done nao foi ativado.", $time);
        $stop;
    end

endmodule