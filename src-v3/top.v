`timescale 1ns / 1ps

module top #(
    // Parâmetros Globais do Privacy Amplification
    parameter N = 640,
    parameter W = 64,
    parameter P = 32,
    parameter L = 64
)(
    input wire clock,
    input wire reset,

    // Interface direta com a Memória ROM Externa
    output reg [7:0] rom_key_addr, 
    input wire [(W-1):0] rom_key_q,

    // Saídas de Controle e Resultado
    output reg [(P-1):0] hash_register,
    output reg batch_ready, 
    output reg done
);

    // =========================================================================
    // CONSTANTES DERIVADAS
    // =========================================================================
    localparam CYCLES = N / W;                  
    localparam BATCHES = L / P;                 
    localparam TOTAL_TICKS = CYCLES * BATCHES;  

    // =========================================================================
    // 1. INPUT BUFFER DA CHAVE (FIFO)
    // =========================================================================
    wire [(W-1):0] key_fifo_q;
    reg fifo_wr_en, fifo_rd_en;
    wire key_fifo_valid, key_fifo_full, key_fifo_empty;

    input_buffer_fifo #(
        .IN_WIDTH(W),
        .BUF_DEPTH(32), 
        .OUT_WIDTH(W)
    ) key_fifo (
        .clk(clock),
        .rst_n(!reset),
        .push_data(rom_key_q),
        .wr_en(fifo_wr_en),
        .rd_en(fifo_rd_en),
        .data_out(key_fifo_q),
        .data_valid(key_fifo_valid),
        .full(key_fifo_full),
        .empty(key_fifo_empty)
    );

    // =========================================================================
    // 2. LUT INTERNA DA MATRIZ
    // =========================================================================
    reg [7:0] matrix_addr_reg;
    wire [(W+P-2):0] current_matrix_window;

    matrix_lut u_matrix_lut(
        .clock(clock),
        .address(matrix_addr_reg[4:0]),
        .q(current_matrix_window)
    );

    // =========================================================================
    // 3. COMPRESSION UNIT
    // =========================================================================
    reg comp_unit_clear;
    wire [(P-1):0] current_hash_out;

    compression_unit #(
        .P(P),
        .W(W)
    ) u_compression_unit(
        .clock(clock),
        .reset(reset),
        .clear_acc(comp_unit_clear),
        .key(key_fifo_q),
        .matrix_window(current_matrix_window),
        .hash_out(current_hash_out)
    );

    // =========================================================================
    // 4. DUPLA FSM
    // =========================================================================
    
    // -------------------------------------------------------------------------
    // FSM 1: FETCH (Enche a FIFO completamente com todos os lotes)
    // -------------------------------------------------------------------------
    reg [1:0] fetch_state;
    reg [7:0] fetch_cnt;
    reg [1:0] rom_lat_pipe;
    reg buffer_ready;

    always @(posedge clock) begin
        if (reset) begin
            fetch_state <= 0;
            fetch_cnt <= 0;
            rom_key_addr <= 0;
            fifo_wr_en <= 0;
            rom_lat_pipe <= 0;
            buffer_ready <= 0;
        end else begin
            rom_lat_pipe[0] <= (fetch_state == 1);
            rom_lat_pipe[1] <= rom_lat_pipe[0];
            fifo_wr_en      <= rom_lat_pipe[1]; 

            case (fetch_state)
                0: begin
                    if (!done && !buffer_ready) begin
                        fetch_state <= 1;
                        fetch_cnt <= 0;
                    end
                end
                1: begin
                    rom_key_addr <= fetch_cnt % CYCLES; 
                    
                    if (fetch_cnt == TOTAL_TICKS - 1) begin
                        fetch_state <= 2;
                    end else begin
                        fetch_cnt <= fetch_cnt + 1;
                    end
                end
                2: begin
                    if (!rom_lat_pipe[0] && !rom_lat_pipe[1] && !fifo_wr_en) begin
                        buffer_ready <= 1;
                        fetch_state <= 3; 
                    end
                end
                3: begin
                    // Concluído
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // FSM 2: CALC 
    // -------------------------------------------------------------------------
    localparam S_CALC_IDLE  = 3'd0;
    localparam S_CALC_RUN   = 3'd1;
    localparam S_CALC_WAIT  = 3'd2;
    localparam S_CALC_SAVE  = 3'd3;
    localparam S_CALC_DONE  = 3'd4;

    reg [2:0] calc_state;
    reg [7:0] calc_cnt;
    reg [7:0] batch_idx;

    always @(posedge clock) begin
        if (reset) begin
            calc_state <= S_CALC_IDLE;
            calc_cnt <= 0;
            batch_idx <= 0;
            fifo_rd_en <= 0;
            matrix_addr_reg <= 0;
            comp_unit_clear <= 1;
            hash_register <= 0;
            batch_ready <= 0;
            done <= 0;
        end else begin
            if (batch_ready) batch_ready <= 0;

            case (calc_state)
                S_CALC_IDLE: begin
                    if (buffer_ready && !done) begin
                        calc_state <= S_CALC_RUN;
                        calc_cnt <= 0;
                        batch_idx <= 0;
                        comp_unit_clear <= 1; 
                    end
                end

                S_CALC_RUN: begin 
                    comp_unit_clear <= 0;
                    
                    // Condição para bloquear a leitura da FIFO e o avanço da Matriz
                    // após os ciclos efetivos de extração do lote
                    if (calc_cnt < CYCLES) begin
                        fifo_rd_en <= 1;
                        matrix_addr_reg <= (batch_idx * CYCLES) + calc_cnt;
                    end else begin
                        fifo_rd_en <= 0;
                    end

                    // Mantém o clear no ciclo de start conforme especificado
                    if(calc_cnt == 1) comp_unit_clear <= 1;

                    if (calc_cnt == CYCLES + 1) begin
                        calc_state <= S_CALC_WAIT;
                    end else begin
                        calc_cnt <= calc_cnt + 1;
                    end
                end

                S_CALC_WAIT: begin // 1 ciclo aguardando latência da LUT/FIFO
                    fifo_rd_en <= 0;
                    calc_state <= S_CALC_SAVE;
						  calc_cnt <= 0;
                end

                S_CALC_SAVE: begin // 1 ciclo salvando no registrador
                    fifo_rd_en <= 0;
                    hash_register <= current_hash_out;
                    batch_ready <= 1;
                    
                    if (batch_idx == BATCHES - 1) begin
                        calc_state <= S_CALC_DONE;
                    end else begin
                        batch_idx <= batch_idx + 1;
                        calc_state <= S_CALC_RUN;
                    end
                end

                S_CALC_DONE: begin
                    done <= 1;
                end

                default: calc_state <= S_CALC_IDLE;
            endcase
        end
    end

endmodule