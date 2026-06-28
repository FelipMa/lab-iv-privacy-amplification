`timescale 1ns/1ps
module aes128_encrypt (
    input  wire         clock,
    input  wire         reset_n,
    input  wire         start,
    input  wire [127:0] key,
    input  wire [127:0] plaintext,
    output reg  [127:0] ciphertext,
    output reg          busy,
    output reg          done
);
    localparam LAST_ROUND = 4'd10;

    reg [127:0] state;
    reg [127:0] round_key;
    reg [3:0]   round;

    wire [127:0] next_round_key;
    wire [127:0] sub_shift_state;
    wire [127:0] middle_round_state;
    wire [127:0] final_round_state;

    assign next_round_key    = KeyExpansion(round_key, round); // Pra gerar a chave da rodada (a primeira é justamente a primeira chave do input, ao todo são 11)
    
    assign sub_shift_state   = ShiftRows(SubBytes(state));
    assign middle_round_state = MixColumns(sub_shift_state) ^ next_round_key; // XOR do state com a chave é justamente o AddRoundKey do documento
    
    assign final_round_state  = sub_shift_state ^ next_round_key; // no final não temos o MixColumns, então o AddRoundKey é feito usando o subshift

    always @(posedge clock) begin
        if (!reset_n) begin
            state      <= 128'd0;
            round_key  <= 128'd0;
            round      <= 4'd0;
            ciphertext <= 128'd0;
            busy       <= 1'b0;
            done       <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                state     <= plaintext ^ key;  // Initial AddRoundKey (XOR de round key com state atuais)
                round_key <= key;
                round     <= 4'd1;
                busy      <= 1'b1;
            end else if (busy) begin
                round_key <= next_round_key;

                if (round < LAST_ROUND) begin
                    state <= middle_round_state;
                    round <= round + 4'd1;
                end else begin
                    state      <= final_round_state;
                    ciphertext <= final_round_state;
                    busy       <= 1'b0;
                    done       <= 1'b1;
                    round      <= 4'd0;
                end
            end
        end
    end

    function [127:0] SubBytes;
        input [127:0] in;
        integer i;
        begin
            for (i = 0; i < 16; i = i + 1) begin
                SubBytes[127 - 8*i -: 8] = sbox(in[127 - 8*i -: 8]); //Nao temos tempo pra fazer sequencialmente. Fiz assim pra economizar ciclos
            end
        end
    endfunction

    function [127:0] ShiftRows;
        input [127:0] in;
        reg [7:0] b0;  reg [7:0] b1;  reg [7:0] b2;  reg [7:0] b3;
        reg [7:0] b4;  reg [7:0] b5;  reg [7:0] b6;  reg [7:0] b7;
        reg [7:0] b8;  reg [7:0] b9;  reg [7:0] b10; reg [7:0] b11;
        reg [7:0] b12; reg [7:0] b13; reg [7:0] b14; reg [7:0] b15;
        begin
            b0  = in[127:120]; b1  = in[119:112]; b2  = in[111:104]; b3  = in[103:96];
            b4  = in[95:88];   b5  = in[87:80];   b6  = in[79:72];   b7  = in[71:64];
            b8  = in[63:56];   b9  = in[55:48];   b10 = in[47:40];   b11 = in[39:32];
            b12 = in[31:24];   b13 = in[23:16];   b14 = in[15:8];    b15 = in[7:0];

            //[b0 b4 b8  b12]
            //[b1 b5 b9  b13]
            //[b2 b6 b10 b14]
            //[b3 b7 b11 b15]
            ShiftRows = { b0,  b5,  b10, b15,
                           b4,  b9,  b14, b3,
                           b8,  b13, b2,  b7,
                           b12, b1,  b6,  b11 };
        end
    endfunction

    function [127:0] MixColumns;
        input [127:0] in;
        reg [7:0] a00; reg [7:0] a10; reg [7:0] a20; reg [7:0] a30;
        reg [7:0] a01; reg [7:0] a11; reg [7:0] a21; reg [7:0] a31;
        reg [7:0] a02; reg [7:0] a12; reg [7:0] a22; reg [7:0] a32;
        reg [7:0] a03; reg [7:0] a13; reg [7:0] a23; reg [7:0] a33;

        reg [127:0] out;
        integer c;
        begin
        out = 128'd0;

        //word 0
        a00 = in[127:120];
        a10 = in[119:112];
        a20 = in[111:104];
        a30 = in[103:96];

        out[127:120] = mul2(a00) ^ mul3(a10) ^ a20       ^ a30;
        out[119:112] = a00       ^ mul2(a10) ^ mul3(a20) ^ a30;
        out[111:104] = a00       ^ a10       ^ mul2(a20) ^ mul3(a30);
        out[103:96]  = mul3(a00) ^ a10       ^ a20       ^ mul2(a30);


        //word 1
        a01 = in[95:88];
        a11 = in[87:80];
        a21 = in[79:72];
        a31 = in[71:64];

        out[95:88] = mul2(a01) ^ mul3(a11) ^ a21       ^ a31;
        out[87:80] = a01       ^ mul2(a11) ^ mul3(a21) ^ a31;
        out[79:72] = a01       ^ a11       ^ mul2(a21) ^ mul3(a31);
        out[71:64] = mul3(a01) ^ a11       ^ a21       ^ mul2(a31);


        //word 2
        a02 = in[63:56];
        a12 = in[55:48];
        a22 = in[47:40];
        a32 = in[39:32];

        out[63:56] = mul2(a02) ^ mul3(a12) ^ a22       ^ a32;
        out[55:48] = a02       ^ mul2(a12) ^ mul3(a22) ^ a32;
        out[47:40] = a02       ^ a12       ^ mul2(a22) ^ mul3(a32);
        out[39:32] = mul3(a02) ^ a12       ^ a22       ^ mul2(a32);


        //word 3
        a03 = in[31:24];
        a13 = in[23:16];
        a23 = in[15:8];
        a33 = in[7:0];

        out[31:24] = mul2(a03) ^ mul3(a13) ^ a23       ^ a33;
        out[23:16] = a03       ^ mul2(a13) ^ mul3(a23) ^ a33;
        out[15:8]  = a03       ^ a13       ^ mul2(a23) ^ mul3(a33);
        out[7:0]   = mul3(a03) ^ a13       ^ a23       ^ mul2(a33);

        MixColumns = out;
    end
    endfunction

    function [7:0] xtimes;
        input [7:0] x;
        begin
            xtimes = {x[6:0], 1'b0} ^ (8'h1b & {8{x[7]}});
        end
    endfunction

    function [7:0] mul2;
        input [7:0] x;
        begin
            mul2 = xtimes(x);
        end
    endfunction

    function [7:0] mul3;
        input [7:0] x;
        begin
            mul3 = xtimes(x) ^ x;
        end
    endfunction

    function [31:0] RotWord;
        input [31:0] w;
        begin
            RotWord = {w[23:0], w[31:24]}; // lembre-se>: a0 = [31:24] a1 = [23:16] assim... ROTWORD([a0,a1,a2,a3]) = [a1,a2,a3,a0],
        end
    endfunction

    function [31:0] SubWord;
        input [31:0] w;
        begin
            SubWord = {sbox(w[31:24]), sbox(w[23:16]), sbox(w[15:8]), sbox(w[7:0])}; // O Standard diz que os bytes começam de a0, a1...
        end
    endfunction

    function [31:0] rcon;
        input [3:0] r;
        begin
            case (r)
                4'd1:  rcon = 32'h01000000;
                4'd2:  rcon = 32'h02000000;
                4'd3:  rcon = 32'h04000000;
                4'd4:  rcon = 32'h08000000;
                4'd5:  rcon = 32'h10000000;
                4'd6:  rcon = 32'h20000000;
                4'd7:  rcon = 32'h40000000;
                4'd8:  rcon = 32'h80000000;
                4'd9:  rcon = 32'h1b000000;
                4'd10: rcon = 32'h36000000;
                default: rcon = 32'h00000000;
            endcase
        end
    endfunction

    function [127:0] KeyExpansion; //explicacao melhor no pdf do standard
        input [127:0] k;
        input [3:0] r;
        reg [31:0] w0; reg [31:0] w1; reg [31:0] w2; reg [31:0] w3;
        reg [31:0] t;
        reg [31:0] nw0; reg [31:0] nw1; reg [31:0] nw2; reg [31:0] nw3;
        begin
            w0 = k[127:96];
            w1 = k[95:64];
            w2 = k[63:32];
            w3 = k[31:0];
            nw0 = w0 ^ SubWord(RotWord(w3)) ^ rcon(r);
            nw1 = w1 ^ nw0;
            nw2 = w2 ^ nw1;
            nw3 = w3 ^ nw2;
            KeyExpansion = {nw0, nw1, nw2, nw3};
        end
    endfunction

    function [7:0] sbox;
        input [7:0] a;
        begin
            case (a)
                8'h00: sbox=8'h63; 
                8'h01: sbox=8'h7c; 
                8'h02: sbox=8'h77; 
                8'h03: sbox=8'h7b;
                8'h04: sbox=8'hf2; 
                8'h05: sbox=8'h6b; 
                8'h06: sbox=8'h6f; 
                8'h07: sbox=8'hc5;
                8'h08: sbox=8'h30; 
                8'h09: sbox=8'h01; 
                8'h0a: sbox=8'h67; 
                8'h0b: sbox=8'h2b;
                8'h0c: sbox=8'hfe; 
                8'h0d: sbox=8'hd7; 
                8'h0e: sbox=8'hab; 
                8'h0f: sbox=8'h76;
                8'h10: sbox=8'hca; 
                8'h11: sbox=8'h82; 
                8'h12: sbox=8'hc9; 
                8'h13: sbox=8'h7d;
                8'h14: sbox=8'hfa; 
                8'h15: sbox=8'h59; 
                8'h16: sbox=8'h47; 
                8'h17: sbox=8'hf0;
                8'h18: sbox=8'had; 
                8'h19: sbox=8'hd4; 
                8'h1a: sbox=8'ha2; 
                8'h1b: sbox=8'haf;
                8'h1c: sbox=8'h9c; 
                8'h1d: sbox=8'ha4; 
                8'h1e: sbox=8'h72; 
                8'h1f: sbox=8'hc0;
                8'h20: sbox=8'hb7; 
                8'h21: sbox=8'hfd; 
                8'h22: sbox=8'h93; 
                8'h23: sbox=8'h26;
                8'h24: sbox=8'h36; 
                8'h25: sbox=8'h3f; 
                8'h26: sbox=8'hf7; 
                8'h27: sbox=8'hcc;
                8'h28: sbox=8'h34; 
                8'h29: sbox=8'ha5; 
                8'h2a: sbox=8'he5; 
                8'h2b: sbox=8'hf1;
                8'h2c: sbox=8'h71; 
                8'h2d: sbox=8'hd8; 
                8'h2e: sbox=8'h31; 
                8'h2f: sbox=8'h15;
                8'h30: sbox=8'h04; 
                8'h31: sbox=8'hc7; 
                8'h32: sbox=8'h23; 
                8'h33: sbox=8'hc3;
                8'h34: sbox=8'h18; 
                8'h35: sbox=8'h96; 
                8'h36: sbox=8'h05; 
                8'h37: sbox=8'h9a;
                8'h38: sbox=8'h07; 
                8'h39: sbox=8'h12; 
                8'h3a: sbox=8'h80; 
                8'h3b: sbox=8'he2;
                8'h3c: sbox=8'heb; 
                8'h3d: sbox=8'h27; 
                8'h3e: sbox=8'hb2; 
                8'h3f: sbox=8'h75;
                8'h40: sbox=8'h09; 
                8'h41: sbox=8'h83; 
                8'h42: sbox=8'h2c; 
                8'h43: sbox=8'h1a;
                8'h44: sbox=8'h1b; 
                8'h45: sbox=8'h6e; 
                8'h46: sbox=8'h5a; 
                8'h47: sbox=8'ha0;
                8'h48: sbox=8'h52; 
                8'h49: sbox=8'h3b; 
                8'h4a: sbox=8'hd6; 
                8'h4b: sbox=8'hb3;
                8'h4c: sbox=8'h29; 
                8'h4d: sbox=8'he3; 
                8'h4e: sbox=8'h2f; 
                8'h4f: sbox=8'h84;
                8'h50: sbox=8'h53; 
                8'h51: sbox=8'hd1; 
                8'h52: sbox=8'h00; 
                8'h53: sbox=8'hed;
                8'h54: sbox=8'h20; 
                8'h55: sbox=8'hfc; 
                8'h56: sbox=8'hb1; 
                8'h57: sbox=8'h5b;
                8'h58: sbox=8'h6a; 
                8'h59: sbox=8'hcb; 
                8'h5a: sbox=8'hbe; 
                8'h5b: sbox=8'h39;
                8'h5c: sbox=8'h4a; 
                8'h5d: sbox=8'h4c; 
                8'h5e: sbox=8'h58; 
                8'h5f: sbox=8'hcf;
                8'h60: sbox=8'hd0; 
                8'h61: sbox=8'hef; 
                8'h62: sbox=8'haa; 
                8'h63: sbox=8'hfb;
                8'h64: sbox=8'h43; 
                8'h65: sbox=8'h4d; 
                8'h66: sbox=8'h33; 
                8'h67: sbox=8'h85;
                8'h68: sbox=8'h45; 
                8'h69: sbox=8'hf9; 
                8'h6a: sbox=8'h02; 
                8'h6b: sbox=8'h7f;
                8'h6c: sbox=8'h50; 
                8'h6d: sbox=8'h3c; 
                8'h6e: sbox=8'h9f; 
                8'h6f: sbox=8'ha8;
                8'h70: sbox=8'h51; 
                8'h71: sbox=8'ha3; 
                8'h72: sbox=8'h40; 
                8'h73: sbox=8'h8f;
                8'h74: sbox=8'h92; 
                8'h75: sbox=8'h9d; 
                8'h76: sbox=8'h38; 
                8'h77: sbox=8'hf5;
                8'h78: sbox=8'hbc; 
                8'h79: sbox=8'hb6; 
                8'h7a: sbox=8'hda; 
                8'h7b: sbox=8'h21;
                8'h7c: sbox=8'h10; 
                8'h7d: sbox=8'hff; 
                8'h7e: sbox=8'hf3; 
                8'h7f: sbox=8'hd2;
                8'h80: sbox=8'hcd; 
                8'h81: sbox=8'h0c; 
                8'h82: sbox=8'h13; 
                8'h83: sbox=8'hec;
                8'h84: sbox=8'h5f; 
                8'h85: sbox=8'h97; 
                8'h86: sbox=8'h44; 
                8'h87: sbox=8'h17;
                8'h88: sbox=8'hc4; 
                8'h89: sbox=8'ha7; 
                8'h8a: sbox=8'h7e; 
                8'h8b: sbox=8'h3d;
                8'h8c: sbox=8'h64; 
                8'h8d: sbox=8'h5d; 
                8'h8e: sbox=8'h19; 
                8'h8f: sbox=8'h73;
                8'h90: sbox=8'h60; 
                8'h91: sbox=8'h81; 
                8'h92: sbox=8'h4f; 
                8'h93: sbox=8'hdc;
                8'h94: sbox=8'h22; 
                8'h95: sbox=8'h2a; 
                8'h96: sbox=8'h90; 
                8'h97: sbox=8'h88;
                8'h98: sbox=8'h46; 
                8'h99: sbox=8'hee; 
                8'h9a: sbox=8'hb8; 
                8'h9b: sbox=8'h14;
                8'h9c: sbox=8'hde; 
                8'h9d: sbox=8'h5e; 
                8'h9e: sbox=8'h0b; 
                8'h9f: sbox=8'hdb;
                8'ha0: sbox=8'he0; 
                8'ha1: sbox=8'h32; 
                8'ha2: sbox=8'h3a; 
                8'ha3: sbox=8'h0a;
                8'ha4: sbox=8'h49; 
                8'ha5: sbox=8'h06; 
                8'ha6: sbox=8'h24; 
                8'ha7: sbox=8'h5c;
                8'ha8: sbox=8'hc2; 
                8'ha9: sbox=8'hd3; 
                8'haa: sbox=8'hac; 
                8'hab: sbox=8'h62;
                8'hac: sbox=8'h91; 
                8'had: sbox=8'h95; 
                8'hae: sbox=8'he4; 
                8'haf: sbox=8'h79;
                8'hb0: sbox=8'he7; 
                8'hb1: sbox=8'hc8; 
                8'hb2: sbox=8'h37; 
                8'hb3: sbox=8'h6d;
                8'hb4: sbox=8'h8d; 
                8'hb5: sbox=8'hd5; 
                8'hb6: sbox=8'h4e; 
                8'hb7: sbox=8'ha9;
                8'hb8: sbox=8'h6c; 
                8'hb9: sbox=8'h56; 
                8'hba: sbox=8'hf4; 
                8'hbb: sbox=8'hea;
                8'hbc: sbox=8'h65; 
                8'hbd: sbox=8'h7a; 
                8'hbe: sbox=8'hae; 
                8'hbf: sbox=8'h08;
                8'hc0: sbox=8'hba; 
                8'hc1: sbox=8'h78; 
                8'hc2: sbox=8'h25; 
                8'hc3: sbox=8'h2e;
                8'hc4: sbox=8'h1c; 
                8'hc5: sbox=8'ha6; 
                8'hc6: sbox=8'hb4; 
                8'hc7: sbox=8'hc6;
                8'hc8: sbox=8'he8; 
                8'hc9: sbox=8'hdd; 
                8'hca: sbox=8'h74; 
                8'hcb: sbox=8'h1f;
                8'hcc: sbox=8'h4b; 
                8'hcd: sbox=8'hbd; 
                8'hce: sbox=8'h8b; 
                8'hcf: sbox=8'h8a;
                8'hd0: sbox=8'h70; 
                8'hd1: sbox=8'h3e; 
                8'hd2: sbox=8'hb5; 
                8'hd3: sbox=8'h66;
                8'hd4: sbox=8'h48; 
                8'hd5: sbox=8'h03; 
                8'hd6: sbox=8'hf6; 
                8'hd7: sbox=8'h0e;
                8'hd8: sbox=8'h61; 
                8'hd9: sbox=8'h35; 
                8'hda: sbox=8'h57; 
                8'hdb: sbox=8'hb9;
                8'hdc: sbox=8'h86; 
                8'hdd: sbox=8'hc1; 
                8'hde: sbox=8'h1d; 
                8'hdf: sbox=8'h9e;
                8'he0: sbox=8'he1; 
                8'he1: sbox=8'hf8; 
                8'he2: sbox=8'h98; 
                8'he3: sbox=8'h11;
                8'he4: sbox=8'h69; 
                8'he5: sbox=8'hd9; 
                8'he6: sbox=8'h8e; 
                8'he7: sbox=8'h94;
                8'he8: sbox=8'h9b; 
                8'he9: sbox=8'h1e; 
                8'hea: sbox=8'h87; 
                8'heb: sbox=8'he9;
                8'hec: sbox=8'hce; 
                8'hed: sbox=8'h55; 
                8'hee: sbox=8'h28; 
                8'hef: sbox=8'hdf;
                8'hf0: sbox=8'h8c; 
                8'hf1: sbox=8'ha1; 
                8'hf2: sbox=8'h89; 
                8'hf3: sbox=8'h0d;
                8'hf4: sbox=8'hbf; 
                8'hf5: sbox=8'he6; 
                8'hf6: sbox=8'h42; 
                8'hf7: sbox=8'h68;
                8'hf8: sbox=8'h41; 
                8'hf9: sbox=8'h99; 
                8'hfa: sbox=8'h2d; 
                8'hfb: sbox=8'h0f;
                8'hfc: sbox=8'hb0; 
                8'hfd: sbox=8'h54; 
                8'hfe: sbox=8'hbb; 
                8'hff: sbox=8'h16;
            endcase
        end
    endfunction
endmodule
