#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
compare_seed_generator_tb.py

Gera em Python o mesmo stream de referência usado pelo tb_seed_generator.v:

    AES-128 CTR: AES(key, nonce || counter)
    Mapeamento Hankel: M[r][c] = s[r+c]
    Janela entregue ao seed_generator: W + P - 1 bits
    start_idx(batch, ciclo) = batch * P + ciclo * W

Uso básico:
    python compare_seed_generator_tb.py

Comparar com um transcript/log do ModelSim:
    python compare_seed_generator_tb.py --log transcript.txt

Gerar apenas uma tabela CSV:
    python compare_seed_generator_tb.py --csv windows.csv

Sem dependências externas. A implementação AES abaixo replica o comportamento do AES.v
para AES-128 com blocos de 128 bits em ordem big-endian, e a montagem do stream replica
a indexação LSB-first do testbench Verilog:

    reference_stream[i*128 + bit_idx] = tmp_block[bit_idx]
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple


# S-box AES padrão.
SBOX = [
    0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5, 0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76,
    0xCA, 0x82, 0xC9, 0x7D, 0xFA, 0x59, 0x47, 0xF0, 0xAD, 0xD4, 0xA2, 0xAF, 0x9C, 0xA4, 0x72, 0xC0,
    0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31, 0x15,
    0x04, 0xC7, 0x23, 0xC3, 0x18, 0x96, 0x05, 0x9A, 0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75,
    0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0, 0x52, 0x3B, 0xD6, 0xB3, 0x29, 0xE3, 0x2F, 0x84,
    0x53, 0xD1, 0x00, 0xED, 0x20, 0xFC, 0xB1, 0x5B, 0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF,
    0xD0, 0xEF, 0xAA, 0xFB, 0x43, 0x4D, 0x33, 0x85, 0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8,
    0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5, 0xBC, 0xB6, 0xDA, 0x21, 0x10, 0xFF, 0xF3, 0xD2,
    0xCD, 0x0C, 0x13, 0xEC, 0x5F, 0x97, 0x44, 0x17, 0xC4, 0xA7, 0x7E, 0x3D, 0x64, 0x5D, 0x19, 0x73,
    0x60, 0x81, 0x4F, 0xDC, 0x22, 0x2A, 0x90, 0x88, 0x46, 0xEE, 0xB8, 0x14, 0xDE, 0x5E, 0x0B, 0xDB,
    0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C, 0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79,
    0xE7, 0xC8, 0x37, 0x6D, 0x8D, 0xD5, 0x4E, 0xA9, 0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08,
    0xBA, 0x78, 0x25, 0x2E, 0x1C, 0xA6, 0xB4, 0xC6, 0xE8, 0xDD, 0x74, 0x1F, 0x4B, 0xBD, 0x8B, 0x8A,
    0x70, 0x3E, 0xB5, 0x66, 0x48, 0x03, 0xF6, 0x0E, 0x61, 0x35, 0x57, 0xB9, 0x86, 0xC1, 0x1D, 0x9E,
    0xE1, 0xF8, 0x98, 0x11, 0x69, 0xD9, 0x8E, 0x94, 0x9B, 0x1E, 0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF,
    0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16,
]

RCON = [
    0x00000000,
    0x01000000,
    0x02000000,
    0x04000000,
    0x08000000,
    0x10000000,
    0x20000000,
    0x40000000,
    0x80000000,
    0x1B000000,
    0x36000000,
]


@dataclass(frozen=True)
class Params:
    n: int = 640
    l: int = 64
    w: int = 64
    p: int = 32
    key: int = 0x2B7E151628AED2A6ABF7158809CF4F3C
    nonce: int = 0x000000000000000000000001

    @property
    def cycles(self) -> int:
        return ceil_div(self.n, self.w)

    @property
    def batches(self) -> int:
        return ceil_div(self.l, self.p)

    @property
    def win(self) -> int:
        return self.w + self.p - 1

    @property
    def total_windows(self) -> int:
        return self.cycles * self.batches

    @property
    def ref_bits(self) -> int:
        return ((self.batches - 1) * self.p) + ((self.cycles - 1) * self.w) + self.win

    @property
    def ref_blocks(self) -> int:
        return ceil_div(self.ref_bits, 128)


