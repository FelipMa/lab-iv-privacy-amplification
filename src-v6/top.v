`timescale 1ns / 1ps

module top #(
    // Parametros Globais do Privacy Amplification
    parameter N = 640,
    parameter W = 64,
    parameter P = 32,
    parameter L = 64,
    parameter ROM_ADDR_BITS = 5,
    parameter LUT_DEPTH = 5,
    parameter MEM_DEPTH = 32
)(
    input  wire           clock,
    input  wire           reset,
    output wire [(P-1):0] hash_register,
    output wire           batch_ready,
    output wire           done
);

    localparam CYCLES     = (N + W - 1) / W;
    localparam BATCHES    = (L + P - 1) / P;
    localparam BATCH_BITS = $clog2(BATCHES);

    wire                     sys_reset;

    // rom_key <-> Input_Buffer
    wire [(ROM_ADDR_BITS-1):0] rom_key_addr;
    wire [(W-1):0]             rom_key_q;

    // Input_Buffer <-> controlador
    wire                     buf_ready, buf_out_valid, buf_done;
    wire [(W-1):0]           buf_out_data;
    wire                     buf_prepare, buf_go;

    // matrix_lut <-> controlador
    wire [(LUT_DEPTH-1):0]   matrix_addr_reg;
    wire [(W+P-2):0]         current_matrix_window;

    // controlador <-> compression_unit
    wire                     clear_acc, enable;
    wire [(P-1):0]           current_hash_out;

    // controlador <-> ram_dump
    wire                     ram_we;
    wire [BATCH_BITS:0]      ram_address;

    
    // datapath combinacional
    
    wire [(W-1):0]   safe_key    = buf_out_valid ? buf_out_data          : {W{1'b0}};
    wire [(W+P-2):0] safe_window = buf_out_valid ? current_matrix_window : {(W+P-1){1'b0}};


    controlador #(
        .N(N),
        .W(W),
        .P(P),
        .L(L),
        .LUT_DEPTH(LUT_DEPTH)
    ) u_controlador (
        .clock            (clock),
        .reset            (reset),
        .buf_ready        (buf_ready),
        .current_hash_out (current_hash_out),
        .sys_reset        (sys_reset),
        .buf_prepare      (buf_prepare),
        .buf_go           (buf_go),
        .matrix_addr_reg  (matrix_addr_reg),
        .clear_acc        (clear_acc),
        .enable           (enable),
        .hash_register    (hash_register),
        .batch_ready      (batch_ready),
        .done             (done),
        .ram_we           (ram_we),
        .ram_address      (ram_address)
    );


    Input_Buffer #(
        .DEPTH(CYCLES),
        .ADDR_BITS(ROM_ADDR_BITS),
        .DATA_BITS(W),
        .REPEAT_COUNT(BATCHES)
    ) u_input_buffer (
        .clk(clock),
        .rst_n(!sys_reset),
        .prepare(buf_prepare),
        .go(buf_go),
        .rom_q(rom_key_q),
        .rom_addr(rom_key_addr),
        .rom_clock(),
        .out_data(buf_out_data),
        .out_valid(buf_out_valid),
        .ready_to_stream(buf_ready),
        .done(buf_done)
    );

    rom_key #(
        .DATA_BITS(W),
        .ADDR_BITS(ROM_ADDR_BITS),
        .DEPTH(MEM_DEPTH)
    ) uut_rom_key (
        .address (rom_key_addr),
        .clock   (clock),
        .q       (rom_key_q)
    );


    matrix_lut u_matrix_lut(
        .clock(clock),
        .address(matrix_addr_reg),
        .q(current_matrix_window)
    );


    compression_unit #(
        .P(P),
        .W(W)
    ) u_compression_unit(
        .clock(clock),
        .reset(sys_reset),
        .clear_acc(clear_acc),
        .enable(enable),
        .key(safe_key),
        .matrix_window(safe_window),
        .hash_out(current_hash_out)
    );


    ram_dump #(
        .DATA_BITS(P),
        .ADDR_BITS(BATCH_BITS + 1)
    ) u_ram_dump (
        .clock   (clock),
        .we      (ram_we),
        .address (ram_address),
        .data_in (hash_register)
    );

endmodule
