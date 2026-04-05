module compression_unit #(
    parameter PARALLELISM = 1 // Paralelismo maximo será 32, iremos assumir o tamanho maximo para declarar entradas e saidas
)(
    input wire clock,
    input wire reset,
    input wire [31:0] key,
    input wire [62:0] matrix_window, // [(31 + PARALLELISM - 1) : 0]
    output wire [31:0] hash_out // [PARALLELISM - 1 : 0]
);

    genvar i;

    generate
        for (i = 0; i < PARALLELISM; i = i + 1) begin : gen_hash_engines
            hash_engine engine_inst (
                .clock   (clock),
                .reset   (reset),
                .key     (key),
                // Cada engine pega uma "fatia" de 32 bits.
                // A engine 0 pega os bits [31:0]
                // A engine 1 pega os bits [32:1] e assim por diante.
                .matrix  (matrix_window[i +: 32]), 
                .hash_b  (hash_out[i])
            );
        end
    endgenerate

endmodule