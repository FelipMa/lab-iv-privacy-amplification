`timescale 1ns/1ps

module top_tb;

    // =========================================================================
    // Parâmetros do Sistema
    // =========================================================================
    parameter N = 128;
    parameter W = 32;
    parameter P = 32;
    parameter L = 64;

    localparam CYCLES_PER_BATCH = (N + W - 1) / W;
    localparam BATCHES = (L + P - 1) / P;

    // =========================================================================
    // Sinais do DUT
    // =========================================================================
    reg clock;
    reg reset;
    
    wire done;

    // =========================================================================
    // Instanciação do DUT
    // =========================================================================
    top #(
        .N(N),
        .W(W),
        .P(P),
        .L(L)
    ) dut (
        .clock(clock),
        .reset(reset),
        .done(done)
    );

    // =========================================================================
    // Geração de Clock (100 MHz -> Período de 10ns)
    // =========================================================================
    initial begin
        clock = 0;
        forever #5 clock = ~clock; 
    end

    // =========================================================================
    // Memória Simulada para Captura do Hardware
    // =========================================================================
    reg [(P-1):0] ram_simulada [0:(BATCHES-1)];
    integer write_addr = 0;

    // Acessando os sinais 'batch_ready' e 'hash_register' pela hierarquia interna do dut
    always @(posedge clock) begin
        if (dut.batch_ready) begin
            ram_simulada[write_addr] = dut.hash_register;
            write_addr = write_addr + 1;
        end
    end

    // =========================================================================
    // Informações Base (Software/Referência)
    // =========================================================================
    // Hardcoded Inputs - Iguais aos arquivos MIF / LUT
    reg [N-1:0] SW_KEY = 128'h7F4D92B1C0E8A3549B62F10D85A7C3E9;
    reg [(N+L-2):0] SW_SEED = 191'h6A2F8B10C5D4E92A3B84F716D09E5C3B2A1F8D4E76B093C1;
    
    // Array para guardar os hashes gerados pelo SW
    reg [(P-1):0] sw_hashes [0:(BATCHES-1)];

    // =========================================================================
    // Task para cálculo de popcount (contagem de '1's) e paridade (XOR)
    // =========================================================================
    function automatic reg calc_parity;
        input [W-1:0] data;
        integer k;
        reg p_val;
        begin
            p_val = 1'b0;
            for (k = 0; k < W; k = k + 1) begin
                p_val = p_val ^ data[k];
            end
            calc_parity = p_val;
        end
    endfunction

    // =========================================================================
    // Task: Calcula Gabarito do Hash em Software
    // =========================================================================
    task calculate_software_hash;
        integer batch_idx, word_idx, bit_idx;
        reg [W-1:0] current_key_word;
        reg [W+P-2:0] current_seed_window;
        reg [W-1:0] window_shifted;
        reg [W-1:0] and_result;
        reg parity;
        reg [(P-1):0] calculated_hash;
        reg [7:0] seed_offset;
        
        begin
            for (batch_idx = 0; batch_idx < BATCHES; batch_idx = batch_idx + 1) begin
                calculated_hash = {P{1'b0}};
                
                for (bit_idx = 0; bit_idx < P; bit_idx = bit_idx + 1) begin
                    parity = 1'b0; 
                    
                    for (word_idx = 0; word_idx < CYCLES_PER_BATCH; word_idx = word_idx + 1) begin
                        current_key_word = SW_KEY[(word_idx * W) +: W];
                        seed_offset = (batch_idx * P) + (word_idx * W);
                        current_seed_window = SW_SEED[seed_offset +: (W+P-1)];
                        window_shifted = current_seed_window[bit_idx +: W];
                        and_result = current_key_word & window_shifted;
                        parity = parity ^ calc_parity(and_result);
                    end
                    calculated_hash[bit_idx] = parity;
                end
                sw_hashes[batch_idx] = calculated_hash;
            end
        end
    endtask

    // =========================================================================
    // Estímulos, Impressão e Validação Final
    // =========================================================================
    integer i;
    reg all_pass;

    initial begin
        $display("---------------------------------------------------");
        $display("[SIM] Iniciando Simulacao do Top Module (100 MHz)");
        $display("---------------------------------------------------");
        
        reset = 1;
        #30;
        reset = 0;

        wait(done == 1'b1);
        #20;

        $display("===================================================");
        $display("               DUMP DA RAM (HARDWARE)              ");
        $display("===================================================");
        for (i = 0; i < write_addr; i = i + 1) begin
            $display("Endereco [%0d] : %h", i, ram_simulada[i]);
        end
        
        calculate_software_hash();

        $display("===================================================");
        $display("              VALIDACAO DE RESULTADOS              ");
        $display("===================================================");
        all_pass = 1'b1;

        for (i = 0; i < BATCHES; i = i + 1) begin
            if (ram_simulada[i] === sw_hashes[i]) begin
                $display("[PASSOU] Batch %0d - LIDO: %h == ESPERADO: %h", i, ram_simulada[i], sw_hashes[i]);
            end else begin
                $display("[FALHOU] Batch %0d - LIDO: %h != ESPERADO: %h", i, ram_simulada[i], sw_hashes[i]);
                all_pass = 1'b0;
            end
        end

        $display("---------------------------------------------------");
        if (all_pass) begin
            $display("STATUS FINAL: SUCESSO ABSOLUTO!");
        end else begin
            $display("STATUS FINAL: ENCONTRADOS ERROS DE VALIDACAO!");
        end
        $display("---------------------------------------------------");
        
        $stop;
    end

endmodule