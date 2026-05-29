`timescale 1ns / 1ps

module top(
    input wire clock,
    input wire reset,

    // Interface direta com a Memória ROM Externa
    output reg [4:0] rom_key_addr,
    input wire [63:0] rom_key_q,

    // Saídas de Controle e Resultado
    output reg [31:0] hash_register,
    output reg batch_ready, 
    output reg done
);

    // =========================================================================
    // 1. INPUT BUFFER DA CHAVE (FIFO)
    // =========================================================================
    wire [63:0] key_fifo_q;
    reg fifo_wr_en, fifo_rd_en;
    wire key_fifo_valid, key_fifo_full, key_fifo_empty;

    input_buffer_fifo #(
        .IN_WIDTH(64),
        .BUF_DEPTH(32), 
        .OUT_WIDTH(64)
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
    // 2. LUT INTERNA DA MATRIZ (Gerada Dinamicamente pelo Python)
    // =========================================================================
    reg [4:0] matrix_addr_reg;
    wire [94:0] current_matrix_window;

    matrix_lut u_matrix_lut(
        .clock(clock),
        .address(matrix_addr_reg),
        .q(current_matrix_window)
    );

    // =========================================================================
    // 3. COMPREHENSION UNIT
    // =========================================================================
    reg comp_unit_clear;
    wire [31:0] current_hash_out;

    compression_unit #(
        .P(32),
        .W(64)
    ) u_compression_unit(
        .clock(clock),
        .reset(reset),
        .clear_acc(comp_unit_clear),
        .key(key_fifo_q),
        .matrix_window(current_matrix_window),
        .hash_out(current_hash_out)
    );

    // =========================================================================
    // 4. FSM UNIFICADA (Fetch -> Wait -> Calc -> Pipeline Delay -> Save)
    // =========================================================================
    localparam ST_IDLE       = 3'd0,
               ST_FETCH_REQ  = 3'd1,
               ST_WAIT_FILL  = 3'd2,
               ST_CALC       = 3'd3,
               ST_WAIT_MEM   = 3'd4,
               ST_WAIT_ACC   = 3'd5,
               ST_SAVE       = 3'd6;

    reg [2:0] state;
    reg [4:0] fetch_cnt;
    reg [4:0] calc_cnt;
    reg [1:0] batch_idx;
    reg [1:0] rom_lat_pipe;

    always @(posedge clock) begin
        if (reset) begin
            state <= ST_IDLE;
            rom_key_addr <= 0;
            fifo_wr_en <= 0;
            fifo_rd_en <= 0;
            comp_unit_clear <= 1;
            hash_register <= 0;
            batch_ready <= 0;
            done <= 0;
            fetch_cnt <= 0;
            calc_cnt <= 0;
            batch_idx <= 0;
            rom_lat_pipe <= 0;
            matrix_addr_reg <= 0;
        end else begin
            // Shift register para sincronizar a latência de 2 ciclos de leitura da ROM
            rom_lat_pipe[0] <= (state == ST_FETCH_REQ);
            rom_lat_pipe[1] <= rom_lat_pipe[0];
            fifo_wr_en      <= rom_lat_pipe[1]; 

            if (batch_ready) batch_ready <= 0;

            case (state)
                ST_IDLE: begin
                    fetch_cnt <= 0;
                    calc_cnt <= 0;
                    comp_unit_clear <= 1; 
                    if (batch_idx < 2) begin 
                        state <= ST_FETCH_REQ;
                    end else begin
                        done <= 1;
                    end
                end

                ST_FETCH_REQ: begin
                    rom_key_addr <= fetch_cnt;
                    if (fetch_cnt == 9) begin 
                        state <= ST_WAIT_FILL;
                    end else begin
                        fetch_cnt <= fetch_cnt + 1;
                    end
                end

                ST_WAIT_FILL: begin
                    if (!rom_lat_pipe[0] && !rom_lat_pipe[1] && !fifo_wr_en) begin
                        state <= ST_CALC;
                    end
                end

                ST_CALC: begin
                    comp_unit_clear <= 0; 
                    fifo_rd_en <= 1;      
                    matrix_addr_reg <= (batch_idx * 10) + calc_cnt; 

                    if (calc_cnt == 9) begin
                        state <= ST_WAIT_MEM;
                    end else begin
                        calc_cnt <= calc_cnt + 1;
                    end
                end

                ST_WAIT_MEM: begin
                    fifo_rd_en <= 0;
                    state <= ST_WAIT_ACC;
                end

                ST_WAIT_ACC: begin
                    state <= ST_SAVE;
                end

                ST_SAVE: begin
                    hash_register <= current_hash_out;
                    batch_ready <= 1;
                    batch_idx <= batch_idx + 1;
                    state <= ST_IDLE; 
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule