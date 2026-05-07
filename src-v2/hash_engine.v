module hash_engine #(
    parameter W = 128 // Tamanho da chave
)(
    input wire clock,
    input wire reset,
    input wire clear_acc, // Sinal para reiniciar o acumulador
    input wire [W-1:0] key,
    input wire [W-1:0] matrix,
    output reg hash_b
);

    // Registradores do Estágio 1 (Pipeline)
    reg [W-1:0] and_stage;
    reg clear_acc_pipe;

    always @(posedge clock) begin
        if (reset) begin
            and_stage <= {W{1'b0}};
            hash_b <= 1'b0;
            clear_acc_pipe <= 1'b0;
        end else begin
            // =========================================================
            // ESTÁGIO 1: Operação AND bit a bit e propagação de controle
            // =========================================================
            and_stage <= key & matrix;
            clear_acc_pipe <= clear_acc;
            
            // =========================================================
            // ESTÁGIO 2: Árvore XOR e Acumulação
            // =========================================================
            if (clear_acc_pipe) begin
                // Início de uma nova linha: armazena sem acumular com o passado
                hash_b <= ^and_stage;
            end else begin
                // Meio da linha: acumula (XOR) o resultado atual com o histórico
                hash_b <= hash_b ^ (^and_stage);
            end
        end
    end

endmodule