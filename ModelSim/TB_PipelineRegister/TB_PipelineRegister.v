//=====================================================================
// File: TB_PipelineRegister.v
//=====================================================================

`timescale 1 ns / 1 ps

module TB_PipelineRegister();

parameter DATA_WIDTH  = 512;   // PipelineRegister width
parameter WORD_WIDTH  = 32;    // Input word width
parameter CHUNK_WORDS = 16;    // 512/32

// Control
reg clock;
reg reset;
reg enable;   // (not used, but maintained to consistency)

// AXI4-Stream Slave (input)
reg [DATA_WIDTH-1:0] s_axis_tdata;
reg                  s_axis_tvalid;
wire                 s_axis_tready;

// AXI4-Stream Master (output)
wire [DATA_WIDTH-1:0] m_axis_tdata;
wire                  m_axis_tvalid;
reg                   m_axis_tready;

// ===== PipelineRegister Module =====
PipelineRegister #(
	.WIDTH(DATA_WIDTH)
)	DUV (
	.clock(clock),
	.reset(reset),
	.s_axis_tdata(s_axis_tdata),
	.s_axis_tvalid(s_axis_tvalid),
	.s_axis_tready(s_axis_tready),
	.m_axis_tdata(m_axis_tdata),
	.m_axis_tvalid(m_axis_tvalid),
	.m_axis_tready(m_axis_tready)
);

// Clock de 100 MHz -> período 10 ns
always #5 clock = ~clock;

// Task: Send a chunk of (DATA_IN_WIDTH-1) bits using a handshake
task send_chunk;
	input [DATA_WIDTH-1:0] chunk;
begin
	@(posedge clock);
	s_axis_tdata = chunk;
	s_axis_tvalid = 1;
	while (!s_axis_tready) @(posedge clock);
	@(posedge clock);
	s_axis_tvalid = 0;
	s_axis_tdata = 0;
end
endtask

// Task: Check output block (with a timeout) and write bits in file
task check_and_write_chunk;
	input [DATA_WIDTH-1:0] expected;
	input integer chunk_id;
	input integer file_out;
	integer timeout;
	integer bit_idx;
begin
	timeout = 0;
	while (!m_axis_tvalid && timeout < 10000) 
	begin
		@(posedge clock);
		timeout = timeout + 1;
	end
	if (timeout >= 10000) 
	begin
		$display("Chunk %0d: TIMEOUT (no output)", chunk_id);
		$finish;
	end
	#1;
	if (m_axis_tdata === expected) 
	begin
		$display("Chunk %0d: OK", chunk_id);
	end 
	else 
	begin
		$display("Chunk %0d: ERROR!", chunk_id);
		$display("Expected: %h", expected);
		$display("Obtained: %h", m_axis_tdata);
	end
	// Writes the bits (from LSB) to the file key_chunk.txt
	for (bit_idx = 0; bit_idx < DATA_WIDTH; bit_idx = bit_idx + 1) 
	begin
		if (m_axis_tdata[bit_idx])
		begin
			$fdisplay(file_out, "1");
		end
		else
		begin
			$fdisplay(file_out, "0");
		end
	end
	@(posedge clock);
end

endtask

// Main Process
integer file_in, file_out;
reg [7:0] c;
integer bit_cnt, word_cnt, chunk_cnt, total_bits;
reg [WORD_WIDTH-1:0] word_buf;
reg [WORD_WIDTH-1:0] chunk_words [0:CHUNK_WORDS-1];
reg [DATA_WIDTH-1:0] chunk;
integer i, j;
integer test_passed;

initial begin
	clock = 0;
	reset = 1;
	enable = 1;       // always enabled
	s_axis_tvalid = 0;
	m_axis_tready = 1;
	test_passed = 1;

	// Reset
	repeat(5) @(posedge clock);
	reset = 0;
	repeat(2) @(posedge clock);
	$display("Simulation started, reset released.");

	file_in = $fopen("key_rec.txt", "r");
	if (file_in == 0) 
	begin
		$display("ERROR: Failed to open key_rec.txt");
		$finish;
	end
	$display("The key_rec.txt file is open");

	file_out = $fopen("key_chunk.txt", "w");
	if (file_out == 0) 
	begin
		$display("ERROR: Could not create key_chunk.txt");
		$finish;
	end

	// Initialize counters
	bit_cnt = 0;
	word_cnt = 0;
	chunk_cnt = 0;
	total_bits = 0;
	word_buf = 0;
	chunk = 0;

	$display("\n--- Reading bits from key_rec.txt, forming chunks and sending ---");
	while (!$feof(file_in)) 
	begin
		c = $fgetc(file_in);
		if (c == "0" || c == "1") 
		begin
			c = c - "0";
			word_buf = word_buf | (c << bit_cnt);
			bit_cnt = bit_cnt + 1;
			total_bits = total_bits + 1;

			if (bit_cnt == WORD_WIDTH) 
			begin
				// Palavra completa: armazena no buffer do chunk
				chunk_words[word_cnt] = word_buf;
				word_cnt = word_cnt + 1;
				bit_cnt = 0;
				word_buf = 0;

				if (word_cnt == CHUNK_WORDS) 
				begin
						// Monta chunk de 512 bits (LSB first)
						chunk = 0;
						for (j = 0; j < CHUNK_WORDS; j = j+1)
								chunk[(j*WORD_WIDTH) +: WORD_WIDTH] = chunk_words[j];
						// Envia o chunk para o PipelineRegister
						send_chunk(chunk);
						// Verifica e escreve bits do chunk de saída
						check_and_write_chunk(chunk, chunk_cnt, file_out);
						chunk_cnt = chunk_cnt + 1;
						word_cnt = 0;
				end
			end
		end
	end

	$fclose(file_in);

	// Check if there are any leftover bits (that don't form a complete chunk).
	if (bit_cnt != 0 || word_cnt != 0) 
	begin
		$display("WARNING: %0d unused bits (total not a multiple of 512)", (bit_cnt + word_cnt*WORD_WIDTH));
	end

	// Wait for the last chunk to be output (if there is one).
	while (m_axis_tvalid) @(posedge clock);
	#100;
	$fclose(file_out);
	
	// --------------------------------------------------------------
	// Results
	// --------------------------------------------------------------
	$display("\n==========================================");
	$display("TEST RESULT");
	$display("Total bits read: %0d", total_bits);
	$display("Total chunks verified: %0d", chunk_cnt);
	$display("Output written to key_chunk.txt (one bit per line)");
	$display("==========================================");
	$finish;
end

endmodule

