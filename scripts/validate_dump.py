"""Compara o dump da simulacao (output_dump.hex) com expected_outputs.txt.

Ambos sao arquivos com uma palavra hex por linha (formato compativel com
$writememh do Verilog). Imprime tabela e termina com exit code 0 em sucesso,
1 em falha.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DUMP = ROOT / "src" / "tb_mem_validation" / "sim" / "output_dump.hex"
EXPECTED = ROOT / "src" / "tb_mem_validation" / "expected_outputs.hex"


def read_hex_lines(path: Path) -> list[int]:
    out: list[int] = []
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("//") or line.startswith("@"):
            continue
        out.append(int(line, 16))
    return out


def main() -> int:
    if not DUMP.exists():
        print(f"ERROR: dump nao encontrado: {DUMP}", file=sys.stderr)
        return 1
    if not EXPECTED.exists():
        print(f"ERROR: expected nao encontrado: {EXPECTED}", file=sys.stderr)
        return 1

    got = read_hex_lines(DUMP)
    exp = read_hex_lines(EXPECTED)

    if len(got) != len(exp):
        print(
            f"ERROR: tamanhos diferentes: dump={len(got)} expected={len(exp)}",
            file=sys.stderr,
        )
        return 1

    fails = 0
    print(f"{'addr':>4} {'got':>4} {'expected':>10} {'status':>8}")
    for i, (g, e) in enumerate(zip(got, exp)):
        ok = g == e
        if not ok:
            fails += 1
        print(f"{i:>4} {g:#04x} {e:#10x} {'PASS' if ok else 'FAIL':>8}")

    print()
    if fails:
        print(f"FAIL: {fails}/{len(exp)} divergencias")
        return 1
    print(f"PASS: {len(exp)}/{len(exp)} vetores ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
