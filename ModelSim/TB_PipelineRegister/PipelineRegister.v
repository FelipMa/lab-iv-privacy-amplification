//===================================================================================
// File: PipelineRegister.v
//===================================================================================

module PipelineRegister (m_axis_tdata, m_axis_tvalid, s_axis_tready,
												 s_axis_tdata, s_axis_tvalid, m_axis_tready,
												 clock, reset);
												 
parameter WIDTH = 512;

// Control
input  wire clock;
input  wire reset;

// AXI4-Stream Slave (input)
input  wire [WIDTH-1:0] s_axis_tdata;
input  wire             s_axis_tvalid;
output wire             s_axis_tready;

// AXI4-Stream Master (output)
output reg  [WIDTH-1:0] m_axis_tdata;
output reg              m_axis_tvalid;
input  wire             m_axis_tready;

reg [WIDTH-1:0] data_reg;
reg             valid_reg;

assign s_axis_tready = !valid_reg;

always @(posedge clock) 
begin
	if (reset) 
	begin
		data_reg   <= {WIDTH{1'b0}};
		valid_reg  <= 1'b0;
		m_axis_tdata <= {WIDTH{1'b0}};
    m_axis_tvalid <= 1'b0;
	end 
	else 
	begin
		if (s_axis_tvalid && s_axis_tready) 
		begin
			data_reg  <= s_axis_tdata;
			valid_reg <= 1'b1;
		end
		if (valid_reg && m_axis_tready) 
		begin
			m_axis_tdata  <= data_reg;
			m_axis_tvalid <= 1'b1;
			valid_reg     <= 1'b0;
		end 
		else 
		begin
			m_axis_tvalid <= 1'b0;
		end
	end
end

endmodule

