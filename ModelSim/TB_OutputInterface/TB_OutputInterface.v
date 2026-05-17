//===================================================================================
// File: TB_OutputInterface.v
//===================================================================================

`timescale 1 ns / 1 ps

module TB_OutputInterface();

parameter DATA_IN_WIDTH  = 512;	// Input chunk width
parameter DATA_OUT_WIDTH = 32;  // Output word width
parameter CHUNK_WORDS    = 16;  // 16 = 512/32
parameter CNT_WIDTH      = 4;   // log2(16)

// Control
reg clock;
reg reset;
reg enable;

// AXI4-Stream Slave (input)
reg [DATA_IN_WIDTH-1:0]  s_axis_tdata;
reg                      s_axis_tvalid;
wire                     s_axis_tready;

// AXI4-Stream Master (output)
wire  [DATA_OUT_WIDTH-1:0] m_axis_tdata;
wire                       m_axis_tvalid;
reg                        m_axis_tready;

// Status
wire error;

// ===== Output Interface Module =====
OutputInterface #(
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

// Task: Send a chunk of (DATA_IN_WIDTH-1) bits using a handshake
task send_chunk;
	input [DATA_IN_WIDTH-1:0] chunk;
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

// Task: Read a word of (DATA_OUT_WIDTH-1) bits from the output (with timeout)
task read_word;
	output [DATA_OUT_WIDTH-1:0] word;
	integer timeout;
begin
	timeout = 0;
	while (!m_axis_tvalid && timeout < 10000) 
	begin
		@(posedge clock);
		timeout = timeout + 1;
	end
	if (timeout >= 10000) 
	begin
		$display("ERROR: timeout waiting for exit word");
		$stop;
	end
	word = m_axis_tdata;
	@(posedge clock);
end
endtask

// Main process
integer file_in, file_out;
reg [7:0] c;
integer bit_cnt, word_cnt, chunk_cnt, total_bits;
reg [31:0] word_buf;
reg [31:0] chunk_words [0:CHUNK_WORDS-1]; // buffer for the CHUNK_WORDS of the current chunk
integer i;
integer test_passed;
reg [31:0] received_word;
integer total_bits_written;

reg [511:0] chunk;
integer j;

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

	$display("Simulation started, enable activated");

	file_in = $fopen("key_rec.txt", "r");
	if (file_in == 0) 
	begin
		$display("ERROR: Failed to open key_rec.txt");
		$stop;
	end
	$display("The key_rec.txt file is open.");

	file_out = $fopen("key_final.txt", "w");
	if (file_out == 0) 
	begin
		$display("ERROR: Could not create key_final.txt");
		$stop;
	end

	// Initialize counters
	bit_cnt = 0;
	word_cnt = 0;
	chunk_cnt = 0;
	total_bits = 0;
	word_buf = 0;
	total_bits_written = 0;

	// Bit-by-bit file reading, word formation, and chunk creation.
	$display("\n--- Reading bits from key_rec.txt and sending chunks ---");
	while (!$feof(file_in)) 
	begin
		c = $fgetc(file_in);
		if (c == "0" || c == "1") 
		begin
			c = c - "0";
			word_buf = word_buf | (c << bit_cnt);
			bit_cnt = bit_cnt + 1;
			total_bits = total_bits + 1;

			if (bit_cnt == 32) 
			begin
				// Complete word: stored in the current chunk buffer
				chunk_words[word_cnt] = word_buf;
				word_cnt = word_cnt + 1;
				bit_cnt = 0;
				word_buf = 0;

				if (word_cnt == CHUNK_WORDS) 
				begin
					// Complete chunk: assemble and ship
					chunk = 0;
					for (j = 0; j < CHUNK_WORDS; j = j+1) 
					begin
						chunk[(j*32) +: 32] = chunk_words[j];
					end
					send_chunk(chunk);
					chunk_cnt = chunk_cnt + 1;

					// Read the 16 output words and compare them.
					for (j = 0; j < CHUNK_WORDS; j = j+1) 
					begin
						read_word(received_word);
						if (received_word !== chunk_words[j]) 
						begin
							$display("ERRO in chunk: %0d, word: %0d expected: 0x%h, received: 0x%h",
											 chunk_cnt-1, j, chunk_words[j], received_word);
							test_passed = 0;
						end
						// Divide the received word into parts and write them in the file.
						for (i = 0; i < 32; i = i+1) 
						begin
							if (received_word[i])
							begin
								$fdisplay(file_out, "1");
							end
							else
							begin
								$fdisplay(file_out, "0");
							end
							
							total_bits_written = total_bits_written + 1;
						end
					end
					word_cnt = 0;
				end
			end
		end
	end
	
	$fclose(file_in);

	// Check if there are any leftover bits (that don't form a complete chunk).
	if (bit_cnt != 0 || word_cnt != 0) 
	begin
		$display("WARNING: %0d unused bits (total not a multiple of 512))", (bit_cnt + word_cnt*32));
	end

	// Wait for the output to finish (if there are still words in FIFO)
	while (m_axis_tvalid) @(posedge clock);
	
	#100;
	$fclose(file_out);

	// --------------------------------------------------------------
	// Results
	// --------------------------------------------------------------
	$display("\n==========================================");
	$display("TEST RESULT");
	$display("Total bits read: %0d", total_bits);
	$display("Total bits written: %0d", total_bits_written);
	$display("Total chunks sent: %0d", chunk_cnt);
	if (test_passed && (total_bits_written == total_bits - (total_bits % DATA_IN_WIDTH))) 
	begin
		$display("*** TEST PASSED ***");
		$display("TThe generated key_final.txt file (including any bits discarded at the end)");
	end 
	else 
	begin
		$display("*** TEST FAILED ***");
	end
	$display("==========================================");
	$stop;
end

endmodule
