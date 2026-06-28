`timescale 1ns/1ps

module aes_sbox_rom_2p (
    input  wire       clock,

    input  wire [7:0] addr_a,
    input  wire [7:0] addr_b,

    output reg  [7:0] data_a,
    output reg  [7:0] data_b
);

    // Quartus: tenta inferir a ROM em bloco M9K. Cada instância fornece 2 leituras síncronas por ciclo.
    (* ramstyle = "M9K" *) reg [7:0] rom [0:255];

    initial begin
        $readmemh("aes_sbox.hex", rom);
    end

    always @(posedge clock) begin
        data_a <= rom[addr_a];
        data_b <= rom[addr_b];
    end

endmodule
