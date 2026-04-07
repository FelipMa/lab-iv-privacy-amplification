"""
Parser and cross-checker for Verilog testbench simulation output.

Parses stdout from hash_engine_tb or compression_unit_tb, extracts
test results, and verifies them against the Python Toeplitz hash model.

Usage:
    python verilog_output_parser.py < sim_output.txt
    python verilog_output_parser.py sim_output.txt
    python verilog_output_parser.py --tb hash_engine sim_output.txt
    python verilog_output_parser.py --tb compression_unit sim_output.txt

Exit 0 = all agree, exit 1 = mismatch found.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from typing import TextIO

import numpy as np

from toeplitz_hash import (
    KEY_BITS,
    OUTPUT_BITS,
    SEED_BITS,
    bits_to_int,
    int_to_bits,
    toeplitz_hash,
)


# -- Data structures ----------------------------------------------- #

@dataclass
class HashEngineResult:
    status: str          # "PASS" or "FAIL"
    label: str
    key: int
    matrix: int
    actual: int          # hash_b from RTL
    expected: int

@dataclass
class CompressionUnitResult:
    status: str
    label: str
    actual: int          # hash_out (packed)
    expected: int
    key: int | None = None
    matrix_window: int | None = None

@dataclass
class VerificationReport:
    total: int = 0
    verilog_pass: int = 0
    verilog_fail: int = 0
    python_agree: int = 0
    python_disagree: int = 0
    details: list[str] = field(default_factory=list)


# -- Regex patterns ------------------------------------------------ #

# [PASS] label | key=0x... matrix=0x... | hash_b=X (esperado=X)
_RE_HE_FULL = re.compile(
    r"\[(PASS|FAIL)\]\s+(.+?)\s*\|\s*key=0x([0-9A-Fa-f]+)\s+matrix=0x([0-9A-Fa-f]+)"
    r"\s*\|\s*hash_b=([01])\s*\(esperado=([01])\)"
)

# [PASS] Reset... | hash_b=0 apos reset
_RE_HE_RESET = re.compile(
    r"\[(PASS|FAIL)\]\s+(Reset.*?)\s*\|\s*hash_b=([01])"
)

# [PASS] label | hash_out=BBBB (esperado=BBBB)
_RE_CU_PASS = re.compile(
    r"\[(PASS|FAIL)\]\s+(.+?)\s*\|\s*hash_out=([01]+)\s*\(esperado=([01]+)\)"
)

# [FAIL] label | hash_out=BBBB (esperado=BBBB) | key=0x... mat=0x...
_RE_CU_FAIL = re.compile(
    r"\[(PASS|FAIL)\]\s+(.+?)\s*\|\s*hash_out=([01]+)\s*\(esperado=([01]+)\)"
    r"\s*\|\s*key=0x([0-9A-Fa-f]+)\s+mat=0x([0-9A-Fa-f]+)"
)

# [PASS] Reset... | hash_out=0 apos reset
_RE_CU_RESET = re.compile(
    r"\[(PASS|FAIL)\]\s+(Reset.*?)\s*\|\s*hash_out=([01]+)\s*apos reset"
)


# -- Parsing ------------------------------------------------------- #

def _bin_str_to_int(s: str) -> int:
    """Binary string (MSB-first, as Verilog %b prints) to integer."""
    return int(s, 2)


def parse_hash_engine_output(text: str) -> list[HashEngineResult]:
    results: list[HashEngineResult] = []
    for line in text.splitlines():
        m = _RE_HE_FULL.search(line)
        if m:
            results.append(HashEngineResult(
                status=m.group(1), label=m.group(2).strip(),
                key=int(m.group(3), 16), matrix=int(m.group(4), 16),
                actual=int(m.group(5)), expected=int(m.group(6)),
            ))
            continue
        m = _RE_HE_RESET.search(line)
        if m:
            results.append(HashEngineResult(
                status=m.group(1), label=m.group(2).strip(),
                key=0, matrix=0, actual=int(m.group(3)), expected=0,
            ))
    return results


def parse_compression_unit_output(text: str) -> list[CompressionUnitResult]:
    results: list[CompressionUnitResult] = []
    for line in text.splitlines():
        # FAIL pattern first (superset of PASS pattern)
        m = _RE_CU_FAIL.search(line)
        if m:
            results.append(CompressionUnitResult(
                status=m.group(1), label=m.group(2).strip(),
                actual=_bin_str_to_int(m.group(3)),
                expected=_bin_str_to_int(m.group(4)),
                key=int(m.group(5), 16),
                matrix_window=int(m.group(6), 16),
            ))
            continue
        m = _RE_CU_PASS.search(line)
        if m:
            results.append(CompressionUnitResult(
                status=m.group(1), label=m.group(2).strip(),
                actual=_bin_str_to_int(m.group(3)),
                expected=_bin_str_to_int(m.group(4)),
            ))
            continue
        m = _RE_CU_RESET.search(line)
        if m:
            results.append(CompressionUnitResult(
                status=m.group(1), label=m.group(2).strip(),
                actual=_bin_str_to_int(m.group(3)), expected=0,
            ))
    return results


# -- Hankel-to-Toeplitz mapping ------------------------------------ #

def _verilog_to_toeplitz_args(
    verilog_key: int,
    verilog_matrix_window: int,
    seed_width: int = SEED_BITS,
) -> tuple[np.ndarray, np.ndarray]:
    """Map Verilog integers to (key_array, seed_array) for toeplitz_hash.

    Verilog sliding window is Hankel (T[i,j]=seed[i+j]).
    Equivalence: H @ k = T @ reverse(k)  (mod 2)
    with first_row = reverse(verilog_seed[0:32]),
         first_col = verilog_seed[31:63].
    """
    verilog_seed = int_to_bits(verilog_matrix_window, seed_width)

    first_row = verilog_seed[:KEY_BITS][::-1]
    first_col_rest = verilog_seed[KEY_BITS:]
    python_seed = np.concatenate([first_row, first_col_rest])
    python_key = int_to_bits(verilog_key, KEY_BITS)[::-1].copy()

    return python_key, python_seed


# -- Verification against Python model ----------------------------- #

def verify_hash_engine_results(
    results: list[HashEngineResult],
) -> VerificationReport:
    report = VerificationReport(total=len(results))

    for r in results:
        if r.status == "PASS":
            report.verilog_pass += 1
        else:
            report.verilog_fail += 1

        if "Reset" in r.label:
            if r.actual == 0:
                report.python_agree += 1
            else:
                report.python_disagree += 1
                report.details.append(
                    f"MISMATCH (reset) [{r.label}]: RTL={r.actual}, expected=0"
                )
            continue

        # 32-bit matrix zero-extended to 63 bits
        key, seed = _verilog_to_toeplitz_args(r.key, r.matrix)
        h = toeplitz_hash(key, seed)
        py_bit = int(h[0])

        if py_bit == r.actual:
            report.python_agree += 1
        else:
            report.python_disagree += 1
            report.details.append(
                f"MISMATCH [{r.label}]: key=0x{r.key:08X} matrix=0x{r.matrix:08X} "
                f"RTL={r.actual} Python={py_bit}"
            )
    return report


def verify_compression_unit_results(
    results: list[CompressionUnitResult],
    parallelism: int = 4,
) -> VerificationReport:
    """PASS-only lines (no key/matrix) trust the Verilog TB's own check."""
    report = VerificationReport(total=len(results))

    for r in results:
        if r.status == "PASS":
            report.verilog_pass += 1
        else:
            report.verilog_fail += 1

        if r.key is not None and r.matrix_window is not None:
            key, seed = _verilog_to_toeplitz_args(r.key, r.matrix_window)
            h = toeplitz_hash(key, seed)
            py_packed = bits_to_int(h[:parallelism])

            if py_packed == r.actual:
                report.python_agree += 1
            else:
                report.python_disagree += 1
                report.details.append(
                    f"MISMATCH [{r.label}]: "
                    f"key=0x{r.key:08X} mat=0x{r.matrix_window:016X} "
                    f"RTL={r.actual:#0{parallelism + 2}b} "
                    f"Python={py_packed:#0{parallelism + 2}b}"
                )
        elif "Reset" in r.label:
            if r.actual == 0:
                report.python_agree += 1
            else:
                report.python_disagree += 1
                report.details.append(
                    f"MISMATCH (reset) [{r.label}]: RTL={r.actual}, expected=0"
                )
        else:
            if r.actual == r.expected:
                report.python_agree += 1
            else:
                report.python_disagree += 1
                report.details.append(
                    f"RTL SELF-MISMATCH [{r.label}]: "
                    f"actual={r.actual:#0{parallelism + 2}b} "
                    f"expected={r.expected:#0{parallelism + 2}b}"
                )
    return report


