`timescale 1ns/1ps

module compression_unit_file_tb;

    // Parametros do hardware
    parameter P = 64;
    parameter W = 64;

    reg clock;
    reg reset;
    reg [W-1:0] key;
    reg [(W+P-2):0] matrix_window;
    wire [P-1:0] hash_out;

    // Instanciacao da Compression Unit
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

    // Geracao do clock de 10ns (50 MHz)
    initial clock = 0;
    always #5 clock = ~clock;

    // Arrays para ler os arquivos hex
    reg [W-1:0] keys_mem [0:99];
    reg [127:0] matrices_mem [0:99]; // 128 bits para acomodar os 127 bits do matrix_window
    
    integer out_file;
    integer i;

    initial begin
        // Inicializacao
        reset = 1;
        key = 0;
        matrix_window = 0;
        
        // Carrega os arquivos hex gerados pelo script Python
        $readmemh("keys.hex", keys_mem);
        $readmemh("matrices.hex", matrices_mem);
        
        // Abre o arquivo de saida para escrita
        out_file = $fopen("output_hashes.hex", "w");
        if (out_file == 0) begin
            $display("Erro ao criar o arquivo output_hashes.hex");
            $finish;
        end

        // Aguarda alguns ciclos em reset
        #20;
        @(posedge clock);
        reset = 0;
        
        // Loop para aplicar as entradas
        for (i = 0; i < 100; i = i + 1) begin
            // Aplica os sinais na subida do clock
            key = keys_mem[i];
            matrix_window = matrices_mem[i][W+P-2:0];
            
            @(posedge clock);
            
            // A partir da segunda iteracao (i > 0), o output da iteracao anterior esta pronto
            if (i > 0) begin
                $fwrite(out_file, "%h\n", hash_out);
            end
        end
        
        // Apos o loop, precisamos de mais um ciclo para ler a ultima saida (da iteracao 99)
        @(posedge clock);
        $fwrite(out_file, "%h\n", hash_out);
        
        // Fecha o arquivo de saida e encerra a simulacao
        $fclose(out_file);
        $display("Simulacao concluida! Resultados salvos em output_hashes.hex.");
        $stop;
    end

endmodule
