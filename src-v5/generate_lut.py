import sys

# Parâmetros Hardcoded
W = 32
P = 32
N = 128
L = 64
HARDCODED_KEY_HEX = "7F4D92B1C0E8A3549B62F10D85A7C3E9"
HARDCODED_SEED_HEX = "6A2F8B10C5D4E92A3B84F716D09E5C3B2A1F8D4E76B093C1"

def generate_lut():
    CYCLES = (N + W - 1) // W
    BATCHES = (L + P - 1) // P
    
    window_size = W + P - 1
    
    # Semente de 191 bits
    seed_val = int(HARDCODED_SEED_HEX, 16)
    seed_bin = format(seed_val, '0191b')
    
    # Invertemos a string para que o índice 0 seja o LSB (bit menos significativo)
    seed_bin_lsb_first = seed_bin[::-1]
    
    lut_entries = []
    address = 0
    
    for batch in range(BATCHES):
        for word in range(CYCLES):
            # Lógica de cálculo do offset.
            # Baseado em Toeplitz Hashing: avança W bits a cada palavra e P bits a cada batch.
            seed_offset = batch * P + word * W
            
            # current_matrix_window = HARDCODED_SEED[seed_offset +: (W+P-1)]
            window_slice = seed_bin_lsb_first[seed_offset : seed_offset + window_size]
            
            # Preenchimento com zeros caso passe do limite da semente
            if len(window_slice) < window_size:
                window_slice += '0' * (window_size - len(window_slice))
                
            # Retorna para MSB-first para conversão hexadecimal
            window_bin = window_slice[::-1]
            window_val = int(window_bin, 2)
            
            lut_entries.append(f"            6'd{address}: q <= {window_size}'h{window_val:0{int((window_size+3)//4)}X};")
            address += 1

    verilog_code = f"""// Gerado automaticamente por generate_lut.py
module matrix_lut (
    input wire clock,
    input wire [5:0] address,
    output reg [{window_size-1}:0] q
);
    always @(posedge clock) begin
        case(address)
"""
    for entry in lut_entries:
        verilog_code += entry + "\n"
        
    verilog_code += f"""            default: q <= {window_size}'h0;
        endcase
    end
endmodule
"""
    
    with open("matrix_lut.v", "w") as f:
        f.write(verilog_code)
        
    print(f"Arquivo 'matrix_lut.v' gerado com sucesso com {address} posições de memória!")

if __name__ == "__main__":
    generate_lut()