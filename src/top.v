module top #(
    parameter W = 128, // 128
    parameter P = 782, // 782
    parameter N = 1_000_000
)(
    input wire clk_fpga,
    input wire rst_fpga,
    output wire LED_done
);

    wire clock = clk_fpga;
    wire reset = rst_fpga; 

    localparam CYCLES_PER_ROW = N/W;

    // 16 bits, mas pode variar conforme o resultado de N/W
    reg [15:0] cycle_counter;

    // Fios do Input Buffer para a Compression Unit
    wire [W-1:0] current_key_chunk;
    // Registrador que fica mudando a cada clock para simular um input
    reg [W-1:0] current_key_chunk_reg;
    assign current_key_chunk = current_key_chunk_reg;

    // Fios do Seed Generator para a Compression Unit
    wire [(W+P-2):0] current_matrix_window;
    // Registrador que fica mudando a cada clock para simular uma seed
    reg [(W+P-2):0] current_matrix_window_reg;
    assign current_matrix_window = current_matrix_window_reg;

    // Fios da Compression Unit para o Hash Register
    wire [P-1:0] current_hash_out;
    (* noprune *) reg [P-1:0] hash_register;

    // Sinal de controle para reiniciar a Compression Unit
    // IMPORTANTE: Modificado para o ciclo 2 devido aos 2 atrasos de clock do novo Pipeline
    wire comp_unit_clear;
    assign comp_unit_clear = (cycle_counter == 16'd2) ? 1'b1 : 1'b0;

    // =========================================================================
    // Compression Unit
    // =========================================================================
    compression_unit #(
        .P(P),
        .W(W)
    ) u_compression_unit (
        .clock         (clock),
        .reset         (reset | comp_unit_clear), 
        .key           (current_key_chunk),
        .matrix_window (current_matrix_window),
        .hash_out      (current_hash_out)
    );

    always @(posedge clock) begin
        if (reset) begin
            current_key_chunk_reg <= {W{1'b0}};
            current_matrix_window_reg <= {(W+P-1){1'b0}};
            hash_register <= {P{1'b0}};
            cycle_counter <= 16'd0;
        end else begin
            // Controle do Contador
            if (cycle_counter == (CYCLES_PER_ROW - 16'd1)) begin
                cycle_counter <= 16'd0;
            end else begin
                cycle_counter <= cycle_counter + 16'd1;
            end

            // Gravação do Hash
            // Capturamos no ciclo 2, que é o momento exato em que o dado pipelizado da linha anterior sai da Compression Unit.
            if (cycle_counter == 16'd2) begin
                hash_register <= current_hash_out;
            end

            // Atualização das Entradas (Simulação via shift register)
            current_key_chunk_reg <= {current_key_chunk_reg[(W-2):0], ~current_key_chunk_reg[W-1]};
            current_matrix_window_reg <= {current_matrix_window_reg[(W+P-3):0], ~current_matrix_window_reg[W+P-2]};
        end
    end

    // Dummy temporario
    assign LED_done = hash_register[0];

endmodule