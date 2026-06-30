// Mock Sincrono gerado dinamicamente pelo Python (1 ciclo de latencia)
// Este modulo simula a chegada dos dados de streaming da matriz de Toeplitz.
module matrix_lut (
    input wire clock,
    input wire [4:0] address,
    output reg [94:0] q
);
    always @(posedge clock) begin
        case(address)
            5'd0: q <= 95'h6E439FB84539E021FA2199F2;
            5'd1: q <= 95'h62BF22874E6BAF9F6E439FB8;
            5'd2: q <= 95'h52923DE4A97A9FDDE2BF2287;
            5'd3: q <= 95'h72C4B379BF9BCA13D2923DE4;
            5'd4: q <= 95'h5AEBC30E53EAC5EC72C4B379;
            5'd5: q <= 95'h4DCCB9250490109B5AEBC30E;
            5'd6: q <= 95'h65591DD285F7D8FC4DCCB925;
            5'd7: q <= 95'h2A6722767F03BC11E5591DD2;
            5'd8: q <= 95'h1D7AF82185D96AFAAA672276;
            5'd9: q <= 95'h066CE72EAFD853599D7AF821;
            5'd10: q <= 95'h4E6BAF9F6E439FB84539E021;
            5'd11: q <= 95'h297A9FDDE2BF22874E6BAF9F;
            5'd12: q <= 95'h3F9BCA13D2923DE4A97A9FDD;
            5'd13: q <= 95'h53EAC5EC72C4B379BF9BCA13;
            5'd14: q <= 95'h0490109B5AEBC30E53EAC5EC;
            5'd15: q <= 95'h05F7D8FC4DCCB9250490109B;
            5'd16: q <= 95'h7F03BC11E5591DD285F7D8FC;
            5'd17: q <= 95'h05D96AFAAA6722767F03BC11;
            5'd18: q <= 95'h2FD853599D7AF82185D96AFA;
            5'd19: q <= 95'h1FB3B429066CE72EAFD85359;
            5'd20: q <= 95'h000000000000000000000000;
            5'd21: q <= 95'h000000000000000000000000;
            5'd22: q <= 95'h000000000000000000000000;
            5'd23: q <= 95'h000000000000000000000000;
            5'd24: q <= 95'h000000000000000000000000;
            5'd25: q <= 95'h000000000000000000000000;
            5'd26: q <= 95'h000000000000000000000000;
            5'd27: q <= 95'h000000000000000000000000;
            5'd28: q <= 95'h000000000000000000000000;
            5'd29: q <= 95'h000000000000000000000000;
            5'd30: q <= 95'h000000000000000000000000;
            5'd31: q <= 95'h000000000000000000000000;
            default: q <= 95'h0;
        endcase
    end
endmodule
