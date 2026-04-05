module hash_engine (
    input wire clock,
    input wire reset,
    input wire [31:0] key,
    input wire [31:0] matrix,
    output reg hash_b
);

    // (reset síncrono)
    always @(posedge clock) begin
        if (reset) begin
            hash_b <= 1'b0;
        end else begin
            // Faz o AND bit a bit (multiplicação) e a redução XOR (somatório mod 2)
            hash_b <= ^(key & matrix);
        end
    end

endmodule