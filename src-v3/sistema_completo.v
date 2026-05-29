// Copyright (C) 2018  Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions 
// and other software and tools, and its AMPP partner logic 
// functions, and any output files from any of the foregoing 
// (including device programming or simulation files), and any 
// associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License 
// Subscription Agreement, the Intel Quartus Prime License Agreement,
// the Intel FPGA IP License Agreement, or other applicable license
// agreement, including, without limitation, that your use is for
// the sole purpose of programming logic devices manufactured by
// Intel and sold by Intel or its authorized distributors.  Please
// refer to the applicable agreement for further details.

// PROGRAM		"Quartus Prime"
// VERSION		"Version 18.1.0 Build 625 09/12/2018 SJ Lite Edition"
// CREATED		"Wed May 27 16:21:25 2026"

module sistema_completo(
	CLOCK_50,
	SW,
	LEDG,
	SAIDA_HASH
);


input wire	CLOCK_50;
input wire	[0:0] SW;
output wire	[0:0] LEDG;
output wire	[31:0] SAIDA_HASH;

wire	SYNTHESIZED_WIRE_7;
wire	[63:0] SYNTHESIZED_WIRE_1;
wire	[94:0] SYNTHESIZED_WIRE_2;
wire	[4:0] SYNTHESIZED_WIRE_4;
wire	[4:0] SYNTHESIZED_WIRE_6;





top	b2v_inst(
	.clock(SYNTHESIZED_WIRE_7),
	.reset(SW),
	.rom_key_q(SYNTHESIZED_WIRE_1),
	.rom_matrix_q(SYNTHESIZED_WIRE_2),
	.done(LEDG),
	.hash_register(SAIDA_HASH),
	.rom_key_addr(SYNTHESIZED_WIRE_4),
	.rom_matrix_addr(SYNTHESIZED_WIRE_6));
	defparam	b2v_inst.L = 64;
	defparam	b2v_inst.N = 640;
	defparam	b2v_inst.P = 32;
	defparam	b2v_inst.W = 64;


pll_150	b2v_inst1(
	.inclk0(CLOCK_50),
	.c0(SYNTHESIZED_WIRE_7));


rom_key	b2v_inst2(
	.clock(SYNTHESIZED_WIRE_7),
	.address(SYNTHESIZED_WIRE_4),
	.q(SYNTHESIZED_WIRE_1));


rom_matrix	b2v_inst3(
	.clock(SYNTHESIZED_WIRE_7),
	.address(SYNTHESIZED_WIRE_6),
	.q(SYNTHESIZED_WIRE_2));


endmodule
