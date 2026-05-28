module hardcoded_top_v0 #(
    parameter W = 32,
    parameter P = 32,
    parameter N = 128,
    parameter L = 64
)(
    input wire clk_fpga,
    input wire rst_fpga,
    output wire LED_done
);

    wire clock = clk_fpga;
    wire reset = rst_fpga; 

    // =========================================================================
    // Hardcoded Inputs (Simulando memórias/módulos externos)
    // =========================================================================
    
    // Chave hardcoded de N bits (128 bits todos em 1)
    wire [N-1:0] HARDCODED_KEY = 128'h7F4D92B1C0E8A3549B62F10D85A7C3E9;
    
    // Semente hardcoded de N + L - 1 bits (191 bits)
    wire [(N+L-2):0] HARDCODED_SEED = 191'h6A2F8B10C5D4E92A3B84F716D09E5C3B2A1F8D4E76B093C1;

    // =========================================================================
    // Registrador de Resultado Final
    // =========================================================================
    // Registrador de tamanho L simulando a memória externa
    reg [L-1:0] final_result;

    // =========================================================================
    // Controles de Ciclo e Linhas
    // =========================================================================
    localparam CYCLES_PER_ROW  = N / W; // 128 / 32 = 4 ciclos por linha
    localparam TOTAL_ROW_GRPS  = L / P; // 64 / 32 = 2 grupos de linhas no total

    reg [1:0] delay_counter;   // Contador de atraso inicial do pipeline
    reg [1:0] hash_counter;    // Contador de ciclos internos da linha (0 a 3)
    reg       row_group_cnt;   // Controle do grupo de linhas atual (0 a 1)
    reg       done_flag;

    // =========================================================================
    // Fios da Compression Unit
    // =========================================================================
    wire [W-1:0] current_key_chunk;
    wire [(W+P-2):0] current_matrix_window;
    wire [P-1:0] current_hash_out;
    wire comp_unit_clear_acc;

    // Consulta à chave hardcoded usando offset contínuo
    assign current_key_chunk = HARDCODED_KEY[hash_counter * W +: W];

    // Consulta à semente hardcoded usando offset dinâmico baseado na linha atual
    wire [7:0] seed_offset = (row_group_cnt * P) + (hash_counter * W);
    assign current_matrix_window = HARDCODED_SEED[seed_offset +: (W+P-1)];

    // Sinal de controle para reiniciar a acumulação no início de cada linha
    assign comp_unit_clear_acc = (hash_counter == 2'd0) ? 1'b1 : 1'b0;

    // =========================================================================
    // Instância da Compression Unit
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

    // =========================================================================
    // Lógica de Controle e Gravação Contínua
    // =========================================================================
    always @(posedge clock) begin
        if (reset) begin
            delay_counter <= 2'd0;
            hash_counter  <= 2'd0;
            row_group_cnt <= 1'b0;
            final_result  <= {L{1'b0}};
            done_flag     <= 1'b0;
        end else if (!done_flag) begin
            
            // O atraso só acontece uma vez no início das operações
            if (delay_counter < 2'd2) begin
                delay_counter <= delay_counter + 2'd1;
            end else begin
                
                // 1. Controle do contador de hashes e avanço de linhas
                if (hash_counter == (CYCLES_PER_ROW - 2'd1)) begin
                    hash_counter <= 2'd0;
                    
                    // 2. Gravação do Hash pronto na posição correta da "memória"
                    final_result[row_group_cnt * P +: P] <= current_hash_out;
                    
                    // Verifica o fim do processamento de todas as linhas
                    if (row_group_cnt == (TOTAL_ROW_GRPS - 1)) begin
                        done_flag <= 1'b1;
                    end else begin
                        row_group_cnt <= row_group_cnt + 1'b1;
                    end
                end else begin
                    hash_counter <= hash_counter + 2'd1;
                end
                
            end
        end
    end

    // Sinalização de término para a FPGA
    assign LED_done = done_flag;

endmodule