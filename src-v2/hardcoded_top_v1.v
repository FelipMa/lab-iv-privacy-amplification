module hardcoded_top_v1 #(
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
    // Controles de Ciclo e Linhas
    // =========================================================================
    localparam CYCLES_PER_ROW  = N / W;
    localparam TOTAL_ROW_GRPS  = L / P;
    localparam ADDR_WIDTH      = 1;

    reg [1:0] delay_counter;
    reg [1:0] hash_counter;
    reg [ADDR_WIDTH-1:0] row_group_cnt;
    reg       done_flag;

    reg [1:0] capture_shift_reg;            // Atrasa o comando de escrita na RAM (wren) em 2 ciclos
    reg [ADDR_WIDTH-1:0] row_group_delay_1; // Estágio 1 do atraso de endereço
    reg [ADDR_WIDTH-1:0] row_group_delay_2; // Estágio 2 do atraso de endereço (vai para a RAM)
    reg input_done;                         // Flag para avisar que a entrada encerrou

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
    altsyncram #(
        .operation_mode("SINGLE_PORT"),
        .width_a(P),                     // Largura da palavra: 32 bits
        .widthad_a(ADDR_WIDTH),          // Largura do endereço: 1 bit
        .numwords_a(TOTAL_ROW_GRPS),     // Número total de palavras: 2 posições
        .outdata_reg_a("UNREGISTERED"),
        .lpm_type("altsyncram"),
        .lpm_hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=RES") 
    ) result_ram (
        .clock0 (clock),
        .wren_a (capture_shift_reg[1]),  // Usando o shift register de controle (2 ciclos atrasado)
        .address_a (row_group_delay_2),  // Usando o endereço que acompanhou o pipeline
        .data_a (current_hash_out),
        .q_a ()
    );

    // =========================================================================
    // Lógica de Controle (Pipelined para ALTSYNCRAM)
    // =========================================================================
    always @(posedge clock) begin
        if (reset) begin
            delay_counter <= 2'd0;
            hash_counter  <= 2'd0;
            row_group_cnt <= 0;
            done_flag     <= 1'b0;
            capture_shift_reg <= 2'b00;
            row_group_delay_1 <= 0;
            row_group_delay_2 <= 0;
            input_done        <= 1'b0;
        end else if (!done_flag) begin
            // =============================================================
            // ESTÁGIO 2 (SAÍDA): Validação da gravação na memória
            // =============================================================
            // A gravação real na altsyncram ocorre de forma transparente porque 
            // capture_shift_reg[1] e row_group_delay_2 estão conectados fisicamente 
            // nas portas da RAM. Aqui só verificamos se foi a última operação.
            
            if (capture_shift_reg[1]) begin
                if (row_group_delay_2 == (TOTAL_ROW_GRPS - 1)) begin
                    done_flag <= 1'b1;
                end
            end

            // =============================================================
            // ESTÁGIO 1 (ENTRADA): Alimentação do Pipeline
            // =============================================================
            if (!input_done) begin
                // Alimenta os registradores de atraso
                capture_shift_reg <= {capture_shift_reg[0], (hash_counter == (CYCLES_PER_ROW - 2'd1))};
                row_group_delay_1 <= row_group_cnt;
                row_group_delay_2 <= row_group_delay_1;

                // Avanço dos contadores
                if (hash_counter == (CYCLES_PER_ROW - 2'd1)) begin
                    if (row_group_cnt == (TOTAL_ROW_GRPS - 1)) begin
                        // Para de enviar dados, mas mantém o clock rodando para esvaziar o pipeline
                        input_done <= 1'b1; 
                    end else begin
                        hash_counter <= 2'd0;
                        row_group_cnt <= row_group_cnt + 1;
                    end
                end else begin
                    hash_counter <= hash_counter + 2'd1;
                end
            end else begin
                // Pipeline esvaziando: insere zeros no controle para não gravar lixo na RAM
                capture_shift_reg <= {capture_shift_reg[0], 1'b0};
                row_group_delay_1 <= 0;
                row_group_delay_2 <= row_group_delay_1;
            end
        end
    end

    // Sinalização de término para a FPGA
    assign LED_done = done_flag;

endmodule