def ceil_div(a: int, b: int) -> int:
    if b <= 0:
        raise ValueError("Divisor deve ser positivo.")
    return (a + b - 1) // b


def parse_hex(value: str) -> int:
    cleaned = value.strip().lower().replace("_", "")
    if cleaned.startswith("0x"):
        cleaned = cleaned[2:]
    if not cleaned:
        raise ValueError("Valor hexadecimal vazio.")
    return int(cleaned, 16)


def int_to_bytes_be(x: int, width: int = 16) -> List[int]:
    return [(x >> (8 * (width - 1 - i))) & 0xFF for i in range(width)]


def bytes_to_int_be(values: Iterable[int]) -> int:
    out = 0
    for value in values:
        out = ((out << 8) | (value & 0xFF)) & ((1 << 128) - 1)
    return out


def xtime(x: int) -> int:
    x &= 0xFF
    return (((x << 1) & 0xFF) ^ (0x1B if (x & 0x80) else 0x00)) & 0xFF


def mul2(x: int) -> int:
    return xtime(x)


def mul3(x: int) -> int:
    return xtime(x) ^ (x & 0xFF)


def sub_bytes(state: List[int]) -> List[int]:
    return [SBOX[b] for b in state]


def shift_rows(state: List[int]) -> List[int]:
    # Mesma função ShiftRows do AES.v, usando os bytes b0..b15 na ordem [127:120]..[7:0].
    return [
        state[0], state[5], state[10], state[15],
        state[4], state[9], state[14], state[3],
        state[8], state[13], state[2], state[7],
        state[12], state[1], state[6], state[11],
    ]


def mix_columns(state: List[int]) -> List[int]:
    out = [0] * 16
    for col in range(4):
        j = col * 4
        a0, a1, a2, a3 = state[j], state[j + 1], state[j + 2], state[j + 3]
        out[j]     = mul2(a0) ^ mul3(a1) ^ a2       ^ a3
        out[j + 1] = a0       ^ mul2(a1) ^ mul3(a2) ^ a3
        out[j + 2] = a0       ^ a1       ^ mul2(a2) ^ mul3(a3)
        out[j + 3] = mul3(a0) ^ a1       ^ a2       ^ mul2(a3)
    return [x & 0xFF for x in out]


def subword_rotword(w3: int) -> int:
    # Igual ao Verilog:
    # {sbox(w3[23:16]), sbox(w3[15:8]), sbox(w3[7:0]), sbox(w3[31:24])}
    return (
        (SBOX[(w3 >> 16) & 0xFF] << 24)
        | (SBOX[(w3 >> 8) & 0xFF] << 16)
        | (SBOX[w3 & 0xFF] << 8)
        | SBOX[(w3 >> 24) & 0xFF]
    )


def key_expansion_round(round_key: int, round_number: int) -> int:
    if not 1 <= round_number <= 10:
        raise ValueError("round_number deve estar entre 1 e 10 para AES-128.")

    w0 = (round_key >> 96) & 0xFFFFFFFF
    w1 = (round_key >> 64) & 0xFFFFFFFF
    w2 = (round_key >> 32) & 0xFFFFFFFF
    w3 = round_key & 0xFFFFFFFF

    nw0 = w0 ^ subword_rotword(w3) ^ RCON[round_number]
    nw1 = w1 ^ nw0
    nw2 = w2 ^ nw1
    nw3 = w3 ^ nw2

    return ((nw0 << 96) | (nw1 << 64) | (nw2 << 32) | nw3) & ((1 << 128) - 1)


def aes128_encrypt_block(block: int, key: int) -> int:
    """AES-128 encrypt de 1 bloco, equivalente ao módulo AES.v usado no testbench."""
    mask128 = (1 << 128) - 1
    state = (block ^ key) & mask128
    round_key = key & mask128

    for round_number in range(1, 11):
        bytes_state = int_to_bytes_be(state)
        bytes_state = sub_bytes(bytes_state)
        bytes_state = shift_rows(bytes_state)
        round_key = key_expansion_round(round_key, round_number)
        if round_number < 10:
            bytes_state = mix_columns(bytes_state)
        state = (bytes_to_int_be(bytes_state) ^ round_key) & mask128

    return state


