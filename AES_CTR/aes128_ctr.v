`timescale 1ns/1ps

// AES-128 CTR wrapper.
// For each input block, it encrypts {nonce[95:0], counter[31:0]}
// and XORs the resulting keystream with plaintext.
// byte_enable[15] controls plaintext[127:120]; byte_enable[0] controls plaintext[7:0].
module aes128_ctr (
    input  wire         clk,
    input  wire         reset_n,
    input  wire         init,
    input  wire         start,
    input  wire [127:0] key,
    input  wire [95:0]  nonce,
    input  wire [31:0]  initial_counter,
    input  wire [127:0] plaintext,
    input  wire [15:0]  byte_enable,
    output reg  [127:0] ciphertext,
    output reg  [31:0]  counter_value,
    output reg          busy,
    output reg          done
);
    reg [31:0]  counter_reg;
    reg [31:0]  used_counter;
    reg [127:0] plaintext_reg;
    reg [15:0]  byte_enable_reg;
    reg [127:0] aes_plaintext;
    reg         aes_start;

    wire [31:0]  selected_counter;
    wire [127:0] keystream;
    wire         aes_busy;
    wire         aes_done;

    assign selected_counter = init ? initial_counter : counter_reg;

    aes128_encrypt u_aes128_encrypt (
        .clk(clk),
        .reset_n(reset_n),
        .start(aes_start),
        .key(key),
        .plaintext(aes_plaintext),
        .ciphertext(keystream),
        .busy(aes_busy),
        .done(aes_done)
    );

    always @(posedge clk) begin
        if (!reset_n) begin
            counter_reg     <= 32'd0;
            used_counter    <= 32'd0;
            plaintext_reg   <= 128'd0;
            byte_enable_reg <= 16'd0;
            aes_plaintext   <= 128'd0;
            aes_start       <= 1'b0;
            ciphertext      <= 128'd0;
            counter_value   <= 32'd0;
            busy            <= 1'b0;
            done            <= 1'b0;
        end else begin
            aes_start <= 1'b0;
            done      <= 1'b0;

            if (init && !busy && !start) begin
                counter_reg <= initial_counter;
            end

            if (start && !busy) begin
                used_counter    <= selected_counter;
                counter_value   <= selected_counter;
                plaintext_reg   <= plaintext;
                byte_enable_reg <= byte_enable;
                aes_plaintext   <= {nonce, selected_counter};
                aes_start       <= 1'b1;
                busy            <= 1'b1;
            end else if (busy && aes_done) begin
                ciphertext  <= xor_with_keep(plaintext_reg, keystream, byte_enable_reg);
                counter_reg <= used_counter + 32'd1;
                busy        <= 1'b0;
                done        <= 1'b1;
            end
        end
    end

    function [127:0] xor_with_keep;
        input [127:0] p;
        input [127:0] ks;
        input [15:0]  keep;
        integer i;
        begin
            xor_with_keep = 128'd0;
            for (i = 0; i < 16; i = i + 1) begin
                if (keep[15 - i]) begin
                    xor_with_keep[127 - 8*i -: 8] = p[127 - 8*i -: 8] ^ ks[127 - 8*i -: 8];
                end else begin
                    xor_with_keep[127 - 8*i -: 8] = 8'h00;
                end
            end
        end
    endfunction
endmodule
