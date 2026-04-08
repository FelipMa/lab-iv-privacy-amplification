module compression_unit #(
    parameter P = 4, // Paralelismo
    parameter W = 32 // Tamanho da chave
)(
    input wire clock,
    input wire reset,
    input wire [W - 1 : 0] key,
    // O tamanho reflete: W bits básicos + (P - 1) bits extras para deslizar
    input wire [(W + P - 2) : 0] matrix_window,
    output wire [P - 1 : 0] hash_out
);

    genvar i;

    generate
        for (i = 0; i < P; i = i + 1) begin : gen_hash_engines
            // Instancia a hash engine propagando os parâmetros
            hash_engine #(
                .W(W)
            ) engine_inst (
                .clock   (clock),
                .reset   (reset),
                .key     (key),
                // Cada engine pega uma fatia de 'W' bits.
                .matrix  (matrix_window[i +: W]), 
                .hash_b  (hash_out[i])
            );
        end
    endgenerate

endmodule