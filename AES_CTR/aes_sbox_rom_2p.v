`timescale 1ns/1ps

module aes_sbox_rom_2p ( // 2p pois e dual-port 
    input  wire       clock,

    input  wire [7:0] addr_a,
    input  wire [7:0] addr_b,

    output reg  [7:0] data_a,
    output reg  [7:0] data_b
);

    // Quartus: tentar inferir esta ROM em bloco M9K.
    // Cada instância fornece 2 leituras de S-box por ciclo.
    (* ramstyle = "M9K" *) reg [7:0] rom [0:255];

    initial begin
        rom[8'h00] = 8'h63; rom[8'h01] = 8'h7c; rom[8'h02] = 8'h77; rom[8'h03] = 8'h7b;
        rom[8'h04] = 8'hf2; rom[8'h05] = 8'h6b; rom[8'h06] = 8'h6f; rom[8'h07] = 8'hc5;
        rom[8'h08] = 8'h30; rom[8'h09] = 8'h01; rom[8'h0a] = 8'h67; rom[8'h0b] = 8'h2b;
        rom[8'h0c] = 8'hfe; rom[8'h0d] = 8'hd7; rom[8'h0e] = 8'hab; rom[8'h0f] = 8'h76;

        rom[8'h10] = 8'hca; rom[8'h11] = 8'h82; rom[8'h12] = 8'hc9; rom[8'h13] = 8'h7d;
        rom[8'h14] = 8'hfa; rom[8'h15] = 8'h59; rom[8'h16] = 8'h47; rom[8'h17] = 8'hf0;
        rom[8'h18] = 8'had; rom[8'h19] = 8'hd4; rom[8'h1a] = 8'ha2; rom[8'h1b] = 8'haf;
        rom[8'h1c] = 8'h9c; rom[8'h1d] = 8'ha4; rom[8'h1e] = 8'h72; rom[8'h1f] = 8'hc0;

        rom[8'h20] = 8'hb7; rom[8'h21] = 8'hfd; rom[8'h22] = 8'h93; rom[8'h23] = 8'h26;
        rom[8'h24] = 8'h36; rom[8'h25] = 8'h3f; rom[8'h26] = 8'hf7; rom[8'h27] = 8'hcc;
        rom[8'h28] = 8'h34; rom[8'h29] = 8'ha5; rom[8'h2a] = 8'he5; rom[8'h2b] = 8'hf1;
        rom[8'h2c] = 8'h71; rom[8'h2d] = 8'hd8; rom[8'h2e] = 8'h31; rom[8'h2f] = 8'h15;

        rom[8'h30] = 8'h04; rom[8'h31] = 8'hc7; rom[8'h32] = 8'h23; rom[8'h33] = 8'hc3;
        rom[8'h34] = 8'h18; rom[8'h35] = 8'h96; rom[8'h36] = 8'h05; rom[8'h37] = 8'h9a;
        rom[8'h38] = 8'h07; rom[8'h39] = 8'h12; rom[8'h3a] = 8'h80; rom[8'h3b] = 8'he2;
        rom[8'h3c] = 8'heb; rom[8'h3d] = 8'h27; rom[8'h3e] = 8'hb2; rom[8'h3f] = 8'h75;

        rom[8'h40] = 8'h09; rom[8'h41] = 8'h83; rom[8'h42] = 8'h2c; rom[8'h43] = 8'h1a;
        rom[8'h44] = 8'h1b; rom[8'h45] = 8'h6e; rom[8'h46] = 8'h5a; rom[8'h47] = 8'ha0;
        rom[8'h48] = 8'h52; rom[8'h49] = 8'h3b; rom[8'h4a] = 8'hd6; rom[8'h4b] = 8'hb3;
        rom[8'h4c] = 8'h29; rom[8'h4d] = 8'he3; rom[8'h4e] = 8'h2f; rom[8'h4f] = 8'h84;

        rom[8'h50] = 8'h53; rom[8'h51] = 8'hd1; rom[8'h52] = 8'h00; rom[8'h53] = 8'hed;
        rom[8'h54] = 8'h20; rom[8'h55] = 8'hfc; rom[8'h56] = 8'hb1; rom[8'h57] = 8'h5b;
        rom[8'h58] = 8'h6a; rom[8'h59] = 8'hcb; rom[8'h5a] = 8'hbe; rom[8'h5b] = 8'h39;
        rom[8'h5c] = 8'h4a; rom[8'h5d] = 8'h4c; rom[8'h5e] = 8'h58; rom[8'h5f] = 8'hcf;

        rom[8'h60] = 8'hd0; rom[8'h61] = 8'hef; rom[8'h62] = 8'haa; rom[8'h63] = 8'hfb;
        rom[8'h64] = 8'h43; rom[8'h65] = 8'h4d; rom[8'h66] = 8'h33; rom[8'h67] = 8'h85;
        rom[8'h68] = 8'h45; rom[8'h69] = 8'hf9; rom[8'h6a] = 8'h02; rom[8'h6b] = 8'h7f;
        rom[8'h6c] = 8'h50; rom[8'h6d] = 8'h3c; rom[8'h6e] = 8'h9f; rom[8'h6f] = 8'ha8;

        rom[8'h70] = 8'h51; rom[8'h71] = 8'ha3; rom[8'h72] = 8'h40; rom[8'h73] = 8'h8f;
        rom[8'h74] = 8'h92; rom[8'h75] = 8'h9d; rom[8'h76] = 8'h38; rom[8'h77] = 8'hf5;
        rom[8'h78] = 8'hbc; rom[8'h79] = 8'hb6; rom[8'h7a] = 8'hda; rom[8'h7b] = 8'h21;
        rom[8'h7c] = 8'h10; rom[8'h7d] = 8'hff; rom[8'h7e] = 8'hf3; rom[8'h7f] = 8'hd2;

        rom[8'h80] = 8'hcd; rom[8'h81] = 8'h0c; rom[8'h82] = 8'h13; rom[8'h83] = 8'hec;
        rom[8'h84] = 8'h5f; rom[8'h85] = 8'h97; rom[8'h86] = 8'h44; rom[8'h87] = 8'h17;
        rom[8'h88] = 8'hc4; rom[8'h89] = 8'ha7; rom[8'h8a] = 8'h7e; rom[8'h8b] = 8'h3d;
        rom[8'h8c] = 8'h64; rom[8'h8d] = 8'h5d; rom[8'h8e] = 8'h19; rom[8'h8f] = 8'h73;

        rom[8'h90] = 8'h60; rom[8'h91] = 8'h81; rom[8'h92] = 8'h4f; rom[8'h93] = 8'hdc;
        rom[8'h94] = 8'h22; rom[8'h95] = 8'h2a; rom[8'h96] = 8'h90; rom[8'h97] = 8'h88;
        rom[8'h98] = 8'h46; rom[8'h99] = 8'hee; rom[8'h9a] = 8'hb8; rom[8'h9b] = 8'h14;
        rom[8'h9c] = 8'hde; rom[8'h9d] = 8'h5e; rom[8'h9e] = 8'h0b; rom[8'h9f] = 8'hdb;

        rom[8'ha0] = 8'he0; rom[8'ha1] = 8'h32; rom[8'ha2] = 8'h3a; rom[8'ha3] = 8'h0a;
        rom[8'ha4] = 8'h49; rom[8'ha5] = 8'h06; rom[8'ha6] = 8'h24; rom[8'ha7] = 8'h5c;
        rom[8'ha8] = 8'hc2; rom[8'ha9] = 8'hd3; rom[8'haa] = 8'hac; rom[8'hab] = 8'h62;
        rom[8'hac] = 8'h91; rom[8'had] = 8'h95; rom[8'hae] = 8'he4; rom[8'haf] = 8'h79;

        rom[8'hb0] = 8'he7; rom[8'hb1] = 8'hc8; rom[8'hb2] = 8'h37; rom[8'hb3] = 8'h6d;
        rom[8'hb4] = 8'h8d; rom[8'hb5] = 8'hd5; rom[8'hb6] = 8'h4e; rom[8'hb7] = 8'ha9;
        rom[8'hb8] = 8'h6c; rom[8'hb9] = 8'h56; rom[8'hba] = 8'hf4; rom[8'hbb] = 8'hea;
        rom[8'hbc] = 8'h65; rom[8'hbd] = 8'h7a; rom[8'hbe] = 8'hae; rom[8'hbf] = 8'h08;

        rom[8'hc0] = 8'hba; rom[8'hc1] = 8'h78; rom[8'hc2] = 8'h25; rom[8'hc3] = 8'h2e;
        rom[8'hc4] = 8'h1c; rom[8'hc5] = 8'ha6; rom[8'hc6] = 8'hb4; rom[8'hc7] = 8'hc6;
        rom[8'hc8] = 8'he8; rom[8'hc9] = 8'hdd; rom[8'hca] = 8'h74; rom[8'hcb] = 8'h1f;
        rom[8'hcc] = 8'h4b; rom[8'hcd] = 8'hbd; rom[8'hce] = 8'h8b; rom[8'hcf] = 8'h8a;

        rom[8'hd0] = 8'h70; rom[8'hd1] = 8'h3e; rom[8'hd2] = 8'hb5; rom[8'hd3] = 8'h66;
        rom[8'hd4] = 8'h48; rom[8'hd5] = 8'h03; rom[8'hd6] = 8'hf6; rom[8'hd7] = 8'h0e;
        rom[8'hd8] = 8'h61; rom[8'hd9] = 8'h35; rom[8'hda] = 8'h57; rom[8'hdb] = 8'hb9;
        rom[8'hdc] = 8'h86; rom[8'hdd] = 8'hc1; rom[8'hde] = 8'h1d; rom[8'hdf] = 8'h9e;

        rom[8'he0] = 8'he1; rom[8'he1] = 8'hf8; rom[8'he2] = 8'h98; rom[8'he3] = 8'h11;
        rom[8'he4] = 8'h69; rom[8'he5] = 8'hd9; rom[8'he6] = 8'h8e; rom[8'he7] = 8'h94;
        rom[8'he8] = 8'h9b; rom[8'he9] = 8'h1e; rom[8'hea] = 8'h87; rom[8'heb] = 8'he9;
        rom[8'hec] = 8'hce; rom[8'hed] = 8'h55; rom[8'hee] = 8'h28; rom[8'hef] = 8'hdf;

        rom[8'hf0] = 8'h8c; rom[8'hf1] = 8'ha1; rom[8'hf2] = 8'h89; rom[8'hf3] = 8'h0d;
        rom[8'hf4] = 8'hbf; rom[8'hf5] = 8'he6; rom[8'hf6] = 8'h42; rom[8'hf7] = 8'h68;
        rom[8'hf8] = 8'h41; rom[8'hf9] = 8'h99; rom[8'hfa] = 8'h2d; rom[8'hfb] = 8'h0f;
        rom[8'hfc] = 8'hb0; rom[8'hfd] = 8'h54; rom[8'hfe] = 8'hbb; rom[8'hff] = 8'h16;
    end

    always @(posedge clock) begin
        data_a <= rom[addr_a];
        data_b <= rom[addr_b];
    end

endmodule