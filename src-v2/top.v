module top #(
    parameter W = 64, 
    parameter P = 32, 
    parameter N = 640,
    parameter L = 64
)(
    input  wire clock,
    input  wire reset,
    
    // Entradas vindas das memórias ROM
    input  wire [W-1:0]   rom_key_q,
    input  wire [W+P-2:0] rom_matrix_q,
    
    // Saídas para controlar as memórias ROM
    output reg  [4:0]     rom_key_addr,
    output reg  [4:0]     rom_matrix_addr,
    
    // Saídas de Resultados
    output reg  [P-1:0]   hash_register,
    output reg            done
);

    localparam CYCLES_PER_BATCH = N / W;
    localparam TOTAL_BATCHES = L / P;

    wire [P-1:0] current_hash_out;
    reg comp_unit_clear_acc;

    compression_unit #(
        .P(P), .W(W)
    ) u_compression_unit (
        .clock         (clock),
        .reset         (reset),
        .clear_acc     (comp_unit_clear_acc),
        .key           (rom_key_q),
        .matrix_window (rom_matrix_q),
        .hash_out      (current_hash_out)
    );

    reg [2:0] state;
    reg [15:0] cycle_count;
    reg [15:0] batch_count;
    
    localparam S_INIT=0, S_CALC=1, S_WAIT_PIPE_1=2, S_WAIT_PIPE_2=3, S_SAVE=4, S_DONE=5;

    always @(posedge clock) begin
        if (reset) begin
            state <= S_INIT;
            rom_key_addr <= 0;
            rom_matrix_addr <= 0;
            comp_unit_clear_acc <= 1;
            hash_register <= 0;
            done <= 0;
            cycle_count <= 0;
            batch_count <= 0;
        end else begin
            comp_unit_clear_acc <= 0;

            case (state)
                S_INIT: begin
                    comp_unit_clear_acc <= 1; // Zera o acumulador
                    rom_key_addr <= 0; // Reinicia a leitura da chave
                    cycle_count <= 0;
                    state <= S_CALC;
                end

                S_CALC: begin
                    // Avança endereços para o próximo ciclo
                    rom_key_addr <= rom_key_addr + 1;
                    rom_matrix_addr <= rom_matrix_addr + 1;
                    
                    if (cycle_count == CYCLES_PER_BATCH - 1) begin
                        state <= S_WAIT_PIPE_1; // Acabou de ler o lote
                    end else begin
                        cycle_count <= cycle_count + 1;
                    end
                end

                // O pipeline do hash_engine tem 2 estágios
                S_WAIT_PIPE_1: state <= S_WAIT_PIPE_2;
                S_WAIT_PIPE_2: state <= S_SAVE;

                S_SAVE: begin
                    hash_register <= current_hash_out; // Aqui você pegaria isso para salvar numa RAM de saída real
                    
                    if (batch_count == TOTAL_BATCHES - 1) begin
                        state <= S_DONE;
                    end else begin
                        batch_count <= batch_count + 1;
                        state <= S_INIT; // Prepara o próximo lote
                    end
                end

                S_DONE: begin
                    done <= 1;
                end
            endcase
        end
    end
endmodule