def aes_ctr_block(params: Params, counter: int) -> int:
    if not 0 <= params.nonce < (1 << 96):
        raise ValueError("nonce deve caber em 96 bits.")
    if not 0 <= counter < (1 << 32):
        raise ValueError("counter deve caber em 32 bits.")
    input_block = ((params.nonce << 32) | counter) & ((1 << 128) - 1)
    return aes128_encrypt_block(input_block, params.key)


def build_reference_stream(params: Params) -> int:
    """
    Monta o stream s como um inteiro LSB-first.

    Equivalente ao Verilog:
        reference_stream[i*128 + bit_idx] = tmp_block[bit_idx]
    """
    reference_stream = 0
    for block_idx in range(params.ref_blocks):
        block = aes_ctr_block(params, block_idx)
        for bit_idx in range(128):
            absolute_idx = block_idx * 128 + bit_idx
            if absolute_idx >= params.ref_bits:
                break
            if (block >> bit_idx) & 1:
                reference_stream |= 1 << absolute_idx
    return reference_stream


def expected_window(params: Params, reference_stream: int, batch: int, cycle: int) -> int:
    start_idx = batch * params.p + cycle * params.w
    mask = (1 << params.win) - 1
    return (reference_stream >> start_idx) & mask


def generate_windows(params: Params) -> List[Tuple[int, int, int]]:
    stream = build_reference_stream(params)
    rows: List[Tuple[int, int, int]] = []
    for batch in range(params.batches):
        for cycle in range(params.cycles):
            rows.append((batch, cycle, expected_window(params, stream, batch, cycle)))
    return rows


def parse_modelsim_log(path: Path) -> Dict[Tuple[int, int], str]:
    """
    Extrai linhas do tipo:
        # [1640000 ns] OK batch=0 ciclo=0 janela=2c754011ae

    Retorna {(batch, ciclo): janela_hex_sem_prefixo}.
    """
    regex = re.compile(
        r"\bOK\s+batch\s*=\s*(\d+)\s+ciclo\s*=\s*(\d+)\s+janela\s*=\s*([0-9a-fA-F]+)"
    )
    found: Dict[Tuple[int, int], str] = {}
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        match = regex.search(line)
        if not match:
            continue
        batch = int(match.group(1))
        cycle = int(match.group(2))
        window_hex = match.group(3).lower().lstrip("0") or "0"
        found[(batch, cycle)] = window_hex
    return found


def compare_with_log(params: Params, log_path: Path) -> int:
    generated = generate_windows(params)
    observed = parse_modelsim_log(log_path)

    expected_by_key = {
        (batch, cycle): format(window, "x")
        for batch, cycle, window in generated
    }

    errors = 0
    print("=================================================")
    print(f"Comparando Python x ModelSim: {log_path}")
    print("=================================================")

    for key, expected_hex in expected_by_key.items():
        batch, cycle = key
        observed_hex = observed.get(key)
        if observed_hex is None:
            print(f"MISSING batch={batch} ciclo={cycle}: esperado={expected_hex}")
            errors += 1
        elif observed_hex != expected_hex:
            print(f"ERRO batch={batch} ciclo={cycle}")
            print(f"  esperado_python = {expected_hex}")
            print(f"  obtido_modelsim  = {observed_hex}")
            errors += 1
        else:
            print(f"OK batch={batch} ciclo={cycle} janela={expected_hex}")

    extras = sorted(set(observed) - set(expected_by_key))
    for batch, cycle in extras:
        print(f"EXTRA no log batch={batch} ciclo={cycle}: janela={observed[(batch, cycle)]}")
        errors += 1

    print("=================================================")
    print(f"Janelas esperadas : {len(expected_by_key)}")
    print(f"Janelas no log    : {len(observed)}")
    print(f"Divergências      : {errors}")
    print("=================================================")

    if errors == 0:
        print("PASS: o log do testbench coincide com a referência Python.")
    else:
        print("FAIL: há divergência entre o log do testbench e a referência Python.")
    return errors


def write_csv(params: Params, csv_path: Path) -> None:
    rows = generate_windows(params)
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["batch", "ciclo", "start_idx", "janela_hex"])
        for batch, cycle, window in rows:
            start_idx = batch * params.p + cycle * params.w
            writer.writerow([batch, cycle, start_idx, format(window, "x")])


