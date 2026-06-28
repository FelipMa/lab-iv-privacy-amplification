`timescale 1ns/1ps

module AES (
    input  wire         clock,
    input  wire         reset_n,

    // Protocolo de entrada:
    // quando input_ready=1 e input_valid=1 na borda de clock,
    // input_block é capturado.
    input  wire         input_valid, // flag do controlador externo para indicar que novo input foi submetido
    input  wire [127:0] input_block,
    output wire         input_ready, // o proximo input pode ser inserido

    input  wire [127:0] key,

    // Saída:
    // output_valid fica 1 por um ciclo quando output_block é válido.
    output reg  [127:0] output_block,
    output reg          output_valid,
    output reg          busy
);

    localparam LAST_ROUND = 4'd10;

    localparam ST_IDLE         = 2'd0;
    localparam ST_SBOX_READ    = 2'd1;
    localparam ST_ROUND_COMMIT = 2'd2;

    reg [1:0] fsm;

    reg [127:0] state;
    reg [127:0] round_key;
    reg [3:0]   round;

    wire [7:0] sb0;
    wire [7:0] sb1;
    wire [7:0] sb2;
    wire [7:0] sb3;
    wire [7:0] sb4;
    wire [7:0] sb5;
    wire [7:0] sb6;
    wire [7:0] sb7;
    wire [7:0] sb8;
    wire [7:0] sb9;
    wire [7:0] sb10;
    wire [7:0] sb11;
    wire [7:0] sb12;
    wire [7:0] sb13;
    wire [7:0] sb14;
    wire [7:0] sb15;

    wire [7:0] ksb0;
    wire [7:0] ksb1;
    wire [7:0] ksb2;
    wire [7:0] ksb3;

    wire [127:0] sub_state;
    wire [31:0]  subword_rotword;

    wire [127:0] shifted_state;
    wire [127:0] next_round_key;
    wire [127:0] middle_round_state;
    wire [127:0] final_round_state;

    // O AES pode consumir um novo bloco quando:
    // 1) está parado; ou
    // 2) está finalizando a rodada 10 do bloco atual.
    assign input_ready = (fsm == ST_IDLE) ||
                         ((fsm == ST_ROUND_COMMIT) && (round == LAST_ROUND));

    assign sub_state = {
        sb0,  sb1,  sb2,  sb3,
        sb4,  sb5,  sb6,  sb7,
        sb8,  sb9,  sb10, sb11,
        sb12, sb13, sb14, sb15
    };

    // w3 = round_key[31:0]
    // RotWord(w3) = {w3[23:0], w3[31:24]}
    // SubWord(RotWord(w3)) =
    // {sbox(w3[23:16]), sbox(w3[15:8]), sbox(w3[7:0]), sbox(w3[31:24])}
    assign subword_rotword = {ksb0, ksb1, ksb2, ksb3};

    assign shifted_state      = ShiftRows(sub_state);
    assign next_round_key     = KeyExpansionNoSbox(round_key, round, subword_rotword);
    assign middle_round_state = MixColumns(shifted_state) ^ next_round_key;
    assign final_round_state  = shifted_state ^ next_round_key;

    // ============================================================
    // 10 ROMs S-box dual-port em M9K
    // 8 ROMs para os 16 bytes do state
    // 2 ROMs para os 4 bytes do SubWord da expansão de chave
    // ============================================================

    aes_sbox_rom_2p sbox0 (
        .clock  (clock),
        .addr_a (state[127:120]),
        .addr_b (state[119:112]),
        .data_a (sb0),
        .data_b (sb1)
    );

    aes_sbox_rom_2p sbox1 (
        .clock  (clock),
        .addr_a (state[111:104]),
        .addr_b (state[103:96]),
        .data_a (sb2),
        .data_b (sb3)
    );

    aes_sbox_rom_2p sbox2 (
        .clock  (clock),
        .addr_a (state[95:88]),
        .addr_b (state[87:80]),
        .data_a (sb4),
        .data_b (sb5)
    );

    aes_sbox_rom_2p sbox3 (
        .clock  (clock),
        .addr_a (state[79:72]),
        .addr_b (state[71:64]),
        .data_a (sb6),
        .data_b (sb7)
    );

    aes_sbox_rom_2p sbox4 (
        .clock  (clock),
        .addr_a (state[63:56]),
        .addr_b (state[55:48]),
        .data_a (sb8),
        .data_b (sb9)
    );

    aes_sbox_rom_2p sbox5 (
        .clock  (clock),
        .addr_a (state[47:40]),
        .addr_b (state[39:32]),
        .data_a (sb10),
        .data_b (sb11)
    );

    aes_sbox_rom_2p sbox6 (
        .clock  (clock),
        .addr_a (state[31:24]),
        .addr_b (state[23:16]),
        .data_a (sb12),
        .data_b (sb13)
    );

    aes_sbox_rom_2p sbox7 (
        .clock  (clock),
        .addr_a (state[15:8]),
        .addr_b (state[7:0]),
        .data_a (sb14),
        .data_b (sb15)
    );

    aes_sbox_rom_2p sbox8_key (
        .clock  (clock),
        .addr_a (round_key[23:16]),
        .addr_b (round_key[15:8]),
        .data_a (ksb0),
        .data_b (ksb1)
    );

    aes_sbox_rom_2p sbox9_key (
        .clock  (clock),
        .addr_a (round_key[7:0]),
        .addr_b (round_key[31:24]),
        .data_a (ksb2),
        .data_b (ksb3)
    );

    // ============================================================
    // FSM principal
    // ============================================================

    always @(posedge clock) begin
        if (!reset_n) begin
            fsm          <= ST_IDLE;

            state        <= 128'd0;
            round_key    <= 128'd0;
            round        <= 4'd0;

            output_block <= 128'd0;
            output_valid <= 1'b0;
            busy         <= 1'b0;
        end else begin
            output_valid <= 1'b0;

            case (fsm)

                ST_IDLE: begin
                    busy <= 1'b0;

                    if (input_valid) begin
                        // Captura o bloco de entrada e faz o AddRoundKey inicial.
                        // Em CTR, input_block deve ser nonce || counter.
                        state     <= input_block ^ key;
                        round_key <= key;
                        round     <= 4'd1;

                        busy      <= 1'b1;
                        fsm       <= ST_SBOX_READ;
                    end
                end

                ST_SBOX_READ: begin
                    // Nesta borda, as 10 ROMs capturam os endereços
                    // vindos de state e round_key.
                    // No ciclo seguinte, os 20 dados de S-box estarão disponíveis.
                    fsm <= ST_ROUND_COMMIT;
                end

                ST_ROUND_COMMIT: begin
                    if (round < LAST_ROUND) begin
                        // Rodadas 1 a 9: têm MixColumns.
                        state     <= middle_round_state;
                        round_key <= next_round_key;
                        round     <= round + 4'd1;

                        fsm       <= ST_SBOX_READ;
                    end else begin
                        // Rodada 10: não tem MixColumns.
                        output_block <= final_round_state;
                        output_valid <= 1'b1;

                        if (input_valid) begin
                            // Modo contínuo:
                            // entrega o resultado atual e já captura o próximo bloco.
                            state     <= input_block ^ key;
                            round_key <= key;
                            round     <= 4'd1;

                            busy      <= 1'b1;
                            fsm       <= ST_SBOX_READ;
                        end else begin
                            // Sem novo bloco disponível: para.
                            busy      <= 1'b0;
                            round     <= 4'd0;
                            fsm       <= ST_IDLE;
                        end
                    end
                end

                default: begin
                    fsm  <= ST_IDLE;
                    busy <= 1'b0;
                end

            endcase
        end
    end

    // ============================================================
    // ShiftRows
    // ============================================================

    function [127:0] ShiftRows;
        input [127:0] in;

        reg [7:0] b0;
        reg [7:0] b1;
        reg [7:0] b2;
        reg [7:0] b3;

        reg [7:0] b4;
        reg [7:0] b5;
        reg [7:0] b6;
        reg [7:0] b7;

        reg [7:0] b8;
        reg [7:0] b9;
        reg [7:0] b10;
        reg [7:0] b11;

        reg [7:0] b12;
        reg [7:0] b13;
        reg [7:0] b14;
        reg [7:0] b15;

        begin
            b0  = in[127:120];
            b1  = in[119:112];
            b2  = in[111:104];
            b3  = in[103:96];

            b4  = in[95:88];
            b5  = in[87:80];
            b6  = in[79:72];
            b7  = in[71:64];

            b8  = in[63:56];
            b9  = in[55:48];
            b10 = in[47:40];
            b11 = in[39:32];

            b12 = in[31:24];
            b13 = in[23:16];
            b14 = in[15:8];
            b15 = in[7:0];

            ShiftRows = {
                b0,  b5,  b10, b15,
                b4,  b9,  b14, b3,
                b8,  b13, b2,  b7,
                b12, b1,  b6,  b11
            };
        end
    endfunction

    // ============================================================
    // MixColumns
    // ============================================================

    function [127:0] MixColumns;
        input [127:0] in;

        reg [7:0] a00;
        reg [7:0] a10;
        reg [7:0] a20;
        reg [7:0] a30;

        reg [7:0] a01;
        reg [7:0] a11;
        reg [7:0] a21;
        reg [7:0] a31;

        reg [7:0] a02;
        reg [7:0] a12;
        reg [7:0] a22;
        reg [7:0] a32;

        reg [7:0] a03;
        reg [7:0] a13;
        reg [7:0] a23;
        reg [7:0] a33;

        reg [127:0] out;

        begin
            out = 128'd0;

            // word 0
            a00 = in[127:120];
            a10 = in[119:112];
            a20 = in[111:104];
            a30 = in[103:96];

            out[127:120] = mul2(a00) ^ mul3(a10) ^ a20       ^ a30;
            out[119:112] = a00       ^ mul2(a10) ^ mul3(a20) ^ a30;
            out[111:104] = a00       ^ a10       ^ mul2(a20) ^ mul3(a30);
            out[103:96]  = mul3(a00) ^ a10       ^ a20       ^ mul2(a30);

            // word 1
            a01 = in[95:88];
            a11 = in[87:80];
            a21 = in[79:72];
            a31 = in[71:64];

            out[95:88] = mul2(a01) ^ mul3(a11) ^ a21       ^ a31;
            out[87:80] = a01       ^ mul2(a11) ^ mul3(a21) ^ a31;
            out[79:72] = a01       ^ a11       ^ mul2(a21) ^ mul3(a31);
            out[71:64] = mul3(a01) ^ a11       ^ a21       ^ mul2(a31);

            // word 2
            a02 = in[63:56];
            a12 = in[55:48];
            a22 = in[47:40];
            a32 = in[39:32];

            out[63:56] = mul2(a02) ^ mul3(a12) ^ a22       ^ a32;
            out[55:48] = a02       ^ mul2(a12) ^ mul3(a22) ^ a32;
            out[47:40] = a02       ^ a12       ^ mul2(a22) ^ mul3(a32);
            out[39:32] = mul3(a02) ^ a12       ^ a22       ^ mul2(a32);

            // word 3
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

    // ============================================================
    // Operações em GF(2^8)
    // ============================================================

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

    // ============================================================
    // Rcon
    // ============================================================

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

    // ============================================================
    // KeyExpansion sem S-box interna
    // ============================================================

    function [127:0] KeyExpansionNoSbox;
        input [127:0] k;
        input [3:0]   r;
        input [31:0]  subword;

        reg [31:0] w0;
        reg [31:0] w1;
        reg [31:0] w2;
        reg [31:0] w3;

        reg [31:0] nw0;
        reg [31:0] nw1;
        reg [31:0] nw2;
        reg [31:0] nw3;

        begin
            w0 = k[127:96];
            w1 = k[95:64];
            w2 = k[63:32];
            w3 = k[31:0];

            nw0 = w0 ^ subword ^ rcon(r);
            nw1 = w1 ^ nw0;
            nw2 = w2 ^ nw1;
            nw3 = w3 ^ nw2;

            KeyExpansionNoSbox = {nw0, nw1, nw2, nw3};
        end
    endfunction

endmodule
