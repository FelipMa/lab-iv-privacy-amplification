from __future__ import annotations

import sys
from pathlib import Path

from compression_model import P, W, compress

ROOT = Path(__file__).resolve().parent.parent
TB_DIR = ROOT / "src" / "tb_mem_validation"
MIF = TB_DIR / "input_vectors.mif"
DUMP = TB_DIR / "sim" / "output_dump.hex"

MATRIX_WINDOW_BITS = W + P - 1


def parse_mif_data(path):
    text = path.read_text()
    in_content = False
    words = {}
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
        words[int(addr_str.strip(), 16)] = int(rest.strip().rstrip(";").strip(), 16)
    return [words[i] for i in sorted(words)]


def parse_hex_dump(path):
    out = []
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("//") or line.startswith("@"):
            continue
        out.append(int(line, 16))
    return out


def main():
    words = parse_mif_data(MIF)
    got = parse_hex_dump(DUMP)

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
