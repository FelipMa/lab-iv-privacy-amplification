// Compression unit que implementa multiplicacao por matriz Toeplitz sobre GF(2):
//
//   hash_out = (T @ key) mod 2
//
// onde T tem shape P x W e T[i,j] depende apenas de (i - j):
//   - T[i,j] = matrix_window[j - i]         para j >= i (diagonais superiores)
//   - T[i,j] = matrix_window[W + i - j - 1] para j <  i (diagonais inferiores)
//
// O matrix_window tem W+P-1 bits e define todas as diagonais da matriz, com
// a mesma convencao usada por high_level_simulation/compression_model.py.
//
// Cada engine i recebe sua linha-i pre-montada (W bits nao contiguos do
// matrix_window) em vez do part-select Hankel matrix_window[i +: W] da versao
// anterior.

module compression_unit #(
    parameter P = 128, // Paralelismo
    parameter W = 128  // Tamanho da chave
)(
    input wire clock,
    input wire reset,
    input wire [(W-1):0] key,
    input wire [(W+P-2) : 0] matrix_window,
    output wire [(P-1):0] hash_out
);

    genvar i, j;

    generate
        for (i = 0; i < P; i = i + 1) begin : gen_hash_engines
            wire [W-1:0] toeplitz_row;

            for (j = 0; j < W; j = j + 1) begin : gen_row_bits
                if (j >= i) begin : ge_case
                    assign toeplitz_row[j] = matrix_window[j - i];
                end else begin : lt_case
                    assign toeplitz_row[j] = matrix_window[W + i - j - 1];
                end
            end

            hash_engine #(
                .W(W)
            ) engine_inst (
                .clock   (clock),
                .reset   (reset),
                .key     (key),
                .matrix  (toeplitz_row),
                .hash_b  (hash_out[i])
            );
        end
    endgenerate

endmodule
