`timescale 1ns/1ps

module compression_unit_tb;

    // Parâmetros Globais do TB
    parameter P = 4;
    parameter W = 32;

    // Sinais parametrizados
    reg clock;
    reg reset;
    reg [W-1:0] key;
    reg [(W+P-2):0] matrix_window; 
    wire [P-1:0] hash_out;

    // Instanciação da Compression Unit
    compression_unit #(
        .P(P),
        .W(W)
    ) uut (
        .clock         (clock),
        .reset         (reset),
        .key           (key),
        .matrix_window (matrix_window),
        .hash_out      (hash_out)
    );

    // Clock: período de 10ns
    initial clock = 0;
    always #5 clock = ~clock;

    // Função para calcular o esperado em software
    function [P-1:0] calc_expected;
        input [W-1:0] k;
        input [(W+P-2):0] m_win;
        
        integer i, j;
        reg [W-1:0] current_slice;
        reg bit_result;
        reg [P-1:0] full_result;
        
        begin
            full_result = 0;
            for (i = 0; i < P; i = i + 1) begin
                current_slice = m_win[i +: W];
                bit_result = 1'b0;
                
                for (j = 0; j < W; j = j + 1) begin
                    bit_result = bit_result ^ (k[j] & current_slice[j]);
                end
                
                full_result[i] = bit_result;
            end
            calc_expected = full_result;
        end
    endfunction

    // Tarefa de verificação
    task apply_and_check;
        input [W-1:0] t_key;
        input [(W+P-2):0] t_matrix_window;
        input [P-1:0] t_expected;
        input [151:0] t_label;
        
        reg [P-1:0] actual_out;
        begin
            key = t_key;
            matrix_window = t_matrix_window;
            
            @(posedge clock); #1;
            actual_out = hash_out;
            
            if (actual_out === t_expected)
                $display("[PASS] %s | hash_out=%b (esperado=%b)",
                          t_label, actual_out, t_expected);
            else
                $display("[FAIL] %s | hash_out=%b (esperado=%b) | key=0x%08X mat=0x%016X",
                          t_label, actual_out, t_expected, t_key, t_matrix_window);
        end
    endtask

    integer idx;
    reg [W-1:0] rand_key;
    reg [(W+P-2):0] rand_mat;

    initial begin
        // -----------------------------------------------
        // Inicialização e Reset
        // -----------------------------------------------
        reset = 1;
        key = 0;
        matrix_window = 0;

        @(posedge clock); #1;

        if (hash_out === {P{1'b0}})
            $display("[PASS] Reset        | hash_out=0 apos reset");
        else
            $display("[FAIL] Reset        | hash_out=%b (esperado=0)", hash_out);
            
        reset = 0;

        // Casos Determinísticos (Escritos assumindo P=4 e W=32)
        $display("--- Casos deterministicos (P = %0d, W = %0d) ---", P, W);
        
        // Zeros absolutos -> Esperado: 4'b0000
        apply_and_check(32'h00000000, 63'h0000000000000000, 4'b0000, "Zeros           ");
        
        // Todos uns -> Esperado: 4'b0000
        // (32 bits em 1 resultam em XOR par = 0, para todas as fatias)
        apply_and_check(32'hFFFFFFFF, 63'h7FFFFFFFFFFFFFFF, 4'b0000, "Todos uns       ");
        
        // Apenas o Bit 0 ativo -> Esperado: 4'b0001
        // Engine 0 (fatia 31:0) vê os bits alinhados (XOR = 1).
        // Engines 1, 2 e 3 veem o '1' da matriz deslocado em relação à key, resultando em 0.
        apply_and_check(32'h00000001, 63'h0000000000000001, 4'b0001, "Apenas bit 0    ");

        // Padrão alternado (Key par, Matrix ímpar na primeira fatia) -> Esperado: 4'b0000
        // Engine 0: Não tem sobreposição de bits ativos (AND = 0, XOR = 0).
        // Engine 1: A matriz desliza 1 bit e fica 100% sobreposta. AND = 32'hAAAAAAAA. 
        // A quantidade de '1's em 32'hAAAAAAAA é 16. O XOR de 16 uns é par, logo = 0.
        apply_and_check(32'hAAAAAAAA, 63'h5555555555555555, 4'b0000, "Padrao alternado");

        // Validando o alinhamento da Janela Deslizante (LSB) -> Esperado: 4'b1010
        // Key possui apenas o bit 0 ativo. 
        // A matriz possui os bits 1 e 3 ativos (Valor 0xA).
        // Engine 0: bit 0 da matriz é 0 -> (AND = 0) -> 0
        // Engine 1: bit 1 da matriz é 1, ele "desliza" para a pos 0 da engine -> (AND = 1) -> 1
        // Engine 2: bit 2 da matriz é 0 -> (AND = 0) -> 0
        // Engine 3: bit 3 da matriz é 1, ele "desliza" para a pos 0 da engine -> (AND = 1) -> 1
        apply_and_check(32'h00000001, 63'h000000000000000A, 4'b1010, "Janela Deslizante");

        // Validando o Limite Superior dos Vetores (MSB) -> Esperado: 4'b1001
        // Key possui apenas o bit 31 (Mais Significativo) ativo.
        // A matriz possui o bit 31 e o bit 34 ativos. (63'h0000000480000000)
        // Engine 0: Lê [31:0]. O bit 31 da matriz é 1. Bate com a key -> 1
        // Engine 1: Lê [32:1]. O MSB da key bate no bit 32 da matriz, que é 0 -> 0
        // Engine 2: Lê [33:2]. O MSB da key bate no bit 33 da matriz, que é 0 -> 0
        // Engine 3: Lê [34:3]. O MSB da key bate no bit 34 da matriz, que é 1 -> 1
        apply_and_check(32'h80000000, 63'h0000000480000000, 4'b1001, "Limite Superior");

        // -----------------------------------------------
        // Casos Aleatórios
        // -----------------------------------------------
        $display("--- Casos aleatorios ---");
        for (idx = 0; idx < 10; idx = idx + 1) begin
            rand_key = $random;
            rand_mat = {$random, $random}; 
            apply_and_check(rand_key, rand_mat, calc_expected(rand_key, rand_mat), "Aleatorio       ");
        end

        // -----------------------------------------------
        // Verifica reset no meio da operação
        // -----------------------------------------------
        $display("--- Teste de Reset Assincrono / Sincrono ---");
        key = 32'hDEADBEEF;
        matrix_window = 64'hCAFEBABEDEADBEEF;
        
        @(posedge clock); #1;
        reset = 1;
        @(posedge clock); #1;
        
        if (hash_out === {P{1'b0}})
            $display("[PASS] Reset mid-op | hash_out=0 apos reset");
        else
            $display("[FAIL] Reset mid-op | hash_out=%b (esperado=0)", hash_out);
            
        reset = 0;

        #20;
        $display("--- Testbench concluido ---");
        $stop;
    end

endmodule