def print_reference(params: Params) -> None:
    print("=================================================")
    print("Python Seed Generator Reference - AES-128 CTR + Hankel windows")
    print(
        f"N={params.n} L={params.l} W={params.w} P={params.p} "
        f"WIN={params.win} CYCLES={params.cycles} BATCHES={params.batches}"
    )
    print(f"Reference stream bits={params.ref_bits} blocks AES={params.ref_blocks}")
    print("=================================================")

    first_block = aes_ctr_block(params, 0)
    print(f"AES(key, nonce||0) = {first_block:032x}")
    print("=================================================")

    for batch, cycle, window in generate_windows(params):
        print(f"OK batch={batch} ciclo={cycle} janela={window:x}")

    print("=================================================")
    print(f"Janelas geradas: {params.total_windows} / {params.total_windows}")
    print("=================================================")


def validate_params(params: Params) -> None:
    if params.n <= 0 or params.l <= 0 or params.w <= 0 or params.p <= 0:
        raise ValueError("N, L, W e P devem ser positivos.")
    if not 0 <= params.key < (1 << 128):
        raise ValueError("key deve caber em 128 bits.")
    if not 0 <= params.nonce < (1 << 96):
        raise ValueError("nonce deve caber em 96 bits.")


def self_test_aes() -> None:
    # Vetor clássico FIPS-197: AES-128(3243f6a8885a308d313198a2e0370734)
    # com chave 2b7e151628aed2a6abf7158809cf4f3c deve gerar
    # 3925841d02dc09fbdc118597196a0b32.
    key = 0x2B7E151628AED2A6ABF7158809CF4F3C
    block = 0x3243F6A8885A308D313198A2E0370734
    expected = 0x3925841D02DC09FBDC118597196A0B32
    got = aes128_encrypt_block(block, key)
    if got != expected:
        raise AssertionError(f"AES self-test falhou: esperado={expected:032x}, obtido={got:032x}")


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Gera e compara as janelas Hankel AES-CTR esperadas pelo tb_seed_generator.v."
    )
    parser.add_argument("--N", type=int, default=640, help="Tamanho da chave reconciliada. Default: 640")
    parser.add_argument("--L", type=int, default=64, help="Tamanho da chave final. Default: 64")
    parser.add_argument("--W", type=int, default=64, help="Largura processada por ciclo. Default: 64")
    parser.add_argument("--P", type=int, default=32, help="Grau de paralelismo/linhas por batch. Default: 32")
    parser.add_argument(
        "--key",
        type=parse_hex,
        default=parse_hex("2b7e1516_28aed2a6_abf71588_09cf4f3c"),
        help="Chave AES-128 em hexadecimal. Default igual ao testbench.",
    )
    parser.add_argument(
        "--nonce",
        type=parse_hex,
        default=parse_hex("00000000_00000000_00000001"),
        help="Nonce de 96 bits em hexadecimal. Default igual ao testbench.",
    )
    parser.add_argument(
        "--log",
        type=Path,
        default=None,
        help="Arquivo transcript/log do ModelSim para comparar as janelas impressas pelo testbench.",
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=None,
        help="Caminho para salvar CSV com batch, ciclo, start_idx e janela_hex.",
    )
    parser.add_argument(
        "--no-print",
        action="store_true",
        help="Não imprime a tabela de referência; útil quando usar apenas --csv ou --log.",
    )
    parser.add_argument(
        "--no-self-test",
        action="store_true",
        help="Não executa o autoteste AES FIPS-197.",
    )
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    args = build_arg_parser().parse_args(argv)

    if not args.no_self_test:
        self_test_aes()

    params = Params(n=args.N, l=args.L, w=args.W, p=args.P, key=args.key, nonce=args.nonce)
    validate_params(params)

    if not args.no_print:
        print_reference(params)

    if args.csv is not None:
        write_csv(params, args.csv)
        print(f"CSV salvo em: {args.csv}")

    if args.log is not None:
        if not args.log.exists():
            print(f"Erro: arquivo de log não encontrado: {args.log}", file=sys.stderr)
            return 2
        errors = compare_with_log(params, args.log)
        return 0 if errors == 0 else 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
