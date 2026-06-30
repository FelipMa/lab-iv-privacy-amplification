#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import math
import random

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes


# ============================================================
# PARAMETROS DO PROJETO
# ============================================================

W = 64
P = 32
N = 640
L = 64

MASTER_SEED = 42

# Se quiser fixar manualmente, preencha aqui.
# Se deixar None, o script gera dinamicamente a partir da MASTER_SEED.

FIXED_SEED_KEY   = "2B7E151628AED2A6ABF7158809CF4F3C"
FIXED_SEED_NONCE = "000000000000000000000001"


# ============================================================
# FUNCOES AUXILIARES
# ============================================================

def next_pow2(x):
    if x <= 1:
        return 1
    return 1 << (x - 1).bit_length()


def int_to_bits_lsb(value, width):
    return [(value >> i) & 1 for i in range(width)]


def bits_to_int_lsb(bits):
    value = 0
    for i, bit in enumerate(bits):
        if bit:
            value |= (1 << i)
    return value


def bits_to_hex_lsb(bits, width=None):
    if width is None:
        width = len(bits)

    value = bits_to_int_lsb(bits)
    hex_len = (width + 3) // 4

    return f"{value:0{hex_len}X}"


def xor_reduce(bits):
    acc = 0
    for bit in bits:
        acc ^= bit
    return acc


def gerar_stream_aes_ctr(seed_key_int, seed_nonce_int, nbits):
    """
    Gera stream AES-128 CTR usando biblioteca cryptography.

    O bloco de entrada do CTR é:

        SEED_NONCE || counter

    com:
        SEED_NONCE = 96 bits
        counter    = 32 bits, iniciando em 0

    A saída é convertida para bits LSB-first para bater com o Verilog:
        stream[0] = bit 0 do output_block AES.
    """

    key_bytes = seed_key_int.to_bytes(16, byteorder="big")
    nonce_bytes = seed_nonce_int.to_bytes(12, byteorder="big")
    counter_bytes = (0).to_bytes(4, byteorder="big")

    initial_counter_block = nonce_bytes + counter_bytes

    blocks = math.ceil(nbits / 128)

    cipher = Cipher(
        algorithms.AES(key_bytes),
        modes.CTR(initial_counter_block)
    )

    encryptor = cipher.encryptor()

    # Em CTR, cifrar zeros gera diretamente o keystream.
    stream_bytes = encryptor.update(bytes(blocks * 16)) + encryptor.finalize()

    stream_bits = []

    for i in range(blocks):
        block = stream_bytes[i * 16:(i + 1) * 16]
        block_int = int.from_bytes(block, byteorder="big")

        # LSB-first, igual ao acesso output_block[0], output_block[1]...
        stream_bits.extend(int_to_bits_lsb(block_int, 128))

    return stream_bits[:nbits]


# ============================================================
# MAIN
# ============================================================

