`timescale 1ns / 1ps

module rom_key #(
    parameter DATA_BITS = 64,
    parameter ADDR_BITS = 5,
    parameter DEPTH     = 32
)(
    input  wire [ADDR_BITS-1:0] address,
    input  wire                 clock,
    output wire [DATA_BITS-1:0] q
);

    altsyncram #(
        .operation_mode         ("ROM"),
        .intended_device_family ("Cyclone IV E"),
        .width_a                (DATA_BITS),
        .widthad_a              (ADDR_BITS),
        .numwords_a             (DEPTH),
        .outdata_reg_a          ("UNREGISTERED"),
        .address_aclr_a         ("NONE"),
        .outdata_aclr_a         ("NONE"),
        .init_file              ("key.mif"),
        .lpm_type               ("altsyncram")
    ) altsyncram_component (
        // Apenas os pinos válidos para leitura simples em 1 Porta
        .clock0         (clock),
        .address_a      (address),
        .q_a            (q)
    );

endmodule