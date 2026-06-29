`timescale 1ns/1ps


module CTR_seed_controller #(
    parameter [31:0] COUNTER_STEP = 32'd1
)(
    input  wire         clock,
    input  wire         reset_n,

    // Comando para carregar/reposicionar o contador.
    input  wire         counter_load_valid,
    input  wire [31:0]  counter_load_value,
    output wire         counter_load_ready,

    // Parametros CTR.
    input  wire [127:0] key,
    input  wire [95:0]  nonce,

    // Saida do gerador.
    output wire [127:0] seed_block,
    output wire         seed_valid,
    output reg  [31:0]  seed_counter,

    // Estado/debug.
    output reg          running,
    output reg  [31:0]  accepted_blocks,
    output reg  [31:0]  generated_blocks,

    // Pulso de debug: contador aceito pelo AES.
    output reg          counter_accepted_valid,
    output reg  [31:0]  counter_accepted,

    // Debug opcional.
    output wire [31:0]  next_counter_debug,
    output wire         aes_input_ready_debug
);

    // Registradores principais

    // Proximo contador a ser apresentado ao AES.
    reg [31:0] counter_reg;

    // Contador atualmente em processamento no AES.
    // Como esta arquitetura de AES aceita apenas um bloco por vez,
    // basta guardar um contador em voo.
    reg [31:0] inflight_counter;

    // Indica que existe um contador valido preparado para o AES.
    reg aes_input_valid_reg;

    // Interface interna com o AES

    wire [31:0]  counter_to_aes;
    wire         aes_input_valid;
    wire [127:0] aes_input_block;
    wire         aes_input_ready;
    wire         aes_accept;

    wire [127:0] aes_output_block;
    wire         aes_output_valid;
    wire         aes_busy;

    // counter_load tem prioridade sobre o contador sequencial.
    assign counter_to_aes = counter_load_valid ? counter_load_value : counter_reg;

    // Se ja havia contador preparado OU se chegou um load agora,
    // ha um bloco valido para o AES.
    assign aes_input_valid = aes_input_valid_reg || counter_load_valid;

    assign aes_input_block = {nonce, counter_to_aes};

    assign aes_accept = aes_input_valid && aes_input_ready;

    // Nesta versao simples, sempre aceitamos um novo load.
    // Se o AES nao puder aceitar agora, o valor carregado fica preparado.
    assign counter_load_ready = 1'b1;

    assign seed_block = aes_output_block;
    assign seed_valid = aes_output_valid;

    assign next_counter_debug = counter_reg;
    assign aes_input_ready_debug = aes_input_ready;

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

    // ============================================================
    // Controle principal


    always @(posedge clock) begin
        if (!reset_n) begin
            counter_reg            <= 32'd0;
            inflight_counter       <= 32'd0;
            aes_input_valid_reg    <= 1'b0;

            seed_counter           <= 32'd0;

            running                <= 1'b0;
            accepted_blocks        <= 32'd0;
            generated_blocks       <= 32'd0;

            counter_accepted_valid <= 1'b0;
            counter_accepted       <= 32'd0;
        end else begin
            counter_accepted_valid <= 1'b0;

            // 
            // Se o AES vai produzir uma seed nesta borda, o contador
            // correspondente ehh o inflight_counter antigo.
            //
            // no mesmo clock, o AES tambem pode aceitar um novo bloco.
            // Por isso seed_counter eh atualizado ANTES, conceitualmente,
            // de inflight_counter passar a representar o novo bloco.
            // Como usamos atribuicoes nao bloqueantes, ambas usam os
            // valores antigos corretamente.
            // 
            if (aes_input_ready && aes_busy) begin
                seed_counter <= inflight_counter;
            end

            if (aes_output_valid) begin
                generated_blocks <= generated_blocks + 32'd1;
            end

            // Load/reposicionamento do contador.
            //
            // Se counter_load_valid=1 e o AES estiver pronto, o AES
            // aceita counter_load_value nesse mesmo clock.
            //
            // Se o AES nao estiver pronto, counter_load_value fica
            // guardado em counter_reg para ser aceito depois.
            if (counter_load_valid) begin
                running             <= 1'b1;
                aes_input_valid_reg <= 1'b1;

                if (aes_accept) begin
                    // AES aceitou exatamente counter_load_value.
                    inflight_counter       <= counter_load_value;
                    counter_reg            <= counter_load_value + COUNTER_STEP;

                    counter_accepted_valid <= 1'b1;
                    counter_accepted       <= counter_load_value;
                    accepted_blocks        <= accepted_blocks + 32'd1;
                end else begin
                    // AES ainda nao aceitou; deixa o valor carregado preparado.
                    counter_reg <= counter_load_value;
                end

            end else if (aes_accept) begin
                // Fluxo normal.
                // aES aceitou counter_reg, entao o proximo contador
                // preparado passa a ser counter_reg + COUNTER_STEP.
                inflight_counter       <= counter_reg;
                counter_reg            <= counter_reg + COUNTER_STEP;
                aes_input_valid_reg    <= 1'b1;

                counter_accepted_valid <= 1'b1;
                counter_accepted       <= counter_reg;
                accepted_blocks        <= accepted_blocks + 32'd1;
            end
        end
    end

endmodule
