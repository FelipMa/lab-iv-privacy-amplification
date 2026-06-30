module Input_Buffer #(
    parameter DEPTH        = 32768,
    parameter ADDR_BITS    = 15,
    parameter DATA_BITS    = 32,
    parameter REPEAT_COUNT = 2
)(
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire                  prepare,
    input  wire                  go,

    input  wire [DATA_BITS-1:0]  rom_q,

    output wire [ADDR_BITS-1:0]  rom_addr,
    output wire [ADDR_BITS-1:0]  rom_key_addr,
    output wire                  rom_clock,

    output wire [DATA_BITS-1:0]  out_data,
    output reg                   out_valid,
    output reg                   ready_to_stream,
    output reg                   done
);

localparam [2:0]
    IDLE           = 3'd0,
    WARMUP         = 3'd1,
    CAPTURE_FIRST  = 3'd2,
    WAIT_PREFETCH  = 3'd3,
    STREAM         = 3'd4;

localparam integer TOTAL_WORDS = DEPTH * REPEAT_COUNT;

reg [2:0]            state;
reg [DATA_BITS-1:0] out_reg;

reg [31:0]          sent_count;

reg [ADDR_BITS-1:0] rom_addr_reg;
reg [ADDR_BITS-1:0] next_addr;

wire use_lookahead;
wire [ADDR_BITS-1:0] rom_addr_lookahead;

assign use_lookahead =
    (state == STREAM) &&
    go &&
    (sent_count < TOTAL_WORDS - 2);

assign rom_addr_lookahead =
    use_lookahead ? next_addr : rom_addr_reg;

function [ADDR_BITS-1:0] inc_addr;
    input [ADDR_BITS-1:0] addr;
    begin
        if (addr == DEPTH - 1)
            inc_addr = {ADDR_BITS{1'b0}};
        else
            inc_addr = addr + {{(ADDR_BITS-1){1'b0}}, 1'b1};
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state           <= IDLE;
        rom_addr_reg    <= {ADDR_BITS{1'b0}};
        next_addr       <= {ADDR_BITS{1'b0}};
        sent_count      <= 32'd0;
        out_reg         <= {DATA_BITS{1'b0}};
        out_valid       <= 1'b0;
        ready_to_stream <= 1'b0;
        done            <= 1'b0;
    end else begin
        done            <= 1'b0;
        ready_to_stream <= 1'b0;

        case (state)

            IDLE: begin
                out_valid    <= 1'b0;
                sent_count   <= 32'd0;
                rom_addr_reg <= {ADDR_BITS{1'b0}};
                next_addr    <= {ADDR_BITS{1'b0}};

                if (prepare) begin
                    rom_addr_reg <= {ADDR_BITS{1'b0}};
                    state        <= WARMUP;
                end
            end

            WARMUP: begin
                out_valid <= 1'b0;
                state     <= CAPTURE_FIRST;
            end

            CAPTURE_FIRST: begin
                out_reg   <= rom_q;
                out_valid <= 1'b1;

                sent_count <= 32'd0;

                if (TOTAL_WORDS > 1) begin
                    rom_addr_reg <= {{(ADDR_BITS-1){1'b0}}, 1'b1};

                    if (DEPTH > 2)
                        next_addr <= {{(ADDR_BITS-2){1'b0}}, 2'd2};
                    else
                        next_addr <= inc_addr({{(ADDR_BITS-1){1'b0}}, 1'b1});

                    state <= WAIT_PREFETCH;
                end else begin

                    ready_to_stream <= 1'b1;
                    state           <= STREAM;
                end
            end

            WAIT_PREFETCH: begin
                out_valid       <= 1'b1;
                ready_to_stream <= 1'b1;
                state           <= STREAM;
            end

            STREAM: begin
                out_valid       <= 1'b1;
                ready_to_stream <= 1'b1;

                if (go) begin

                    if (sent_count == TOTAL_WORDS - 1) begin
                        out_valid       <= 1'b0;
                        ready_to_stream <= 1'b0;
                        done            <= 1'b1;
                        state           <= IDLE;
                    end else begin
                        out_reg    <= rom_q;
                        sent_count <= sent_count + 1'b1;

                        if (sent_count < TOTAL_WORDS - 2) begin
                            rom_addr_reg <= next_addr;
                            next_addr    <= inc_addr(next_addr);
                        end
                    end
                end
            end

            default: begin
                state           <= IDLE;
                rom_addr_reg    <= {ADDR_BITS{1'b0}};
                next_addr       <= {ADDR_BITS{1'b0}};
                sent_count      <= 32'd0;
                out_reg         <= {DATA_BITS{1'b0}};
                out_valid       <= 1'b0;
                ready_to_stream <= 1'b0;
                done            <= 1'b0;
            end

        endcase
    end
end

assign rom_clock = clk;
assign out_data  = out_reg;
assign rom_addr = rom_addr_lookahead;
assign rom_key_addr = rom_addr_lookahead;

endmodule