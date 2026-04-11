module top #(
    parameter P = 1042,
    parameter W = 64
)(
    input  wire clk,
    input  wire reset,
    
    // Um pino de saída real
    output wire dummy_out 
);

    // Registradores internos simulando a chegada de dados
    reg [W-1:0] key;
    reg [(W+P-2):0] matrix_window;
    
    wire [P-1:0] hash_out;

    compression_unit #(
        .P(P),
        .W(W)
    ) comp_inst (
        .clock         (clk),
        .reset         (reset),
        .key           (key),
        .matrix_window (matrix_window),
        .hash_out      (hash_out)
    );

    // Lógica para variar as entradas a cada clock
    always @(posedge clk) begin
        if (reset) begin
            key <= {W{1'b1}}; 
            matrix_window <= 0;
        end else begin
            // Varia a chave e a matriz continuamente
            key <= ~key;
            matrix_window <= matrix_window + 1'b1;
        end
    end

    // Reduz todos os bits do hash em 1 único bit.
    // Isso OBRIGA o sintetizador a calcular toda a matriz de P e W
    // para conseguir saber qual será o valor lógico deste único pino.
    assign dummy_out = ^hash_out;

endmodule