// Top sintetizavel da branch test/v1-altsyncram-validation.
//
// Adapta o top original (que mockava o Input Buffer e o Seed Generator via
// shift-registers) para usar IPs altsyncram do Quartus:
//   - input_rom alimenta o DUT com pares {matrix_window, key} pre-carregados
//     a partir de input_vectors.mif.
//   - output_ram captura hash_out (acessivel pelo Quartus In-System Memory
//     Content Editor com instance name "ORAM").
//
// Pinout DE2-115:
//   clk_fpga  <- CLOCK_50 (50 MHz)
//   rst_fpga  <- KEY[0]   (botao ativo em baixo: pressionar = reset)
//   LED_done  -> LEDR[0]
//
// Apos rst_fpga liberar, o circuito processa os 16 vetores em 18 ciclos.
// Quando LED_done acende, a output_ram contem os resultados e pode ser
// lida via JTAG no In-System Memory Content Editor.

module top (
    input  wire clk_fpga,
    input  wire rst_fpga,
    output wire LED_done
);

    localparam W = 8;
    localparam P = 8;
    localparam MW_BITS = W + P - 1;
    localparam WORD_BITS = W + MW_BITS;
    localparam DEPTH = 16;
    localparam LATENCY = 2;

    wire clock = clk_fpga;
    wire reset = ~rst_fpga; // KEY[0] e ativo em baixo na DE2-115

    reg [5:0] cycle_counter;
    reg done;

    wire rd_in_progress = (cycle_counter < DEPTH);
    wire wr_in_progress = (cycle_counter >= LATENCY) && (cycle_counter < DEPTH + LATENCY);

    wire [3:0] rd_addr = rd_in_progress ? cycle_counter[3:0] : 4'd0;
    wire [3:0] wr_addr = wr_in_progress ? (cycle_counter[3:0] - LATENCY[3:0]) : 4'd0;
    wire       wren    = wr_in_progress;

    wire [WORD_BITS-1:0] rom_q;
    wire [W-1:0]         key           = rom_q[W-1:0];
    wire [MW_BITS-1:0]   matrix_window = rom_q[WORD_BITS-1:W];

    input_rom u_rom (
        .clock   (clock),
        .address (rd_addr),
        .q       (rom_q)
    );

    wire [P-1:0] hash_out;

    compression_unit #(
        .P(P),
        .W(W)
    ) u_dut (
        .clock         (clock),
        .reset         (reset),
        .key           (key),
        .matrix_window (matrix_window),
        .hash_out      (hash_out)
    );

    output_ram u_ram (
        .clock   (clock),
        .address (wr_addr),
        .data    (hash_out),
        .wren    (wren),
        .q       ()
    );

    always @(posedge clock) begin
        if (reset) begin
            cycle_counter <= 6'd0;
            done          <= 1'b0;
        end else if (!done) begin
            if (cycle_counter == DEPTH + LATENCY - 1) done <= 1'b1;
            cycle_counter <= cycle_counter + 6'd1;
        end
    end

    assign LED_done = done;

endmodule
