module top #(
    parameter W = 2, // 128 ou 64 ou 128
    parameter P = 3, // 782 ou 1563 ou 521
    parameter N = 10, // 1_000_000
    parameter L = 6 // 100_000
)(
    input wire clk_fpga,
    input wire rst_fpga,
    output wire LED_done
);
    wire clock = clk_fpga;
    wire reset = rst_fpga; 

    localparam CYCLES_PER_ROW = N/W;

    // Counter de 16 bits (tem bits de sobra)
    reg [15:0] hash_counter;
    
    // Contador para aguardar o pipeline encher
    reg [1:0] delay_counter;

    // Fios do Input Buffer para a Compression Unit
    wire [W-1:0] current_key_chunk;

    // Registrador que fica mudando a cada clock para simular a saída do input buffer
    reg [W-1:0] current_key_chunk_reg;
    assign current_key_chunk = current_key_chunk_reg;

    // Fios do Seed Generator para a Compression Unit
    wire [(W+P-2):0] current_matrix_window;

    // Registrador que fica mudando a cada clock para simular a saída do seed generator
    reg [(W+P-2):0] current_matrix_window_reg;
    assign current_matrix_window = current_matrix_window_reg;

    // Fios da Compression Unit para o Hash Register
    wire [P-1:0] current_hash_out;

    (* noprune *) reg [P-1:0] hash_register;

    // Sinal de controle para reiniciar a acumulação na Compression Unit
    wire comp_unit_clear_acc;
    assign comp_unit_clear_acc = (hash_counter == 16'd0) ? 1'b1 : 1'b0;

    // =========================================================================
    // Compression Unit
    // =========================================================================
    compression_unit #(
        .P(P),
        .W(W)
    ) u_compression_unit (
        .clock         (clock),
        .reset         (reset),
        .clear_acc     (comp_unit_clear_acc),
        .key           (current_key_chunk),
        .matrix_window (current_matrix_window),
        .hash_out      (current_hash_out)
    );

    always @(posedge clock) begin
        if (reset) begin
            current_key_chunk_reg <= {W{1'b0}};
            current_matrix_window_reg <= {(W+P-1){1'b0}};
            hash_register <= {P{1'b0}};
            hash_counter <= 16'd0;
            delay_counter <= 2'd0;
        end else begin
            
            // Incrementa delay_counter até 3 (é o tempo que leva para o pipeline encher).
            // Enquanto for menor que 3, a lógica do hash_counter não é ativada.
            // (ver vídeo)
            if (delay_counter < 2'd3) begin
                delay_counter <= delay_counter + 2'd1;
            end else begin
                // 1. Controle do contador de hashes
                if (hash_counter == (CYCLES_PER_ROW - 16'd1)) begin
                    hash_counter <= 16'd0;
                end else begin
                    hash_counter <= hash_counter + 16'd1;
                end

                // 2. Gravação do Hash
                if (hash_counter == (CYCLES_PER_ROW - 16'd1)) begin
                    hash_register <= current_hash_out;
                end
            end

            // 3. Atualização aleatória do input buffer e seed generator
            current_key_chunk_reg <= {current_key_chunk_reg[(W-2):0], ~current_key_chunk_reg[W-1]};
            current_matrix_window_reg <= {current_matrix_window_reg[(W+P-3):0], ~current_matrix_window_reg[W+P-2]};
        end
    end

    // Saída dummy
    assign LED_done = hash_register[0];

endmodule