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
// CREATED		"Sat Apr 11 16:58:32 2026"

module PrivacyAmplification(
	clock,
	reset,
	enable,
	m_axis_tready,
	s_axis_tvalid,
	s_axis_tdata,
	ib_error,
	s_axis_tready,
	oi_error,
	m_axis_tvalid,
	m_axis_tdata
);


input wire	clock;
input wire	reset;
input wire	enable;
input wire	m_axis_tready;
input wire	s_axis_tvalid;
input wire	[31:0] s_axis_tdata;
output wire	ib_error;
output wire	s_axis_tready;
output wire	oi_error;
output wire	m_axis_tvalid;
output wire	[31:0] m_axis_tdata;

wire	SYNTHESIZED_WIRE_0;
wire	SYNTHESIZED_WIRE_1;
wire	[511:0] SYNTHESIZED_WIRE_2;
wire	SYNTHESIZED_WIRE_3;
wire	SYNTHESIZED_WIRE_4;
wire	[511:0] SYNTHESIZED_WIRE_5;


InputBuffer	b2v_IB(
	.s_axis_tvalid(s_axis_tvalid),
	.m_axis_tready(SYNTHESIZED_WIRE_0),
	.clock(clock),
	.reset(reset),
	.enable(enable),
	.s_axis_tdata(s_axis_tdata),
	.m_axis_tvalid(SYNTHESIZED_WIRE_3),
	.s_axis_tready(s_axis_tready),
	.error(ib_error),
	.m_axis_tdata(SYNTHESIZED_WIRE_5));
	defparam	b2v_IB.CHUNK_WORDS = 16;
	defparam	b2v_IB.CNT_WIDTH = 4;
	defparam	b2v_IB.DATA_IN_WIDTH = 32;
	defparam	b2v_IB.DATA_OUT_WIDTH = 512;


OutputInterface	b2v_OI(
	.s_axis_tvalid(SYNTHESIZED_WIRE_1),
	.m_axis_tready(m_axis_tready),
	.clock(clock),
	.reset(reset),
	.enable(enable),
	.s_axis_tdata(SYNTHESIZED_WIRE_2),
	.m_axis_tvalid(m_axis_tvalid),
	.s_axis_tready(SYNTHESIZED_WIRE_4),
	.error(oi_error),
	.m_axis_tdata(m_axis_tdata));
	defparam	b2v_OI.CHUNK_WORDS = 16;
	defparam	b2v_OI.CNT_WIDTH = 4;
	defparam	b2v_OI.DATA_IN_WIDTH = 512;
	defparam	b2v_OI.DATA_OUT_WIDTH = 32;


PipelineRegister	b2v_R1(
	.s_axis_tvalid(SYNTHESIZED_WIRE_3),
	.m_axis_tready(SYNTHESIZED_WIRE_4),
	.clock(clock),
	.reset(reset),
	.s_axis_tdata(SYNTHESIZED_WIRE_5),
	.m_axis_tvalid(SYNTHESIZED_WIRE_1),
	.s_axis_tready(SYNTHESIZED_WIRE_0),
	.m_axis_tdata(SYNTHESIZED_WIRE_2));
	defparam	b2v_R1.WIDTH = 512;


endmodule
