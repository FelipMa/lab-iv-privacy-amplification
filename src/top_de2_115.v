module top_de2_115 (
    input wire clk_fpga,
    input wire rst_fpga,     // Mapeado para SW[0]
    input wire sw_select,    // Mapeado para SW[17]
    output wire LED_done,    // Mapeado para LEDR[0]
    
    // Displays de 7 segmentos (ativos em nível baixo)
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5,
    output wire [6:0] HEX6,
    output wire [6:0] HEX7
);

    parameter W = 64;
    parameter P = 64;

    // Sinais para controle da gravacao na RAM
    reg [3:0] ram_address;
    reg ram_write_enable;
    wire [63:0] ram_data_in;
    wire [63:0] ram_data_out;

    // Fios da Compression Unit
    reg [W-1:0] key_reg;
    reg [W+P-2:0] matrix_reg;
    wire [P-1:0] current_hash_out;
    reg [P-1:0] hash_register;

    // Instanciacao da Compression Unit do SRC normal
    compression_unit #(
        .P(P),
        .W(W)
    ) u_compression_unit (
        .clock         (clk_fpga),
        .reset         (rst_fpga), 
        .key           (key_reg),
        .matrix_window (matrix_reg),
        .hash_out      (current_hash_out)
    );

    // Entradas dinamicas controladas por shift register para gerar hashes diferentes
    always @(posedge clk_fpga) begin
        if (rst_fpga) begin
            key_reg <= 64'h3A7D9E4B2F5C8A10;
            matrix_reg <= 127'h5E8A9B1C3D2E4F0A7B6C5D4E3F2A1B0C;
            hash_register <= {P{1'b0}};
            ram_address <= 4'd0;
            ram_write_enable <= 1'b1;
        end else begin
            if (ram_write_enable) begin
                // Gera chaves/matrizes dinamicas variando o padrao a cada ciclo
                key_reg <= {key_reg[W-2:0], ~key_reg[W-1]};
                matrix_reg <= {matrix_reg[W+P-3:0], ~matrix_reg[W+P-2]};
                
                // Salva o hash atualizado do ciclo anterior
                hash_register <= current_hash_out;
                
                // Incrementa o endereco da memoria
                if (ram_address == 4'd15) begin
                    ram_write_enable <= 1'b0; // Para de gravar ao encher a RAM (16 elementos)
                end else begin
                    ram_address <= ram_address + 4'd1;
                end
            end
        end
    end

    // Os dados a serem gravados na RAM sao o hash calculado
    assign ram_data_in = current_hash_out;
    assign LED_done = ~ram_write_enable; // Acende o LED quando a RAM estiver cheia

    // Instanciacao da RAM com suporte ao In-System Memory Content Editor
    altsyncram #(
        .operation_mode("SINGLE_PORT"),
        .width_a(64),
        .widthad_a(4),
        .numwords_a(16),
        .outdata_reg_a("UNREGISTERED"),
        .lpm_hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=HASH"),
        .lpm_type("altsyncram")
    ) u_ram (
        .clock0    (clk_fpga),
        .address_a (ram_address),
        .wren_a    (ram_write_enable && !rst_fpga),
        .data_a    (ram_data_in),
        .q_a       (ram_data_out)
    );

    // Selecao de exibicao nos displays de 7 segmentos (mostra o ultimo hash gravado na RAM)
    wire [31:0] display_value;
    assign display_value = sw_select ? hash_register[63:32] : hash_register[31:0];

    // Conexao dos decodificadores para cada display de 7 segmentos
    hex_to_7seg dec0 (.hex(display_value[3:0]),   .seg(HEX0));
    hex_to_7seg dec1 (.hex(display_value[7:4]),   .seg(HEX1));
    hex_to_7seg dec2 (.hex(display_value[11:8]),  .seg(HEX2));
    hex_to_7seg dec3 (.hex(display_value[15:12]), .seg(HEX3));
    hex_to_7seg dec4 (.hex(display_value[19:16]), .seg(HEX4));
    hex_to_7seg dec5 (.hex(display_value[23:20]), .seg(HEX5));
    hex_to_7seg dec6 (.hex(display_value[27:24]), .seg(HEX6));
    hex_to_7seg dec7 (.hex(display_value[31:28]), .seg(HEX7));

endmodule

// Decodificador Hexadecimal para 7 Segmentos (Ativo em Nivel Baixo)
module hex_to_7seg (
    input wire [3:0] hex,
    output reg [6:0] seg
);
    always @(*) begin
        case (hex)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
            default: seg = 7'b1111111;
        endcase
    end
endmodule
