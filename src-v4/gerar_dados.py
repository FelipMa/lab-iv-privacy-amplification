import random

W = 64
P = 32
N = 640
L = 64
CYCLES = N // W  # 10
BATCHES = L // P # 2
ROM_DEPTH = 32   # Quantidade minima exigida de palavras na memoria

random.seed(42) 
key_bits = [random.randint(0, 1) for _ in range(N)]
seed_bits = [random.randint(0, 1) for _ in range(N + L - 1)]

def bits_to_bin_str(bits): return "".join(map(str, reversed(bits)))
def bits_to_hex_str(bits):
    bin_str = bits_to_bin_str(bits)
    hex_len = (len(bits) + 3) // 4
    return f"{int(bin_str, 2):0{hex_len}X}"

final_hash = []

# 1. RASTREAMENTO DETALHADO (DEBUG LOG)
with open("debug_log.txt", "w") as log:
    log.write("=== RASTREAMENTO PASSO A PASSO ===\n")
    for b in range(BATCHES):
        log.write(f"\n--- LOTE {b} ---\n")
        acc = [0] * P
        for c in range(CYCLES):
            key_chunk = key_bits[c*W : (c+1)*W]
            seed_start = b * P + c * W
            seed_chunk = seed_bits[seed_start : seed_start + W + P - 1]
            
            log.write(f"Ciclo {c}: KEY=0x{bits_to_hex_str(key_chunk)} | MATRIZ=0x{bits_to_hex_str(seed_chunk)}\n")
            for i in range(P):
                engine_slice = seed_chunk[i : i+W]
                parity = sum([key_chunk[k] & engine_slice[k] for k in range(W)]) % 2
                acc[i] ^= parity
            log.write(f" -> ACC Fim do Ciclo {c}: 0x{bits_to_hex_str(acc)}\n")
        log.write(f"\n>>> LOTE {b} FINAL: 0x{bits_to_hex_str(acc)} <<<\n")
        final_hash.extend(acc)

# 2. GERAR MOCK DA MATRIZ SÍNCRONO (matrix_lut.v)
# Codigo 100% sintetizavel (Logica pura, nao usa memoria em bloco)
with open("matrix_lut.v", "w") as f:
    f.write("// Mock Sincrono gerado dinamicamente pelo Python (1 ciclo de latencia)\n")
    f.write("// Este modulo simula a chegada dos dados de streaming da matriz de Toeplitz.\n")
    f.write("module matrix_lut (\n    input wire clock,\n    input wire [4:0] address,\n    output reg [94:0] q\n);\n")
    f.write("    always @(posedge clock) begin\n        case(address)\n")
    for i in range(ROM_DEPTH):
        if i < (CYCLES * BATCHES):
            b, c = i // CYCLES, i % CYCLES
            start_idx = b * P + c * W
            window = seed_bits[start_idx : start_idx + (W + P - 1)]
            hex_val = bits_to_hex_str(window)
        else:
            hex_val = "0"
        f.write(f"            5'd{i}: q <= 95'h{hex_val};\n")
    f.write("            default: q <= 95'h0;\n        endcase\n    end\nendmodule\n")

# 3. GERAR APENAS O ARQUIVO MIF PARA A CHAVE (ROM KEY)
with open("key.mif", "w") as f:
    f.write(f"DEPTH = {ROM_DEPTH};\nWIDTH = {W};\nADDRESS_RADIX = UNS;\nDATA_RADIX = BIN;\nCONTENT BEGIN\n")
    for i in range(ROM_DEPTH):
        chunk_str = bits_to_bin_str(key_bits[i*W : (i+1)*W]) if i < CYCLES else "0" * W
        f.write(f"{i} : {chunk_str};\n")
    f.write("END;\n")

print(f"Ficheiros gerados com sucesso. ROM_DEPTH fixado em {ROM_DEPTH} palavras.")