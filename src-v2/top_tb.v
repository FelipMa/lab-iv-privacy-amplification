`timescale 1ns / 1ps

module tb_top();
    reg clk, rst;
    wire [31:0] hash_out;
    wire done;

    // Instanciação do seu sistema (usando o top.v atualizado)
    top uut (
        .clock(clk),
        .reset(rst),
        .hash_register(hash_out),
        .done(done)
    );

    // Gerador de Clock (150 MHz = 6.66ns período)
    always #3.33 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        #20 rst = 0;
        
        // Aguarda o término
        wait(done);
        $display("Simulação concluída!");
        $display("Hash Final gerado: %h", hash_out);
        $finish;
    end
endmodule