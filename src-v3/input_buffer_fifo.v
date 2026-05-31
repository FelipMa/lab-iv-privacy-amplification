module input_buffer_fifo #(
    parameter IN_WIDTH  = 64,
    parameter BUF_DEPTH = 4,
    parameter OUT_WIDTH = 8
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [IN_WIDTH-1:0]  push_data,
    input  wire                 wr_en,
    input  wire                 rd_en,
    output reg  [OUT_WIDTH-1:0] data_out,
    output reg                  data_valid,
    output wire                 full,
    output wire                 empty
);

    // Cálculo do tamanho do ponteiro (Log2 manual)
    localparam ADDR_W = (BUF_DEPTH <= 2)     ? 1 : 
                        (BUF_DEPTH <= 4)     ? 2 : 
                        (BUF_DEPTH <= 8)     ? 3 : 
                        (BUF_DEPTH <= 16)    ? 4 : 
                        (BUF_DEPTH <= 32)    ? 5 : 
                        (BUF_DEPTH <= 64)    ? 6 : 
                        (BUF_DEPTH <= 128)   ? 7 : 
                        (BUF_DEPTH <= 256)   ? 8 : 
                        (BUF_DEPTH <= 512)   ? 9 : 
                        (BUF_DEPTH <= 1024)  ? 10 : 
                        (BUF_DEPTH <= 2048)  ? 11 : 
                        (BUF_DEPTH <= 4096)  ? 12 : 
                        (BUF_DEPTH <= 8192)  ? 13 : 
                        (BUF_DEPTH <= 16384) ? 14 : 
                        (BUF_DEPTH <= 32768) ? 15 : 16;

    reg [IN_WIDTH-1:0] mem [0:BUF_DEPTH-1];
    reg [ADDR_W:0] wr_ptr, rd_ptr;

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]) && 
                   (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]);

    // Escrita na Fila
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_W-1:0]] <= push_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // Leitura e Validação do Dado
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
            data_out <= 0;
            data_valid <= 0;
        end else if (rd_en && !empty) begin
            data_out <= mem[rd_ptr[ADDR_W-1:0]][OUT_WIDTH-1:0];
            data_valid <= 1'b1;
            rd_ptr <= rd_ptr + 1'b1;
        end else begin
            data_valid <= 1'b0;
        end
    end
endmodule