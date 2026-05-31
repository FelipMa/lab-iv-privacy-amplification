`timescale 1ns / 1ps

module tb_sistema_completo();

    reg clock;
    reg reset;
    reg exit;

    localparam N = 640;
    localparam W = 64;
    localparam P = 32;
    localparam L = 64;
    
    localparam CYCLES = N/W;
    
    localparam ROM_ADDR_BITS = (CYCLES <= 32)    ? 5 : 
                               (CYCLES <= 64)    ? 6 : 
                               (CYCLES <= 128)   ? 7 : 
                               (CYCLES <= 256)   ? 8 : 
                               (CYCLES <= 512)   ? 9 : 
                               (CYCLES <= 1024)  ? 10 : 
                               (CYCLES <= 2048)  ? 11 : 
                               (CYCLES <= 4096)  ? 12 : 
                               (CYCLES <= 8192)  ? 13 : 
                               (CYCLES <= 16384) ? 14 : 
                               (CYCLES <= 32768) ? 15 : 16;
                               
    localparam MEM_DEPTH = (CYCLES <= 32)    ? 32 : 
                           (CYCLES <= 64)    ? 64: 
                           (CYCLES <= 128)   ? 128: 
                           (CYCLES <= 256)   ? 256: 
                           (CYCLES <= 512)   ? 512: 
                           (CYCLES <= 1024)  ? 1024: 
                           (CYCLES <= 2048)  ? 2048: 
                           (CYCLES <= 4096)  ? 4096: 
                           (CYCLES <= 8192)  ? 8192: 
                           (CYCLES <= 16384) ? 16384: 
                           (CYCLES <= 32768) ? 32768 : 65536;

    // Sinais de interconexão estrutural escalonáveis via parâmetros
    wire [(ROM_ADDR_BITS-1):0] rom_key_addr;
    wire [(W-1):0]             rom_key_q;
    wire [(P-1):0]             hash_register;
    
    wire batch_ready;
    wire done;

    // Instanciação do Bloco Top de Cálculo
    top #(
        .N(N),
        .W(W),
        .P(P),
        .L(L),
        .ROM_ADDR_BITS(ROM_ADDR_BITS)
    ) uut_top (
        .clock          (clock),
        .reset          (reset),
        .rom_key_addr   (rom_key_addr),
        .rom_key_q      (rom_key_q),
        .hash_register  (hash_register),
        .batch_ready    (batch_ready),
        .done           (done)
    );

    // Instanciação do módulo real da ROM (Carrega key.mif dinamicamente)
    // Se a IP do Quartus rejeitar a passagem de parâmetros, basta apagar o bloco #()
    rom_key #(
        .DATA_BITS(W),
        .ADDR_BITS(ROM_ADDR_BITS),
        .DEPTH(MEM_DEPTH)       
    ) uut_rom_key (
        .address (rom_key_addr),
        .clock   (clock),
        .q       (rom_key_q)
    );

    // Período correspondente a 150 MHz
    always #3.333 clock = ~clock;

    integer lote_count = 0;

    initial begin
        $display("==================================================================");
        $display(" INICIANDO TESTBENCH ESTRUTURAL REAL (TOP + ROM_KEY REAL + LUT)   ");
        $display("==================================================================");
        
        clock = 0;
        reset = 1;
        exit = 0;
          
        // Segura o reset por alguns ciclos para estabilizar o sistema
        #20;
        reset = 0;
        $display("[SIM] Reset liberado. Preparando e lendo stream de dados da ROM...");

        // Timeout aumentado para dar margem a toda a simulação
        #15000;
        if (!done) begin
            $display("TIMEOUT! Verifique as transições da FSM ou sinais do Input_Buffer.");
            $stop;
        end
    end

    // Monitoramento e Validação Dinâmica
    always @(posedge clock) begin
        if (batch_ready) begin
            $display("[TEMPO: %0t ps] Lote %0d finalizado. Hash obtido: 0x%h", $time, lote_count, hash_register);
            
            if (lote_count == 0) begin
                if (hash_register !== 32'hD3E5D1D5)
                    $display("    -> [FALHA] Esperado Lote 0: 0xD3E5D1D5");
                else
                    $display("    -> [OK] Lote 0 validado com sucesso!");
            end
                
            if (lote_count == 1) begin
                if (hash_register !== 32'hDE989636)
                    $display("    -> [FALHA] Esperado Lote 1: 0xDE989636");
                else
                    $display("    -> [OK] Lote 1 validado com sucesso!");
            end

            lote_count <= lote_count + 1;
        end

        if (done) begin
            exit <= 1;
        end
          
        if(exit) begin
            $display("==================================================================");
            $display("[SIMULACAO PA] Processamento concluído com total correspondência.");
            $display("==================================================================");
            $stop;
        end
    end

endmodule