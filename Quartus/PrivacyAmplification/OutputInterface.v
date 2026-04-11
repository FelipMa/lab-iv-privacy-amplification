//===================================================================================
// File: OutputInterface.v
//===================================================================================

module OutputInterface (m_axis_tdata, m_axis_tvalid, s_axis_tready, error,
												s_axis_tdata, s_axis_tvalid, m_axis_tready, 
												clock, reset, enable);

parameter DATA_IN_WIDTH  = 512;	// Input chunk width
parameter DATA_OUT_WIDTH = 32;  // Output word width
parameter CHUNK_WORDS    = 16;  // 16 = 512/32
parameter CNT_WIDTH      = 4;   // log2(16)

// Control
input  wire clock;
input  wire reset;
input  wire enable;

// AXI4-Stream Slave (input)
input  wire [DATA_IN_WIDTH-1:0]  s_axis_tdata;
input  wire                      s_axis_tvalid;
output wire                      s_axis_tready;

// AXI4-Stream Master (output)
output reg  [DATA_OUT_WIDTH-1:0] m_axis_tdata;
output reg                       m_axis_tvalid;
input  wire                      m_axis_tready;

// Status
output reg                       error;
 
// Chunk splitter
reg [CNT_WIDTH-1:0] 		word_cnt;
reg [DATA_IN_WIDTH-1:0] chunk_buffer;
reg                 		chunk_busy;   // In processing

// Data write in FIFO
reg [31:0] fifo_wrdata;
reg        fifo_wrreq_int;

// Internal wires for FIFO IP
wire        fifo_wrreq;
wire        fifo_rdreq;
wire [31:0] fifo_q;				
wire        fifo_full;
wire        fifo_empty;												
												
reg fifo_rdreq_d; // To 1 cycle delay, because FIFO IP output register

// ===== FIFO (IP Quartus 18.1) =====
FIFO fifo_out
(
	.data(fifo_wrdata) ,	
	.wrreq(fifo_wrreq) ,
	.rdreq(fifo_rdreq) ,
	.clock(clock) ,
	.sclr(reset) ,
	.q(fifo_q) ,	
	.full(fifo_full) ,	
	.empty(fifo_empty)
);

// Input handshake
assign s_axis_tready = enable && !chunk_busy;
// FIFO write control
assign fifo_wrreq = fifo_wrreq_int;
// FIFO read control
assign fifo_rdreq = !fifo_empty && m_axis_tready;

// Sequencial logic
always @(posedge clock) 
begin
	if (reset) 
	begin
		m_axis_tdata   <= {DATA_OUT_WIDTH{1'b0}};
		m_axis_tvalid  <= 1'b0;
		error          <= 1'b0;
		chunk_buffer   <= {DATA_IN_WIDTH{1'b0}};
		word_cnt       <= {CNT_WIDTH{1'b0}};
		chunk_busy     <= 1'b0;
		fifo_wrdata    <= 32'b0;
		fifo_wrreq_int <= 1'b0;
		fifo_rdreq_d   <= 1'b0;
	end
	else if (enable) 
	begin
		// Reading the input chunk
		if (s_axis_tvalid && s_axis_tready) 
		begin
			chunk_buffer <= s_axis_tdata;
			chunk_busy   <= 1'b1;
			word_cnt     <= {CNT_WIDTH{1'b0}};
		end
		
		// Extract words and write them in FIFO
		if (chunk_busy && !fifo_full) 
		begin
			// Select the next 32-bit word (LSB first)
			fifo_wrdata <= chunk_buffer[(word_cnt * DATA_OUT_WIDTH) +: DATA_OUT_WIDTH];
			fifo_wrreq_int <= 1'b1;
			if (word_cnt == CHUNK_WORDS - 1)
			begin
				chunk_busy <= 1'b0;   // Chunk completely processed
			end
			else
			begin
				word_cnt <= word_cnt + 1'b1;
			end
		end
		else 
		begin
			fifo_wrreq_int <= 1'b0;
		end
		
		// FIFO reading for output (compensating for latency)
		fifo_rdreq_d <= fifo_rdreq;

		if (fifo_rdreq_d) 
		begin
			m_axis_tdata <= fifo_q;
			m_axis_tvalid <= 1'b1;
		end
		else 
		begin
			m_axis_tvalid <= 1'b0;
		end

		// Error detection
		if (fifo_wrreq_int && fifo_full)
		begin
			error <= 1'b1; // Overflow
		end
		if (fifo_rdreq && fifo_empty)
		begin
			error <= 1'b1; // Underflow
		end
	end
end

endmodule
