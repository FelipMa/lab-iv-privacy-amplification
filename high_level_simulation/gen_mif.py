"""Gera input_vectors.mif e expected_outputs.hex para a validacao da v1.

Empacotamento da palavra de 23 bits (default W=8, P=8), MSB-first:
    bits[22:8] = matrix_window (15 bits)
    bits[7:0]  = key            (8 bits)

A profundidade da memoria de entrada e 16 (4-bit address).
Os valores esperados sao calculados pelo modelo numpy/scipy em
compression_model.compress.
"""

from __future__ import annotations

import random
from pathlib import Path

from compression_model import DEFAULT_P as P
from compression_model import DEFAULT_W as W
from compression_model import compress

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "src" / "tb_mem_validation"
MIF_PATH = OUT_DIR / "input_vectors.mif"
EXPECTED_PATH = OUT_DIR / "expected_outputs.hex"

DEPTH = 16
MATRIX_WINDOW_BITS = W + P - 1  # 15
WORD_BITS = W + MATRIX_WINDOW_BITS  # 23


def deterministic_vectors() -> list[tuple[int, int]]:
    return [
        (0x00, 0x0000),
        (0xFF, 0x7FFF),
        (0x01, 0x0001),
        (0xAA, 0x5555),
    ]


def random_vectors(n: int, seed: int = 0) -> list[tuple[int, int]]:
    rng = random.Random(seed)
    return [
        (
            rng.randint(0, (1 << W) - 1),
            rng.randint(0, (1 << MATRIX_WINDOW_BITS) - 1),
        )
        for _ in range(n)
    ]


def pack(key: int, matrix_window: int) -> int:
    return (matrix_window << W) | key


def write_mif(path: Path, words: list[int]) -> None:
    hex_chars = (WORD_BITS + 3) // 4
    addr_chars = max(1, (len(words) - 1).bit_length() // 4 + 1)
    lines: list[str] = []
    lines.append(f"WIDTH={WORD_BITS};")
    lines.append(f"DEPTH={len(words)};")
    lines.append("")
    lines.append("ADDRESS_RADIX=HEX;")
    lines.append("DATA_RADIX=HEX;")
    lines.append("")
    lines.append("CONTENT BEGIN")
    for addr, w in enumerate(words):
        lines.append(f"    {addr:0{addr_chars}X} : {w:0{hex_chars}X};")
    lines.append("END;")
    path.write_text("\n".join(lines) + "\n")


def write_expected(path: Path, expected: list[int]) -> None:
    lines = [f"{e:02x}" for e in expected]
    path.write_text("\n".join(lines) + "\n")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    vectors = deterministic_vectors() + random_vectors(DEPTH - 4, seed=0)
    assert len(vectors) == DEPTH

    words: list[int] = []
    expected: list[int] = []
    print(f"{'addr':>4} {'key':>4} {'matrix':>6} {'packed':>8} {'expected':>8}")
    for addr, (key, mw) in enumerate(vectors):
        w = pack(key, mw)
        e = compress(key, mw)
        words.append(w)
        expected.append(e)
        print(f"{addr:>4} {key:#04x} {mw:#06x} {w:#08x} {e:#04x}")

    write_mif(MIF_PATH, words)
    write_expected(EXPECTED_PATH, expected)

    print(f"\nWrote {MIF_PATH}")
    print(f"Wrote {EXPECTED_PATH}")


if __name__ == "__main__":
    main()
