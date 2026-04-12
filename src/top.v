module top #(
    parameter W = 64, 
    parameter P = 1600
)(
    input wire clk_fpga, // clock do fpga
    input wire rst_fpga, // algum botao do fpga
    output wire LED_done // LED para indicar finalizacao
);
    wire clock = clk_fpga;
    wire reset = rst_fpga; 
    
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

    // Fios da Compression Unit para a Output Interface
    wire [P-1:0] current_hash_out;
    (* noprune *) reg [P-1:0] dummy_out_reg;

    // =========================================================================
    // Compression Unit
    // =========================================================================
    compression_unit #(
        .P(P),
        .W(W)
    ) u_compression_unit (
        .clock         (clock),
        .reset         (reset),
        .key           (current_key_chunk),
        .matrix_window (current_matrix_window),
        .hash_out      (current_hash_out)
    );

    always @(posedge clock) begin
        if (reset) begin
            current_key_chunk_reg <= {W{1'b0}};
            current_matrix_window_reg <= {(W+P-1){1'b0}};
            dummy_out_reg <= {P{1'b0}};
        end else begin
            // current_key_chunk_reg e current_matrix_window_reg devem receber o valor do input buffer e do seed generator
			// aqui no exemplo ficam mudando aleatoriamente usando um shift register
            current_key_chunk_reg <= {current_key_chunk_reg[(W-2):0], ~current_key_chunk_reg[W-1]};
            current_matrix_window_reg <= {current_matrix_window_reg[(W+P-3):0], ~current_matrix_window_reg[W+P-2]};
            
            // grava a saida no registrador final
            dummy_out_reg <= current_hash_out;
        end
    end

    // Dummy temporario apenas para os sinais nao serem deletados no Quartus pelo otimizador.
    assign LED_done = dummy_out_reg[0];

endmodule