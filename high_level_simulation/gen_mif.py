from __future__ import annotations

import random
from pathlib import Path

from compression_model import P, W, compress

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "src" / "tb_mem_validation"
MIF_PATH = OUT_DIR / "input_vectors.mif"
EXPECTED_PATH = OUT_DIR / "expected_outputs.hex"

DEPTH = 16
MATRIX_WINDOW_BITS = W + P - 1
WORD_BITS = W + MATRIX_WINDOW_BITS


def deterministic_vectors():
    return [
        (0x00, 0x0000),
        (0xFF, 0x7FFF),
        (0x01, 0x0001),
        (0xAA, 0x5555),
    ]


def random_vectors(n, seed=0):
    rng = random.Random(seed)
    return [
        (rng.randint(0, (1 << W) - 1), rng.randint(0, (1 << MATRIX_WINDOW_BITS) - 1))
        for _ in range(n)
    ]


def pack(key, matrix_window):
    return (matrix_window << W) | key


def write_mif(path, words):
    hex_chars = (WORD_BITS + 3) // 4
    addr_chars = max(1, (len(words) - 1).bit_length() // 4 + 1)
    lines = [
        f"WIDTH={WORD_BITS};",
        f"DEPTH={len(words)};",
        "",
        "ADDRESS_RADIX=HEX;",
        "DATA_RADIX=HEX;",
        "",
        "CONTENT BEGIN",
    ]
    for addr, w in enumerate(words):
        lines.append(f"    {addr:0{addr_chars}X} : {w:0{hex_chars}X};")
    lines.append("END;")
    path.write_text("\n".join(lines) + "\n")


def write_expected(path, expected):
    path.write_text("\n".join(f"{e:02x}" for e in expected) + "\n")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    vectors = deterministic_vectors() + random_vectors(DEPTH - 4)

    words, expected = [], []
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
