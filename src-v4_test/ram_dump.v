`timescale 1ns / 1ps

module ram_dump #(
    parameter DATA_BITS = 32, 
    parameter ADDR_BITS = 5   
)(
    input wire clock,
    input wire we,                               
    input wire [ADDR_BITS-1:0] address,
    input wire [DATA_BITS-1:0] data_in
);

    // Fio de saída da RAM (exigido pela definição da estrutura)
    wire [DATA_BITS-1:0] ram_output_q;

    // =========================================================================
    // INSTANCIAÇÃO CORRIGIDA DA PRIMITIVA NATIVA: ALTSYNCRAM (SINGLE PORT)
    // =========================================================================
    altsyncram #(
        .operation_mode         ("SINGLE_PORT"),            // Modo RAM de 1 porta
        .intended_device_family ("Cyclone IV E"),
        .width_a                (DATA_BITS),                // Largura alinhada ao tamanho do Hash (P)
        .widthad_a              (ADDR_BITS),                // Quantidade de bits de endereço
        .numwords_a             (2**ADDR_BITS),             // Profundidade da memória
        .outdata_reg_a          ("UNREGISTERED"),           // Sem latência de registrador extra na saída
        .address_aclr_a         ("NONE"),
        .outdata_aclr_a         ("NONE"),
        .lpm_type               ("altsyncram"),
        
        // Ativa o JTAG para leitura em tempo real no In-System Memory Content Editor
        .lpm_hint               ("ENABLE_RUNTIME_MOD=YES, INSTANCE_NAME=hdump")
    ) altsyncram_component (
        // Apenas conexões estritamente necessárias e válidas para o modo SINGLE_PORT
        .clock0         (clock),
        .address_a      (address),
        .data_a         (data_in),
        .wren_a         (we),                               
        .q_a            (ram_output_q)
    );

endmodule