# -- Report printing ----------------------------------------------- #

def print_report(report: VerificationReport, stream: TextIO = sys.stdout) -> None:
    stream.write(f"\n{'=' * 60}\n")
    stream.write(f"  Verification Report\n")
    stream.write(f"{'=' * 60}\n")
    stream.write(f"  Total lines parsed:        {report.total}\n")
    stream.write(f"  Verilog PASS:              {report.verilog_pass}\n")
    stream.write(f"  Verilog FAIL:              {report.verilog_fail}\n")
    stream.write(f"  Python model agrees:       {report.python_agree}\n")
    stream.write(f"  Python model disagrees:    {report.python_disagree}\n")
    stream.write(f"{'=' * 60}\n")

    if report.details:
        stream.write("\n  Mismatch details:\n")
        for d in report.details:
            stream.write(f"    {d}\n")
        stream.write("\n")

    if report.python_disagree == 0 and report.verilog_fail == 0:
        stream.write("  RESULT: ALL OK\n")
    else:
        stream.write("  RESULT: MISMATCHES FOUND\n")
    stream.write(f"{'=' * 60}\n\n")


# -- Auto-detect testbench ---------------------------------------- #

def auto_detect_testbench(text: str) -> str:
    if "hash_out=" in text or "Paralelismo" in text:
        return "compression_unit"
    if "hash_b=" in text:
        return "hash_engine"
    return "unknown"


