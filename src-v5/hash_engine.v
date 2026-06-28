module hash_engine #(
    parameter W = 32
)(
    input wire clock,
    input wire reset,
    input wire enable,
    input wire clear_acc,
    input wire [W-1:0] key,
    input wire [W-1:0] matrix,
    output reg hash_b
);

    // Registradores do Estágio 1 (Pipeline Otimizado)
    // Em vez de gastar W registradores, salvamos apenas o 1 bit já reduzido.
    reg reduced_bit;
    reg clear_acc_pipe;
    reg enable_pipe;

    always @(posedge clock) begin
        if (reset) begin
            reduced_bit    <= 1'b0;
            hash_b         <= 1'b0;
            clear_acc_pipe <= 1'b0;
            enable_pipe    <= 1'b0;
        end else begin
            // =========================================================
            // ESTÁGIO 1: AND Bit a bit + Árvore XOR de Redução
            // =========================================================
            reduced_bit    <= ^(key & matrix);
            
            // Sincroniza os controles para atuarem no ciclo seguinte
            clear_acc_pipe <= clear_acc;
            enable_pipe    <= enable;
            
            // =========================================================
            // ESTÁGIO 2: Acumulação
            // =========================================================
            if (enable_pipe) begin
                if (clear_acc_pipe) begin
                    // Primeira palavra do lote: substitui o lixo anterior
                    hash_b <= reduced_bit;
                end else begin
                    // Meio do lote: acumula via XOR
                    hash_b <= hash_b ^ reduced_bit;
                end
            end
            // Se enable_pipe == 0, hash_b mantém o valor inalterado (Freeze)
        end
    end

endmodule