def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("--seed", type=int, default=MASTER_SEED)
    parser.add_argument("--seed-key", type=str, default=FIXED_SEED_KEY)
    parser.add_argument("--seed-nonce", type=str, default=FIXED_SEED_NONCE)

    args = parser.parse_args()

    cycles = (N + W - 1) // W
    batches = (L + P - 1) // P
    win = W + P - 1

    rom_depth_key = max(32, next_pow2(cycles))

    rng = random.Random(args.seed)

    # ========================================================
    # 1. GERA CHAVE RECONCILIADA DINAMICAMENTE
    # ========================================================

    key_bits = [rng.getrandbits(1) for _ in range(N)]

    # ========================================================
    # 2. GERA SEED_KEY E SEED_NONCE DINAMICAMENTE
    # ========================================================

    if args.seed_key is not None:
        seed_key_int = int(args.seed_key.replace("0x", "").replace("0X", ""), 16)
    else:
        seed_key_int = rng.getrandbits(128)

    if args.seed_nonce is not None:
        seed_nonce_int = int(args.seed_nonce.replace("0x", "").replace("0X", ""), 16)
    else:
        seed_nonce_int = rng.getrandbits(96)

    # ========================================================
    # 3. GERA STREAM AES-CTR
    # ========================================================

    stream_bits_needed = N + L - 1

    stream_bits = gerar_stream_aes_ctr(
        seed_key_int=seed_key_int,
        seed_nonce_int=seed_nonce_int,
        nbits=stream_bits_needed
    )

    # ========================================================
    # 4. GERA key.mif
    # ========================================================

    with open("key.mif", "w", encoding="utf-8") as f:
        f.write(f"WIDTH={W};\n")
        f.write(f"DEPTH={rom_depth_key};\n\n")
        f.write("ADDRESS_RADIX=UNS;\n")
        f.write("DATA_RADIX=HEX;\n\n")
        f.write("CONTENT BEGIN\n")

        for addr in range(rom_depth_key):
            if addr < cycles:
                chunk = key_bits[addr * W:(addr + 1) * W]

                if len(chunk) < W:
                    chunk += [0] * (W - len(chunk))

                hex_val = bits_to_hex_lsb(chunk, W)
            else:
                hex_val = "0" * ((W + 3) // 4)

            f.write(f"    {addr} : {hex_val};\n")

        f.write("END;\n")

    # ========================================================
    # 5. CALCULA PRIVACY AMPLIFICATION E GERA debug_log.txt
    # ========================================================

    final_hash_bits = []

    with open("debug_log.txt", "w", encoding="utf-8") as log:
        log.write("============================================================\n")
        log.write("DEBUG PRIVACY AMPLIFICATION - AES-128 CTR SEED GENERATOR\n")
        log.write("============================================================\n")
        log.write(f"N={N}\n")
        log.write(f"L={L}\n")
        log.write(f"W={W}\n")
        log.write(f"P={P}\n")
        log.write(f"CYCLES={cycles}\n")
        log.write(f"BATCHES={batches}\n")
        log.write(f"WIN={win}\n")
        log.write(f"MASTER_SEED={args.seed}\n")
        log.write("\n")
        log.write(f"SEED_KEY   = 128'h{seed_key_int:032X}\n")
        log.write(f"SEED_NONCE = 96'h{seed_nonce_int:024X}\n")
        log.write("\n")
        log.write("Use esses valores no top.v:\n")
        log.write(f"parameter [127:0] SEED_KEY   = 128'h{seed_key_int:032X},\n")
        log.write(f"parameter [95:0]  SEED_NONCE = 96'h{seed_nonce_int:024X}\n")
        log.write("\n")
        log.write("============================================================\n")
        log.write("OPERACOES\n")
        log.write("============================================================\n")

        for batch in range(batches):
            acc = [0] * P

            log.write("\n")
            log.write(f"---------------- LOTE {batch} ----------------\n")

            for cycle in range(cycles):
                key_start = cycle * W
                key_piece = key_bits[key_start:key_start + W]

                if len(key_piece) < W:
                    key_piece += [0] * (W - len(key_piece))

                start_idx = batch * P + cycle * W
                matrix_window = stream_bits[start_idx:start_idx + win]

                if len(matrix_window) < win:
                    matrix_window += [0] * (win - len(matrix_window))

                hash_step = [0] * P

                for lane in range(P):
                    matrix_row = matrix_window[lane:lane + W]

                    and_result = [
                        key_piece[i] & matrix_row[i]
                        for i in range(W)
                    ]

                    bit_hash = xor_reduce(and_result)

                    hash_step[lane] = bit_hash
                    acc[lane] ^= bit_hash

                log.write(f"\nCiclo {cycle}\n")
                log.write(f"  key_piece     = 0x{bits_to_hex_lsb(key_piece, W)}\n")
                log.write(f"  matrix_window = 0x{bits_to_hex_lsb(matrix_window, win)}\n")
                log.write(f"  hash_step     = 0x{bits_to_hex_lsb(hash_step, P)}\n")
                log.write(f"  hash_acc      = 0x{bits_to_hex_lsb(acc, P)}\n")

            valid_lanes = min(P, L - batch * P)
            batch_hash = acc[:valid_lanes]
            final_hash_bits.extend(batch_hash)

            log.write("\n")
            log.write(f"LOTE {batch} FINALIZADO\n")
            log.write(f"  hash_out_lote = 0x{bits_to_hex_lsb(batch_hash, valid_lanes)}\n")

        final_hash_bits = final_hash_bits[:L]

        log.write("\n")
        log.write("============================================================\n")
        log.write("RESULTADO FINAL\n")
        log.write("============================================================\n")

        for batch in range(batches):
            start = batch * P
            end = min(start + P, L)
            lote_bits = final_hash_bits[start:end]

            log.write(f"HASH_LOTE_{batch} = 0x{bits_to_hex_lsb(lote_bits, len(lote_bits))}\n")

        log.write("\n")
        log.write(f"FINAL_KEY = 0x{bits_to_hex_lsb(final_hash_bits, L)}\n")

    # ========================================================
    # 6. PRINT RESUMIDO NO TERMINAL
    # ========================================================

    print("============================================================")
    print("ARQUIVOS GERADOS")
    print("============================================================")
    print("key.mif")
    print("debug_log.txt")
    print("============================================================")
    print(f"SEED_KEY   = 128'h{seed_key_int:032X}")
    print(f"SEED_NONCE = 96'h{seed_nonce_int:024X}")
    print(f"FINAL_KEY  = 0x{bits_to_hex_lsb(final_hash_bits, L)}")
    print("============================================================")


if __name__ == "__main__":
    main()