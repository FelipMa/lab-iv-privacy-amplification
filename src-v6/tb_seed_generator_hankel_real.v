`timescale 1ns/1ps

// ============================================================
// Testbench REAL do seed_generator -> janelas -> matriz Hankel
//
// Objetivo:
//   1) Instanciar apenas o seed_generator real do RTL;
//   2) Capturar cada matrix_window realmente produzida pelo RTL;
//   3) Gravar as janelas em arquivos .hex/.csv;
//   4) Reconstruir a matriz Hankel L x N a partir das janelas;
//   5) Gravar a matriz Hankel final em arquivos .hex/.csv;
//   6) Verificar internamente a propriedade de Hankel:
//          H[row][col+1] == H[row+1][col]
//      para todos os pontos validos.
//
// Importante:
//   - Este TB NAO usa AES de referencia;
//   - Este TB NAO usa Python;
//   - As janelas e a matriz gravadas sao as produzidas pelo seed_generator real.
//
// Arquivos gerados:
//   seedgen_windows_real.hex
//   seedgen_windows_real.csv
//   seedgen_rows_from_windows_real.hex
//   seedgen_rows_from_windows_real.csv
//   seedgen_hankel_real.hex
//   seedgen_hankel_real.csv
// ============================================================

module tb_seed_generator_hankel_real;

    // Parametros atuais do projeto
    parameter N = 640;
    parameter L = 64;
    parameter W = 64;
    parameter P = 32;

    localparam CYCLES         = (N + W - 1) / W;
    localparam BATCHES        = (L + P - 1) / P;
    localparam WIN            = W + P - 1;
    localparam TOTAL_WINDOWS  = CYCLES * BATCHES;

    localparam HEX_CHARS_W    = (W   + 3) / 4;
    localparam HEX_CHARS_WIN  = (WIN + 3) / 4;
    localparam HEX_CHARS_N    = (N   + 3) / 4;

    reg clock;
    reg reset_n;
    reg prepare;
    reg go;
    reg [127:0] key;
    reg [95:0]  nonce;

    wire ready_to_stream;
    wire [WIN-1:0] matrix_window;
    wire busy;

    seed_generator #(
        .N(N),
        .L(L),
        .W(W),
        .P(P)
    ) dut (
        .clock(clock),
        .reset_n(reset_n),
        .prepare(prepare),
        .key(key),
        .nonce(nonce),
        .go(go),
        .ready_to_stream(ready_to_stream),
        .matrix_window(matrix_window),
        .busy(busy)
    );

    always #5 clock = ~clock; // 100 MHz

    // Matriz Hankel reconstruida a partir das janelas reais do RTL.
    // H[row][col] = seed[row + col]
    reg [N-1:0] hankel_matrix [0:L-1];

    // Guarda as janelas reais capturadas, para rastreamento/debug.
    reg [WIN-1:0] captured_windows [0:TOTAL_WINDOWS-1];

    integer fd_windows_hex;
    integer fd_windows_csv;
    integer fd_rows_hex;
    integer fd_rows_csv;
    integer fd_matrix_hex;
    integer fd_matrix_csv;

    integer seen_windows;
    integer batch_idx;
    integer cycle_idx;
    integer addr;
    integer start_bit;
    integer row_local;
    integer row_global;
    integer col_start;
    integer i;
    integer r;
    integer c;
    integer safety;
    integer hankel_errors;

    reg [W-1:0] row_chunk;

    // ------------------------------------------------------------
    // Escrita HEX com largura fixa, preservando a mesma orientacao
    // usada pelo Verilog: bit 0 eh o LSB do valor impresso.
    // ------------------------------------------------------------
    task write_hex_W;
        input integer fd;
        input [W-1:0] value;
        integer nib;
        integer k;
        integer bitpos;
        reg [3:0] h;
        begin
            for (nib = HEX_CHARS_W - 1; nib >= 0; nib = nib - 1) begin
                h = 4'd0;
                for (k = 0; k < 4; k = k + 1) begin
                    bitpos = nib * 4 + k;
                    if (bitpos < W)
                        h[k] = value[bitpos];
                end
                $fwrite(fd, "%1h", h);
            end
        end
    endtask

    task write_hex_WIN;
        input integer fd;
        input [WIN-1:0] value;
        integer nib;
        integer k;
        integer bitpos;
        reg [3:0] h;
        begin
            for (nib = HEX_CHARS_WIN - 1; nib >= 0; nib = nib - 1) begin
                h = 4'd0;
                for (k = 0; k < 4; k = k + 1) begin
                    bitpos = nib * 4 + k;
                    if (bitpos < WIN)
                        h[k] = value[bitpos];
                end
                $fwrite(fd, "%1h", h);
            end
        end
    endtask

    task write_hex_N;
        input integer fd;
        input [N-1:0] value;
        integer nib;
        integer k;
        integer bitpos;
        reg [3:0] h;
        begin
            for (nib = HEX_CHARS_N - 1; nib >= 0; nib = nib - 1) begin
                h = 4'd0;
                for (k = 0; k < 4; k = k + 1) begin
                    bitpos = nib * 4 + k;
                    if (bitpos < N)
                        h[k] = value[bitpos];
                end
                $fwrite(fd, "%1h", h);
            end
        end
    endtask

    task open_output_files;
        begin
            fd_windows_hex = $fopen("seedgen_windows_real.hex", "w");
            fd_windows_csv = $fopen("seedgen_windows_real.csv", "w");
            fd_rows_hex    = $fopen("seedgen_rows_from_windows_real.hex", "w");
            fd_rows_csv    = $fopen("seedgen_rows_from_windows_real.csv", "w");
            fd_matrix_hex  = $fopen("seedgen_hankel_real.hex", "w");
            fd_matrix_csv  = $fopen("seedgen_hankel_real.csv", "w");

            if (fd_windows_hex == 0 || fd_windows_csv == 0 ||
                fd_rows_hex == 0    || fd_rows_csv == 0    ||
                fd_matrix_hex == 0  || fd_matrix_csv == 0) begin
                $display("ERRO: nao foi possivel abrir um ou mais arquivos de saida.");
                $finish;
            end

            $fwrite(fd_windows_csv, "addr,batch,cycle,start_bit,end_bit_exclusive,window_hex\n");
            $fwrite(fd_rows_csv, "addr,batch,cycle,row_local,row_global,col_start,col_end_exclusive,row_chunk_hex\n");
            $fwrite(fd_matrix_csv, "row,row_hex\n");
        end
    endtask

    task close_output_files;
        begin
            $fclose(fd_windows_hex);
            $fclose(fd_windows_csv);
            $fclose(fd_rows_hex);
            $fclose(fd_rows_csv);
            $fclose(fd_matrix_hex);
            $fclose(fd_matrix_csv);
        end
    endtask

    // ------------------------------------------------------------
    // Captura UMA janela real produzida pelo seed_generator.
    // A partir dela, extrai P linhas locais:
    //     row_chunk = matrix_window[row_local +: W]
    // e coloca cada chunk no trecho correto da matriz Hankel.
    // ------------------------------------------------------------
    task capture_current_window_and_update_matrix;
        begin
            addr      = batch_idx * CYCLES + cycle_idx;
            start_bit = batch_idx * P + cycle_idx * W;

            captured_windows[addr] = matrix_window;

            // Arquivo de janelas reais
            $fwrite(fd_windows_hex,
                    "addr=%0d batch=%0d cycle=%0d start_bit=%0d end=%0d window=",
                    addr, batch_idx, cycle_idx, start_bit, start_bit + WIN);
            write_hex_WIN(fd_windows_hex, matrix_window);
            $fwrite(fd_windows_hex, "\n");

            $fwrite(fd_windows_csv, "%0d,%0d,%0d,%0d,%0d,",
                    addr, batch_idx, cycle_idx, start_bit, start_bit + WIN);
            write_hex_WIN(fd_windows_csv, matrix_window);
            $fwrite(fd_windows_csv, "\n");

            $display("[%0t ns] janela real: addr=%0d lote=%0d ciclo=%0d start_bit=%0d window=%0h",
                     $time, addr, batch_idx, cycle_idx, start_bit, matrix_window);

            // Reconstrucao da matriz Hankel a partir da janela
            for (row_local = 0; row_local < P; row_local = row_local + 1) begin
                row_global = batch_idx * P + row_local;
                col_start  = cycle_idx * W;
                row_chunk  = matrix_window[row_local +: W];

                if ((row_global < L) && (col_start + W <= N)) begin
                    hankel_matrix[row_global][col_start +: W] = row_chunk;
                end

                $fwrite(fd_rows_hex,
                        "addr=%0d batch=%0d cycle=%0d row_local=%0d row_global=%0d col=[%0d:%0d) row_chunk=",
                        addr, batch_idx, cycle_idx, row_local, row_global, col_start, col_start + W);
                write_hex_W(fd_rows_hex, row_chunk);
                $fwrite(fd_rows_hex, "\n");

                $fwrite(fd_rows_csv, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
                        addr, batch_idx, cycle_idx, row_local, row_global, col_start, col_start + W);
                write_hex_W(fd_rows_csv, row_chunk);
                $fwrite(fd_rows_csv, "\n");
            end
        end
    endtask

    // ------------------------------------------------------------
    // Verifica a propriedade de Hankel:
    //     H[r][c+1] == H[r+1][c]
    // Isso confirma que as janelas capturadas formam uma matriz
    // coerente, com diagonais anti-principais constantes.
    // ------------------------------------------------------------
    task verify_hankel_property;
        begin
            hankel_errors = 0;
            for (r = 0; r < L - 1; r = r + 1) begin
                for (c = 0; c < N - 1; c = c + 1) begin
                    if (hankel_matrix[r][c + 1] !== hankel_matrix[r + 1][c]) begin
                        if (hankel_errors < 20) begin
                            $display("ERRO HANKEL: H[%0d][%0d]=%0b difere de H[%0d][%0d]=%0b",
                                     r, c + 1, hankel_matrix[r][c + 1],
                                     r + 1, c, hankel_matrix[r + 1][c]);
                        end
                        hankel_errors = hankel_errors + 1;
                    end
                end
            end
        end
    endtask

    task dump_final_matrix;
        begin
            $display("============================================================");
            $display("Matriz Hankel reconstruida a partir das janelas reais do RTL");
            $display("Cada linha possui N=%0d bits e sera impressa em HEX.", N);
            $display("============================================================");

            for (i = 0; i < L; i = i + 1) begin
                $fwrite(fd_matrix_hex, "row=%0d hex=", i);
                write_hex_N(fd_matrix_hex, hankel_matrix[i]);
                $fwrite(fd_matrix_hex, "\n");

                $fwrite(fd_matrix_csv, "%0d,", i);
                write_hex_N(fd_matrix_csv, hankel_matrix[i]);
                $fwrite(fd_matrix_csv, "\n");

                $display("row=%0d hex=%0h", i, hankel_matrix[i]);
            end
        end
    endtask

    initial begin
        clock   = 1'b0;
        reset_n = 1'b0;
        prepare = 1'b0;
        go      = 1'b0;

        // Valores padrao do projeto. Podem ser sobrescritos com plusargs:
        //   +AES_KEY=2b7e151628aed2a6abf7158809cf4f3c
        //   +NONCE=000000000000000000000001
        key   = 128'h2b7e1516_28aed2a6_abf71588_09cf4f3c;
        nonce = 96'h00000000_00000000_00000001;

        if ($value$plusargs("AES_KEY=%h", key)) begin
            $display("AES_KEY sobrescrita por plusarg.");
        end
        if ($value$plusargs("NONCE=%h", nonce)) begin
            $display("NONCE sobrescrito por plusarg.");
        end

        seen_windows  = 0;
        batch_idx     = 0;
        cycle_idx     = 0;
        safety        = 0;
        hankel_errors = 0;

        for (i = 0; i < L; i = i + 1)
            hankel_matrix[i] = {N{1'b0}};

        for (i = 0; i < TOTAL_WINDOWS; i = i + 1)
            captured_windows[i] = {WIN{1'b0}};

        open_output_files();

        $display("============================================================");
        $display("TB REAL: seed_generator -> janelas -> matriz Hankel");
        $display("N=%0d L=%0d W=%0d P=%0d", N, L, W, P);
        $display("CYCLES=%0d BATCHES=%0d WIN=%0d TOTAL_WINDOWS=%0d", CYCLES, BATCHES, WIN, TOTAL_WINDOWS);
        $display("AES key = %032h", key);
        $display("Nonce   = %024h", nonce);
        $display("============================================================");

        repeat (5) @(negedge clock);
        reset_n = 1'b1;

        @(negedge clock);
        prepare = 1'b1;
        @(negedge clock);
        prepare = 1'b0;

        // Consome uma janela sempre que o seed_generator diz que ela esta pronta.
        while ((seen_windows < TOTAL_WINDOWS) && (safety < 300000)) begin
            @(negedge clock);
            safety = safety + 1;
            go = 1'b0;

            if (ready_to_stream) begin
                capture_current_window_and_update_matrix();

                go = 1'b1; // A janela sera consumida pelo DUT no proximo posedge.
                seen_windows = seen_windows + 1;

                if (cycle_idx + 1 == CYCLES) begin
                    cycle_idx = 0;
                    batch_idx = batch_idx + 1;
                end else begin
                    cycle_idx = cycle_idx + 1;
                end
            end
        end

        @(posedge clock);
        @(negedge clock);
        go = 1'b0;

        if (seen_windows != TOTAL_WINDOWS) begin
            $display("FALHA: timeout. Janelas capturadas = %0d / %0d", seen_windows, TOTAL_WINDOWS);
            close_output_files();
            $finish;
        end

        dump_final_matrix();
        verify_hankel_property();
        close_output_files();

        $display("============================================================");
        $display("Janelas capturadas: %0d / %0d", seen_windows, TOTAL_WINDOWS);
        $display("Erros Hankel      : %0d", hankel_errors);
        if (hankel_errors == 0)
            $display("PASS: as janelas reais do seed_generator formam uma matriz Hankel coerente.");
        else
            $display("FAIL: as janelas reais NAO preservam a propriedade de Hankel.");
        $display("Arquivos gerados:");
        $display("  seedgen_windows_real.hex");
        $display("  seedgen_windows_real.csv");
        $display("  seedgen_rows_from_windows_real.hex");
        $display("  seedgen_rows_from_windows_real.csv");
        $display("  seedgen_hankel_real.hex");
        $display("  seedgen_hankel_real.csv");
        $display("============================================================");

        $finish;
    end

endmodule
