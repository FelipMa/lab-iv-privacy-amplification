// Gerado automaticamente por gerar_lut.py
module matrix_lut (
    input wire clock,
    input wire [5:0] address,
    output reg [62:0] q
);
    always @(posedge clock) begin
        case(address)
            6'd0: q <= 63'h2A1F8D4E76B093C1;
            6'd1: q <= 63'h509E5C3B2A1F8D4E;
            6'd2: q <= 63'h3B84F716D09E5C3B;
            6'd3: q <= 63'h45D4E92A3B84F716;
            6'd4: q <= 63'h509E5C3B2A1F8D4E;
            6'd5: q <= 63'h3B84F716D09E5C3B;
            6'd6: q <= 63'h45D4E92A3B84F716;
            6'd7: q <= 63'h6A2F8B10C5D4E92A;
            default: q <= 63'h0;
        endcase
    end
endmodule
