module top #(
    // Alterar parâmetros aqui para ver o impacto na síntese
    parameter P = 32,
    parameter W = 32
)(
    input  wire clk,
    input  wire reset,
    
    // Entradas do tamanho exato para nao sofrerem otimizacao
    input  wire [W-1:0] key,
    input  wire [(W+P-2):0] matrix_window,
    
    // A saida precisa ir para um pino externo para nao ser removida
    output wire [P-1:0] out
);

    // Instanciacao da Compression Unit
    compression_unit #(
        .P(P),
        .W(W)
    ) comp_inst (
        .clock         (clk),
        .reset         (reset),
        .key           (key),
        .matrix_window (matrix_window),
        .hash_out      (out)
    );

endmodule