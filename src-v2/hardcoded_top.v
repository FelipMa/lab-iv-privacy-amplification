module hardcoded_top #(
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
    wire [N-1:0] HARDCODED_KEY = 128'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF;
    
    // Semente hardcoded de N + L - 1 bits (191 bits)
    wire [(N+L-2):0] HARDCODED_SEED = 191'h7FFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF;

    // =========================================================================
    // Controles de Ciclo e Linhas
    // =========================================================================
    localparam CYCLES_PER_ROW  = N / W; // 128 / 32 = 4 ciclos por linha
    localparam TOTAL_ROW_GRPS  = L / P; // 64 / 32 = 2 grupos de linhas no total
    localparam ADDR_WIDTH      = 1;     // 1 bit de endereço para suportar 2 posições

    reg [1:0] delay_counter;   // Contador de atraso inicial do pipeline
    reg [1:0] hash_counter;    // Contador de ciclos internos da linha (0 a 3)
    reg [ADDR_WIDTH-1:0] row_group_cnt; // Controle do grupo de linhas atual (0 a 1)
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
    // ALTSYNCRAM configurada para In-System Memory Content Editor
    // =========================================================================
    
    // O pulso de escrita (Write Enable) da RAM acontece quando a linha terminou de processar
    wire mem_we = (!done_flag && (delay_counter == 2'd2) && (hash_counter == (CYCLES_PER_ROW - 2'd1)));

    altsyncram #(
        .operation_mode("SINGLE_PORT"),
        .width_a(P),                     // Largura da palavra: 32 bits
        .widthad_a(ADDR_WIDTH),          // Largura do endereço: 1 bit
        .numwords_a(TOTAL_ROW_GRPS),     // Número total de palavras: 2 posições
        .outdata_reg_a("UNREGISTERED"),
        .lpm_type("altsyncram"),
        .lpm_hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=RES") // Habilita e define o nome "RES" no ISMCE
    ) result_ram (
        .clock0 (clock),
        .wren_a (mem_we),
        .address_a (row_group_cnt),      // Endereço (0 ou 1)
        .data_a (current_hash_out),      // Os 32 bits sendo salvos
        .q_a ()                          // Deixamos desconectado (não lemos pela lógica FPGA, apenas via JTAG)
    );

    // =========================================================================
    // Lógica de Controle
    // =========================================================================
    always @(posedge clock) begin
        if (reset) begin
            delay_counter <= 2'd0;
            hash_counter  <= 2'd0;
            row_group_cnt <= 0;
            done_flag     <= 1'b0;
        end else if (!done_flag) begin
            
            // O atraso só acontece uma vez no início das operações
            if (delay_counter < 2'd2) begin
                delay_counter <= delay_counter + 2'd1;
            end else begin
                
                // 1. Controle do contador de hashes e avanço de linhas
                if (hash_counter == (CYCLES_PER_ROW - 2'd1)) begin
                    hash_counter <= 2'd0;
                    
                    // A gravação na altsyncram acontece de forma transparente neste ciclo
                    // governada pelo wire combinacional `mem_we`
                    
                    // Verifica o fim do processamento de todas as linhas
                    if (row_group_cnt == (TOTAL_ROW_GRPS - 1)) begin
                        done_flag <= 1'b1;
                    end else begin
                        row_group_cnt <= row_group_cnt + 1;
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