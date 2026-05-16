"""Valida o dump da simulacao contra a referencia numpy/scipy.

Para cada entrada de src/tb_mem_validation/input_vectors.mif (a mesma ROM
carregada pelo testbench), recomputa o hash esperado usando
compression_model.compress (matriz de Hankel via scipy + matmul numpy) e
compara com o byte correspondente em src/tb_mem_validation/sim/output_dump.hex
(gerado por $writememh apos a simulacao).

Termina com exit 0 se todos os vetores baterem, 1 caso contrario.
"""

from __future__ import annotations

import sys
from pathlib import Path

from compression_model import DEFAULT_P as P
from compression_model import DEFAULT_W as W
from compression_model import compress

ROOT = Path(__file__).resolve().parent.parent
TB_DIR = ROOT / "src" / "tb_mem_validation"
MIF = TB_DIR / "input_vectors.mif"
DUMP = TB_DIR / "sim" / "output_dump.hex"

MATRIX_WINDOW_BITS = W + P - 1
WORD_BITS = W + MATRIX_WINDOW_BITS


def parse_mif_data(path: Path) -> list[int]:
    """Le o bloco CONTENT do .mif e retorna palavras em ordem de endereco."""
    text = path.read_text()
    in_content = False
    words: dict[int, int] = {}
    for raw in text.splitlines():
        line = raw.strip()
        upper = line.upper()
        if upper.startswith("CONTENT"):
            in_content = True
            continue
        if upper.startswith("END"):
            break
        if not in_content or ":" not in line:
            continue
        addr_str, rest = line.split(":", 1)
        val_str = rest.strip().rstrip(";").strip()
        addr = int(addr_str.strip(), 16)
        val = int(val_str, 16)
        words[addr] = val
    return [words[i] for i in sorted(words)]


def parse_hex_dump(path: Path) -> list[int]:
    """Le um dump no formato de $writememh (uma palavra hex por linha)."""
    out: list[int] = []
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("//") or line.startswith("@"):
            continue
        out.append(int(line, 16))
    return out


def main() -> int:
    if not MIF.exists():
        print(f"ERROR: mif nao encontrado: {MIF}", file=sys.stderr)
        return 1
    if not DUMP.exists():
        print(f"ERROR: dump nao encontrado: {DUMP}", file=sys.stderr)
        return 1

    words = parse_mif_data(MIF)
    got = parse_hex_dump(DUMP)

    if len(words) != len(got):
        print(
            f"ERROR: tamanhos diferentes: mif={len(words)} dump={len(got)}",
            file=sys.stderr,
        )
        return 1

    key_mask = (1 << W) - 1
    mw_mask = (1 << MATRIX_WINDOW_BITS) - 1

    fails = 0
    print(f"{'addr':>4} {'key':>4} {'matrix':>6} {'got':>4} {'expected':>8}  status")
    for addr, (word, g) in enumerate(zip(words, got)):
        key = word & key_mask
        mw = (word >> W) & mw_mask
        expected = compress(key, mw)
        ok = g == expected
        if not ok:
            fails += 1
        print(
            f"{addr:>4} {key:#04x} {mw:#06x} {g:#04x} {expected:#04x} "
            f"{'PASS' if ok else 'FAIL':>6}"
        )

    print()
    if fails:
        print(f"FAIL: {fails}/{len(words)} divergencias")
        return 1
    print(f"PASS: {len(words)}/{len(words)} vetores ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
