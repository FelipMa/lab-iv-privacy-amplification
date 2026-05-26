import random

W = 64
P = 32
N = 640
L = 64
CYCLES = N // W
BATCHES = L // P

# Potências de 2 para o Quartus
ROM_KEY_DEPTH = 16
ROM_MATRIX_DEPTH = 32

key = [random.randint(0, 1) for _ in range(N)]
seed = [random.randint(0, 1) for _ in range(N + L - 1)]

# 1. Gerar key.mif (Tamanho 16)
with open("key.mif", "w") as f:
    f.write(f"DEPTH = {ROM_KEY_DEPTH};\nWIDTH = {W};\nADDRESS_RADIX = UNS;\nDATA_RADIX = BIN;\nCONTENT BEGIN\n")
    for i in range(ROM_KEY_DEPTH):
        if i < CYCLES:
            chunk = key[i*W : (i+1)*W]
            chunk_str = "".join(map(str, reversed(chunk)))
        else:
            chunk_str = "0" * W # Preenche o resto com zeros
        f.write(f"{i} : {chunk_str};\n")
    f.write("END;\n")

# 2. Gerar matrix.mif (Tamanho 32)
with open("matrix.mif", "w") as f:
    width_m = W + P - 1
    f.write(f"DEPTH = {ROM_MATRIX_DEPTH};\nWIDTH = {width_m};\nADDRESS_RADIX = UNS;\nDATA_RADIX = BIN;\nCONTENT BEGIN\n")
    for i in range(ROM_MATRIX_DEPTH):
        if i < (CYCLES * BATCHES):
            b = i // CYCLES
            c = i % CYCLES
            start_idx = b * P + c * W
            window = seed[start_idx : start_idx + width_m]
            window_str = "".join(map(str, reversed(window)))
        else:
            window_str = "0" * width_m # Preenche o resto com zeros
        f.write(f"{i} : {window_str};\n")
    f.write("END;\n")

print("Arquivos key.mif e matrix.mif alinhados em potência de 2!")