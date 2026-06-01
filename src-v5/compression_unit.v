module compression_unit #(
    parameter P = 32, 
    parameter W = 32 
)(
    input wire clock,
    input wire reset,
    input wire enable,
    input wire clear_acc,
    input wire [(W-1):0] key,
    input wire [(W+P-2) : 0] matrix_window,
    output wire [(P-1):0] hash_out
);
    genvar i;

    generate
        for (i = 0; i < P; i = i + 1) begin : gen_hash_engines
            hash_engine #(
                .W(W)
            ) engine_inst (
                .clock     (clock),
                .reset     (reset),
                .enable    (enable),
                .clear_acc (clear_acc),
                .key       (key),
                .matrix    (matrix_window[i +: W]), 
                .hash_b    (hash_out[i])
            );
        end
    endgenerate

endmodule