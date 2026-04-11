//=====================================================================
// File: TB_InputBuffer
//=====================================================================

`timescale 1 ns / 1 ps

module TB_InputBuffer();

parameter DATA_IN_WIDTH  = 32;  // Input word width
parameter DATA_OUT_WIDTH = 512; // Output chunk width
parameter CHUNK_WORDS    = 16;  // 16 = 512/32
parameter CNT_WIDTH      = 4;   // log2(16)

// Control
reg clock;
reg reset;
reg enable;

// AXI4-Stream Slave (input)
reg [DATA_IN_WIDTH-1:0] s_axis_tdata;
reg                     s_axis_tvalid;
wire        						s_axis_tready;

// AXI4-Stream Master (output)
wire [DATA_OUT_WIDTH-1:0] m_axis_tdata;
wire        							m_axis_tvalid;
reg         							m_axis_tready;

// Status
wire error;

// ===== Input Buffer Module =====
InputBuffer #(
		.DATA_IN_WIDTH (DATA_IN_WIDTH),
		.DATA_OUT_WIDTH(DATA_OUT_WIDTH),
		.CHUNK_WORDS   (CHUNK_WORDS),
		.CNT_WIDTH     (CNT_WIDTH)
) DUV (
		.clock(clock),
		.reset(reset),
		.enable(enable),
		.s_axis_tdata(s_axis_tdata),
		.s_axis_tvalid(s_axis_tvalid),
		.s_axis_tready(s_axis_tready),
		.m_axis_tdata(m_axis_tdata),
		.m_axis_tvalid(m_axis_tvalid),
		.m_axis_tready(m_axis_tready),
		.error(error)
);

// Clock de 100 MHz --> period 10ns
always #5 clock = ~clock;

// Task: send a (DATA_IN_WIDTH-1)-bit word with a handshake
task send_word;
	input [DATA_IN_WIDTH-1:0] word;
begin
	@(posedge clock);
	s_axis_tdata = word;
	s_axis_tvalid = 1;
	while (!s_axis_tready) @(posedge clock);
	@(posedge clock);
	s_axis_tvalid = 0;
	s_axis_tdata = 0;
end
endtask

// Task: verify an output chunk
task check_chunk;
	input [DATA_OUT_WIDTH-1:0] expected;
	input integer chunk_id;
begin
	@(posedge clock);
	while (!m_axis_tvalid) @(posedge clock);
	#1;
	if (m_axis_tdata === expected) 
	begin
		$display("Chunk %0d: OK", chunk_id);
	end 
	else 
	begin
		$display("Chunk %0d: ERROR!", chunk_id);
		$display("Expected: %b", expected);
		$display("Obtained: %b", m_axis_tdata);
	end
	@(posedge clock);
end
endtask

// Main process 
integer file;
reg [7:0] c;
integer bit_cnt, word_cnt, chunk_cnt, total_bits;
reg [DATA_IN_WIDTH-1:0] word_buf;
reg [DATA_OUT_WIDTH-1:0] expected_chunk;
integer test_passed;

initial 
begin
	clock = 0;
	reset = 1;
	enable = 0;
	s_axis_tvalid = 0;
	m_axis_tready = 1;
	test_passed = 1;

	// Reset
	repeat(5) @(posedge clock);
	reset = 0;
	repeat(2) @(posedge clock);
	enable = 1;

	$display("Simulation started, enable activated.");
	
	file = $fopen("key_rec.txt", "r");
	if (file == 0) 
	begin
		$display("ERROR: Failed to open key_rec.txt");
		$finish;
	end
	$display("The key_rec.txt file is open.");

	// Initialize counters
	bit_cnt = 0;
	word_cnt = 0;
	chunk_cnt = 0;
	total_bits = 0;
	word_buf = 0;
	expected_chunk = 0;

	// Character-by-character reading
	while (!$feof(file)) 
	begin
		c = $fgetc(file);
		if (c == "0" || c == "1") 
		begin
			bit_cnt = bit_cnt + 1;
			total_bits = total_bits + 1;
		end

		if (bit_cnt == 32) 
		begin
			send_word(word_buf);
			// Accumulates in the expected chunk
			expected_chunk[(word_cnt*32) +: 32] = word_buf;
			word_cnt = word_cnt + 1;
			bit_cnt = 0;
			word_buf = 0;

			if (word_cnt == CHUNK_WORDS) 
			begin
				#2;
				check_chunk(expected_chunk, chunk_cnt);
				chunk_cnt = chunk_cnt + 1;
				word_cnt = 0;
				expected_chunk = 0;
			end
		end
	end

	$fclose(file);

	if (bit_cnt != 0) 
	begin
		$display("WARNING: %0d unused bits (total not a multiple of 512)", bit_cnt);
	end

	// Waiting for the last chunk
	while (m_axis_tvalid) @(posedge clock);
	#100;

	$display("\n==========================================");
	$display("TEST RESULT");
	$display("Total bits read: %0d", total_bits);
	$display("Total chunks verified: %0d", chunk_cnt);
	$display("==========================================");
	$stop;
end

endmodule
