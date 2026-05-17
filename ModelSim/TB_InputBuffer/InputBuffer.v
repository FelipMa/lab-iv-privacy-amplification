//===================================================================================
// File: InputBuffer.v
//===================================================================================

module InputBuffer (m_axis_tdata, m_axis_tvalid, s_axis_tready, error,
										s_axis_tdata, s_axis_tvalid, m_axis_tready, 
										clock, reset, enable);
										
parameter DATA_IN_WIDTH  = 32;	// Input word width
parameter DATA_OUT_WIDTH = 512; // Output chunk width
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

// Chunk accumulation registers
reg [CNT_WIDTH-1:0]      word_cnt;
reg [DATA_OUT_WIDTH-1:0] chunk_buffer;
reg                      chunk_full;

// Internal wires for FIFO IP
wire        fifo_wrreq;
wire        fifo_rdreq;
wire [31:0] fifo_q;				
wire        fifo_full;
wire        fifo_empty;

reg fifo_rdreq_d; // To 1 cycle delay, because FIFO IP output register

// ===== FIFO (IP Quartus 18.1) =====
FIFO fifo_ib
(
	.data(s_axis_tdata) ,	
	.wrreq(fifo_wrreq) ,
	.rdreq(fifo_rdreq) ,
	.clock(clock) ,
	.sclr(reset) ,
	.q(fifo_q) ,	
	.full(fifo_full) ,	
	.empty(fifo_empty)
);

// Input handshake
assign s_axis_tready = enable && !fifo_full;
assign fifo_wrreq    = s_axis_tvalid && s_axis_tready;
// FIFO read control
assign fifo_rdreq = enable && !fifo_empty && !chunk_full && (word_cnt < CHUNK_WORDS);

// Sequencial logic
always @(posedge clock) 
begin
	if (reset) 
	begin
		m_axis_tdata  <= {DATA_OUT_WIDTH{1'b0}};
		m_axis_tvalid <= 1'b0;
		chunk_buffer <= {DATA_OUT_WIDTH{1'b0}};
		word_cnt   <= {CNT_WIDTH{1'b0}};
		chunk_full <= 1'b0;
		error      <= 1'b0;
		fifo_rdreq_d <= 1'b0;
	end 
	else if (enable) 
	begin 
		fifo_rdreq_d <= fifo_rdreq;
		// Read from FIFO and accumulate into chunk_buffer
		if (fifo_rdreq_d) 
		begin
			// Write into the correct 32-bit slice using indexed part-select
			chunk_buffer[ (word_cnt * DATA_IN_WIDTH) +: DATA_IN_WIDTH ] <= fifo_q;

			if (word_cnt == CHUNK_WORDS - 1) 
			begin
					chunk_full <= 1'b1;
			end 
			else 
			begin
					word_cnt <= word_cnt + 1'b1;
			end
		end
		
		// Output handshake
		if (chunk_full && !m_axis_tvalid) 
		begin
				m_axis_tdata  <= chunk_buffer;
				m_axis_tvalid <= 1'b1;
		end

		// Transfer chunk_buffer
		if (m_axis_tvalid && m_axis_tready) 
		begin
			chunk_full    <= 1'b0;
			m_axis_tvalid <= 1'b0;
			word_cnt      <= {CNT_WIDTH{1'b0}};
		end

		// Error detection
		if (s_axis_tvalid && fifo_full)
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
