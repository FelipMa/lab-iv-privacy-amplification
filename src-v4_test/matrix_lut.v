// Mock Sincrono gerado dinamicamente pelo Python (1 ciclo de latencia)
// Este modulo simula a chegada dos dados de streaming da matriz de Toeplitz.
module matrix_lut (
    input wire clock,
    input wire [5:0] address,
    output reg [92:0] q
);
    always @(posedge clock) begin
        case(address)
            6'd0: q <= 93'h1285F7D8FC4DCCB925049010;
            6'd1: q <= 93'h167F03BC11E5591DD285F7D8;
            6'd2: q <= 93'h0185D96AFAAA6722767F03BC;
            6'd3: q <= 93'h0EAFD853599D7AF82185D96A;
            6'd4: q <= 93'h0D1FB3B429066CE72EAFD853;
            6'd5: q <= 93'h056262A46C52B5964D1FB3B4;
            6'd6: q <= 93'h1ABDFB67C28D92BB256262A4;
            6'd7: q <= 93'h150DD879E708CEEF9ABDFB67;
            6'd8: q <= 93'h142156911D3E3A09B50DD879;
            6'd9: q <= 93'h0F267CCE1AAF5E3BD4215691;
            6'd10: q <= 93'h00A6DBF6709E3B2F4F267CCE;
            6'd11: q <= 93'h18033D5DFB67DE35C0A6DBF6;
            6'd12: q <= 93'h1B317334DE9641DC38033D5D;
            6'd13: q <= 93'h1186DAA6063D1B637B317334;
            6'd14: q <= 93'h072D0C408B3C24FCD186DAA6;
            6'd15: q <= 93'h17FE90D0C6AB52DF672D0C40;
            6'd16: q <= 93'h079564774A17DF63F13732E4;
            6'd17: q <= 93'h0AA99C89D9FC0EF047956477;
            6'd18: q <= 93'h0675EBE0861765ABEAA99C89;
            6'd19: q <= 93'h0419B39CBABF614D6675EBE0;
            6'd20: q <= 93'h114AD659347ECED0A419B39C;
            6'd21: q <= 93'h0A364AEC95898A91B14AD659;
            6'd22: q <= 93'h1C233BBE6AF7ED9F0A364AEC;
            6'd23: q <= 93'h14F8E826D43761E79C233BBE;
            6'd24: q <= 93'h0ABD78EF50855A4474F8E826;
            6'd25: q <= 93'h0278ECBD3C99F3386ABD78EF;
            6'd26: q <= 93'h0D9F78D7029B6FD9C278ECBD;
            6'd27: q <= 93'h1A590770E00CF577ED9F78D7;
            6'd28: q <= 93'h18F46D8DECC5CCD37A590770;
            6'd29: q <= 93'h0CF093F3461B6A9818F46D8D;
            6'd30: q <= 93'h1AAD4B7D9CB431022CF093F3;
            6'd31: q <= 93'h097EA70EDFFA43431AAD4B7D;
            6'd32: q <= 93'h07F03BC11E5591DD285F7D8F;
            6'd33: q <= 93'h185D96AFAAA6722767F03BC1;
            6'd34: q <= 93'h0AFD853599D7AF82185D96AF;
            6'd35: q <= 93'h11FB3B429066CE72EAFD8535;
            6'd36: q <= 93'h16262A46C52B5964D1FB3B42;
            6'd37: q <= 93'h0BDFB67C28D92BB256262A46;
            6'd38: q <= 93'h10DD879E708CEEF9ABDFB67C;
            6'd39: q <= 93'h02156911D3E3A09B50DD879E;
            6'd40: q <= 93'h1267CCE1AAF5E3BD42156911;
            6'd41: q <= 93'h0A6DBF6709E3B2F4F267CCE1;
            6'd42: q <= 93'h0033D5DFB67DE35C0A6DBF67;
            6'd43: q <= 93'h1317334DE9641DC38033D5DF;
            6'd44: q <= 93'h186DAA6063D1B637B317334D;
            6'd45: q <= 93'h12D0C408B3C24FCD186DAA60;
            6'd46: q <= 93'h1FE90D0C6AB52DF672D0C408;
            6'd47: q <= 93'h581025FA9C3B7FE90D0C;
            6'd48: q <= 93'h0A99C89D9FC0EF0479564774;
            6'd49: q <= 93'h075EBE0861765ABEAA99C89D;
            6'd50: q <= 93'h019B39CBABF614D6675EBE08;
            6'd51: q <= 93'h14AD659347ECED0A419B39CB;
            6'd52: q <= 93'h0364AEC95898A91B14AD6593;
            6'd53: q <= 93'h0233BBE6AF7ED9F0A364AEC9;
            6'd54: q <= 93'h0F8E826D43761E79C233BBE6;
            6'd55: q <= 93'h0BD78EF50855A4474F8E826D;
            6'd56: q <= 93'h078ECBD3C99F3386ABD78EF5;
            6'd57: q <= 93'h19F78D7029B6FD9C278ECBD3;
            6'd58: q <= 93'h0590770E00CF577ED9F78D70;
            6'd59: q <= 93'h0F46D8DECC5CCD37A590770E;
            6'd60: q <= 93'h0F093F3461B6A9818F46D8DE;
            6'd61: q <= 93'h0AD4B7D9CB431022CF093F34;
            6'd62: q <= 93'h17EA70EDFFA43431AAD4B7D9;
            6'd63: q <= 93'h1604097EA70ED;
            default: q <= 93'h0;
        endcase
    end
endmodule