# -- CLI ----------------------------------------------------------- #

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Cross-check Verilog TB output against Python Toeplitz model.",
    )
    parser.add_argument(
        "file", nargs="?", type=argparse.FileType("r"), default=sys.stdin,
        help="Simulation output file (default: stdin)",
    )
    parser.add_argument(
        "--tb", choices=["hash_engine", "compression_unit", "auto"],
        default="auto", help="Testbench type (default: auto-detect)",
    )
    parser.add_argument(
        "--parallelism", "-p", type=int, default=4,
        help="PARALLELISM parameter for compression_unit_tb (default: 4)",
    )
    args = parser.parse_args()

    text = args.file.read()
    if args.file is not sys.stdin:
        args.file.close()

    tb = args.tb
    if tb == "auto":
        tb = auto_detect_testbench(text)
        if tb == "unknown":
            print("ERROR: Could not auto-detect testbench type. "
                  "Use --tb hash_engine or --tb compression_unit.",
                  file=sys.stderr)
            return 1
        print(f"Auto-detected testbench: {tb}")

    if tb == "hash_engine":
        results = parse_hash_engine_output(text)
        if not results:
            print("WARNING: No test result lines found.", file=sys.stderr)
            return 1
        report = verify_hash_engine_results(results)
    else:
        results = parse_compression_unit_output(text)
        if not results:
            print("WARNING: No test result lines found.", file=sys.stderr)
            return 1
        report = verify_compression_unit_results(results, args.parallelism)

    print_report(report)
    return 0 if (report.python_disagree == 0 and report.verilog_fail == 0) else 1


if __name__ == "__main__":
    sys.exit(main())
