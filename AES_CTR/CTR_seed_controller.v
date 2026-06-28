`timescale 1ns/1ps

// Controlador CTR para usar AES_K(nonce || counter) como gerador de blocos/seed.
//
// Este módulo NÃO faz XOR com plaintext.
// Ele apenas gera:
//      seed_block = AES_K({nonce, counter})
//
// O módulo AES instanciado deve ter a interface ready/valid:
//
// module AES (
//     input  wire         clock,
//     input  wire         reset_n,
//     input  wire         input_valid,
//     input  wire [127:0] input_block,
//     output wire         input_ready,
//     input  wire [127:0] key,
//     output reg  [127:0] output_block,
//     output reg          output_valid,
//     output reg          busy
// );

module CTR_seed_controller (
    input  wire         clock,
    input  wire         reset_n,

    // Pulso de 1 ciclo para iniciar a geração contínua.
    input  wire         start,

    // Parâmetros do fluxo CTR.
    input  wire [127:0] key,
    input  wire [95:0]  nonce,
    input  wire [31:0]  initial_counter,

    // Saída do gerador:
    // seed_valid fica 1 por um ciclo quando seed_block é válido.
    output wire [127:0] seed_block,
    output wire         seed_valid,

    // Contador associado ao seed_block atual.
    // Válido quando seed_valid = 1.
    output reg  [31:0]  seed_counter,

    // Estado/debug.
    output reg          running,
    output reg  [31:0]  accepted_blocks,
    output reg  [31:0]  generated_blocks,

    // Pulsos de debug úteis para testbench/medição de tempo.
    // counter_accepted_valid indica que o AES aceitou um novo bloco
    // {nonce, counter_accepted} naquela borda.
    output reg          counter_accepted_valid,
    output reg  [31:0]  counter_accepted
);

    reg         aes_input_valid;
    reg [127:0] aes_input_block;
    wire        aes_input_ready;

    wire [127:0] aes_output_block;
    wire         aes_output_valid;
    wire         aes_busy;

    reg [31:0] next_counter_to_feed;
    reg [31:0] next_counter_to_output;

    assign seed_block = aes_output_block;
    assign seed_valid = aes_output_valid;

    AES u_aes (
        .clock        (clock),
        .reset_n      (reset_n),

        .input_valid  (aes_input_valid),
        .input_block  (aes_input_block),
        .input_ready  (aes_input_ready),

        .key          (key),

        .output_block (aes_output_block),
        .output_valid (aes_output_valid),
        .busy         (aes_busy)
    );

    always @(posedge clock) begin
        if (!reset_n) begin
            running                <= 1'b0;

            aes_input_valid        <= 1'b0;
            aes_input_block        <= 128'd0;

            next_counter_to_feed   <= 32'd0;
            next_counter_to_output <= 32'd0;

            seed_counter           <= 32'd0;

            accepted_blocks        <= 32'd0;
            generated_blocks       <= 32'd0;

            counter_accepted_valid <= 1'b0;
            counter_accepted       <= 32'd0;
        end else begin
            counter_accepted_valid <= 1'b0;

            if (start && !running) begin
                // Carrega o primeiro bloco contador.
                // O AES aceitará esse bloco na próxima borda em que input_ready=1.
                running                <= 1'b1;

                aes_input_valid        <= 1'b1;
                aes_input_block        <= {nonce, initial_counter};

                next_counter_to_feed   <= initial_counter + 32'd1;
                next_counter_to_output <= initial_counter;

                accepted_blocks        <= 32'd0;
                generated_blocks       <= 32'd0;
            end else if (running) begin
                // Quando o AES aceita o bloco atual, já deixamos preparado
                // o próximo contador para a próxima oportunidade.
                if (aes_input_valid && aes_input_ready) begin
                    counter_accepted_valid <= 1'b1;
                    counter_accepted       <= aes_input_block[31:0];

                    accepted_blocks        <= accepted_blocks + 32'd1;

                    aes_input_block        <= {nonce, next_counter_to_feed};
                    next_counter_to_feed   <= next_counter_to_feed + 32'd1;

                    // Mantém o gerador alimentando o AES continuamente.
                    aes_input_valid        <= 1'b1;
                end
            end

            // Quando o AES entrega um bloco, associamos o resultado
            // ao contador que foi aceito 20 ciclos antes.
            if (aes_output_valid) begin
                seed_counter           <= next_counter_to_output;
                next_counter_to_output <= next_counter_to_output + 32'd1;
                generated_blocks       <= generated_blocks + 32'd1;
            end
        end
    end

endmodule
