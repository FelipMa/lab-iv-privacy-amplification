// Mock Sincrono gerado dinamicamente pelo Python (1 ciclo de latencia)
// Este modulo simula a chegada dos dados de streaming da matriz de Toeplitz.
module matrix_lut (
    input wire clock,
    input wire [5:0] address,
    output reg [94:0] q
);
    always @(posedge clock) begin
        case(address)
            6'd0: q <= 95'h4DCCB9250490109B5AEBC30E;
            6'd1: q <= 95'h65591DD285F7D8FC4DCCB925;
            6'd2: q <= 95'h2A6722767F03BC11E5591DD2;
            6'd3: q <= 95'h1D7AF82185D96AFAAA672276;
            6'd4: q <= 95'h066CE72EAFD853599D7AF821;
            6'd5: q <= 95'h52B5964D1FB3B429066CE72E;
            6'd6: q <= 95'h0D92BB256262A46C52B5964D;
            6'd7: q <= 95'h08CEEF9ABDFB67C28D92BB25;
            6'd8: q <= 95'h3E3A09B50DD879E708CEEF9A;
            6'd9: q <= 95'h2F5E3BD42156911D3E3A09B5;
            6'd10: q <= 95'h1E3B2F4F267CCE1AAF5E3BD4;
            6'd11: q <= 95'h67DE35C0A6DBF6709E3B2F4F;
            6'd12: q <= 95'h1641DC38033D5DFB67DE35C0;
            6'd13: q <= 95'h3D1B637B317334DE9641DC38;
            6'd14: q <= 95'h3C24FCD186DAA6063D1B637B;
            6'd15: q <= 95'h05F7D8FC4DCCB9250490109B;
            6'd16: q <= 95'h7F03BC11E5591DD285F7D8FC;
            6'd17: q <= 95'h05D96AFAAA6722767F03BC11;
            6'd18: q <= 95'h2FD853599D7AF82185D96AFA;
            6'd19: q <= 95'h1FB3B429066CE72EAFD85359;
            6'd20: q <= 95'h6262A46C52B5964D1FB3B429;
            6'd21: q <= 95'h3DFB67C28D92BB256262A46C;
            6'd22: q <= 95'h0DD879E708CEEF9ABDFB67C2;
            6'd23: q <= 95'h2156911D3E3A09B50DD879E7;
            6'd24: q <= 95'h267CCE1AAF5E3BD42156911D;
            6'd25: q <= 95'h26DBF6709E3B2F4F267CCE1A;
            6'd26: q <= 95'h033D5DFB67DE35C0A6DBF670;
            6'd27: q <= 95'h317334DE9641DC38033D5DFB;
            6'd28: q <= 95'h06DAA6063D1B637B317334DE;
            6'd29: q <= 95'h2D0C408B3C24FCD186DAA606;
            6'd30: q <= 95'h65591DD285F7D8FC4DCCB925;
            6'd31: q <= 95'h2A6722767F03BC11E5591DD2;
            6'd32: q <= 95'h1D7AF82185D96AFAAA672276;
            6'd33: q <= 95'h066CE72EAFD853599D7AF821;
            6'd34: q <= 95'h52B5964D1FB3B429066CE72E;
            6'd35: q <= 95'h0D92BB256262A46C52B5964D;
            6'd36: q <= 95'h08CEEF9ABDFB67C28D92BB25;
            6'd37: q <= 95'h3E3A09B50DD879E708CEEF9A;
            6'd38: q <= 95'h2F5E3BD42156911D3E3A09B5;
            6'd39: q <= 95'h1E3B2F4F267CCE1AAF5E3BD4;
            6'd40: q <= 95'h67DE35C0A6DBF6709E3B2F4F;
            6'd41: q <= 95'h1641DC38033D5DFB67DE35C0;
            6'd42: q <= 95'h3D1B637B317334DE9641DC38;
            6'd43: q <= 95'h3C24FCD186DAA6063D1B637B;
            6'd44: q <= 95'h2B52DF672D0C408B3C24FCD1;
            6'd45: q <= 95'h0;
            6'd46: q <= 95'h0;
            6'd47: q <= 95'h0;
            6'd48: q <= 95'h0;
            6'd49: q <= 95'h0;
            6'd50: q <= 95'h0;
            6'd51: q <= 95'h0;
            6'd52: q <= 95'h0;
            6'd53: q <= 95'h0;
            6'd54: q <= 95'h0;
            6'd55: q <= 95'h0;
            6'd56: q <= 95'h0;
            6'd57: q <= 95'h0;
            6'd58: q <= 95'h0;
            6'd59: q <= 95'h0;
            6'd60: q <= 95'h0;
            6'd61: q <= 95'h0;
            6'd62: q <= 95'h0;
            6'd63: q <= 95'h0;
            default: q <= 95'h0;
        endcase
    end
endmodule
