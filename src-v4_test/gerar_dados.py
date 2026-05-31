import random

# =========================================================================
# PARAMETRIZAÇÃO TOTAL DO PRIVACY AMPLIFICATION
# =========================================================================
W = 64
P = 30
N = 1000
L = 100

# =========================================================================
# CÁLCULOS DE CONSTANTES E PROFUNDIDADES DINÂMICAS (BASE 2)
# =========================================================================
CYCLES = (N + W - 1) // W
BATCHES = (L + P - 1) // P

necessario_key = CYCLES
necessario_matrix = CYCLES * BATCHES

ROM_DEPTH_KEY = max(32, 1 << (necessario_key - 1).bit_length())
ROM_DEPTH_MATRIX = max(32, 1 << (necessario_matrix - 1).bit_length())

ADDR_BITS_KEY = (ROM_DEPTH_KEY - 1).bit_length()
ADDR_BITS_MATRIX = (ROM_DEPTH_MATRIX - 1).bit_length()

# =========================================================================
# GERAÇÃO DOS VETORES DE BITS ALEATÓRIOS
# =========================================================================
random.seed(42) 
key_bits = [random.randint(0, 1) for _ in range(N)]
seed_bits = [random.randint(0, 1) for _ in range(N + L - 1)]

def bits_to_bin_str(bits): 
    return "".join(map(str, reversed(bits)))

def bits_to_hex_str(bits):
    bin_str = bits_to_bin_str(bits)
    # Converte para inteiro para garantir que a string hex não tenha bits fantasma
    val_int = int(bin_str, 2)
    
    # Calcula quantos caracteres hexadecimais são estritamente necessários
    # Ex: para 93 bits, (93 + 3) // 4 = 24 caracteres
    hex_len = (len(bits) + 3) // 4
    
    # Formata com zeros à esquerda baseando-se no número exato de caracteres
    return f"{val_int:0{hex_len}X}"

# =========================================================================
# 1. RASTREAMENTO DETALHADO E CÁLCULO DO HASH (DEBUG LOG)
# =========================================================================
final_hash = []
with open("debug_log.txt", "w") as log:
    log.write("=== RASTREAMENTO PASSO A PASSO ===\n")
    for b in range(BATCHES):
        log.write(f"\n--- LOTE {b} ---\n")
        acc = [0] * P
        for c in range(CYCLES):
            key_chunk = key_bits[c*W : (c+1)*W]

            if len(key_chunk) < W:
                key_chunk.extend([0] * (W - len(key_chunk)))
                
            start_idx = b * P + c * W
            matrix_window = seed_bits[start_idx : start_idx + (W + P - 1)]
            
            log.write(f"Ciclo {c}:\n")
            log.write(f"  Chave : {bits_to_hex_str(key_chunk)}\n")
            log.write(f"  Janela: {bits_to_hex_str(matrix_window)}\n")
            
            for i in range(P):
                # Deslocamento exato de 1 bit por motor (Alinhado com o Verilog i +: W)
                matrix_row = matrix_window[i : i + W]
                and_res = [k & m for k, m in zip(key_chunk, matrix_row)]
                xor_res = 0
                for bit in and_res:
                    xor_res ^= bit
                acc[i] ^= xor_res
                
            log.write(f"  Acumulado Parcial Hash: {bits_to_hex_str(acc)}\n")
        final_hash.extend(acc)

# =========================================================================
# 2. GERAR ARQUIVO DA MATRIZ SÍNCRONO DINÂMICO (matrix_lut.v)
# =========================================================================
MAT_WIDTH = W + P - 1
with open("matrix_lut.v", "w") as f:
    f.write("// Mock Sincrono gerado dinamicamente pelo Python (1 ciclo de latencia)\n")
    f.write("// Este modulo simula a chegada dos dados de streaming da matriz de Toeplitz.\n")
    f.write(f"module matrix_lut (\n    input wire clock,\n    input wire [{ADDR_BITS_MATRIX-1}:0] address,\n    output reg [{MAT_WIDTH-1}:0] q\n);\n")
    f.write("    always @(posedge clock) begin\n        case(address)\n")
    
    for i in range(ROM_DEPTH_MATRIX):
        if i < (CYCLES * BATCHES):
            b = i // CYCLES
            c = i % CYCLES
            start_idx = b * P + c * W
            window = seed_bits[start_idx : start_idx + MAT_WIDTH]
            hex_val = bits_to_hex_str(window)
        else:
            hex_val = "0" * ((MAT_WIDTH + 3) // 4)
        f.write(f"            {ADDR_BITS_MATRIX}'d{i}: q <= {MAT_WIDTH}'h{hex_val};\n")
        
    f.write(f"            default: q <= {MAT_WIDTH}'h0;\n        endcase\n    end\nendmodule\n")

# =========================================================================
# 3. GERAR ARQUIVO DE INICIALIZAÇÃO DA MEMÓRIA DA CHAVE (key.mif)
# =========================================================================
with open("key.mif", "w") as f:
    f.write(f"WIDTH={W};\n")
    f.write(f"DEPTH={ROM_DEPTH_KEY};\n\n")
    f.write("ADDRESS_RADIX=UNS;\n")
    f.write("DATA_RADIX=HEX;\n\n")
    f.write("CONTENT BEGIN\n")
    
    for i in range(ROM_DEPTH_KEY):
        if i < CYCLES:
            chunk = key_bits[i*W : (i+1)*W]
            hex_val = bits_to_hex_str(chunk)
        else:
            hex_val = "0"
        f.write(f"    {i} : {hex_val};\n")
        
    f.write("END;\n")

print("==================================================================")
print(" ARQUIVOS GERADOS DINAMICAMENTE COM SUCESSO                       ")
print("==================================================================")
print(f"Parâmetros: N={N}, W={W}, P={P}, L={L}")
print(f"Chave (ROM)   -> Profundidade: {ROM_DEPTH_KEY} linhas ({ADDR_BITS_KEY} bits de endereco)")
print(f"Matriz (LUT)  -> Profundidade: {ROM_DEPTH_MATRIX} linhas ({ADDR_BITS_MATRIX} bits de endereco), Largura: {MAT_WIDTH} bits")
print("==================================================================")