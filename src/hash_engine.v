module hash_engine #(
    parameter W = 128 // Tamanho da chave
)(
    input wire clock,
    input wire reset,
    input wire [W-1:0] key,
    input wire [W-1:0] matrix,
    output reg hash_b
);

    // Parâmetros do pipeline para quebrar a grande árvore de XOR
    localparam NUM_CHUNKS = 8;
    localparam CHUNK_SIZE = W / NUM_CHUNKS; // Para W=128, cada chunk terá 16 bits

    // Registradores do Pipeline
    reg [W-1:0] key_reg;
    reg [W-1:0] matrix_reg;
    reg [NUM_CHUNKS-1:0] stage1_partial;

    integer i;

    // (reset sincrono)
    always @(posedge clock) begin
        if (reset) begin
            key_reg <= {W{1'b0}};
            matrix_reg <= {W{1'b0}};
            stage1_partial <= {NUM_CHUNKS{1'b0}};
            hash_b <= 1'b0;
        end else begin
            // ==============================================================
            // Pipeline Estágio 1: Registradores de Entrada
            // Isola o atraso de roteamento causado pelo altíssimo fanout do top
            // ==============================================================
            key_reg <= key;
            matrix_reg <= matrix;

            // ==============================================================
            // Pipeline Estágio 2: Operação AND + Redução Parcial (XOR)
            // Divide o W=128 em 8 blocos de 16 bits e faz o XOR isoladamente
            // ==============================================================
            for (i = 0; i < NUM_CHUNKS; i = i + 1) begin
                stage1_partial[i] <= ^( key_reg[i*CHUNK_SIZE +: CHUNK_SIZE] & matrix_reg[i*CHUNK_SIZE +: CHUNK_SIZE] );
            end

            // ==============================================================
            // Pipeline Estágio 3: Redução Final (XOR)
            // ==============================================================
            hash_b <= ^stage1_partial;
        end
    end

endmodule