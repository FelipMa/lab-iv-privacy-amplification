"""Modelo de referencia (W=8, P=8) para a compression_unit v1.

Replica, bit a bit, o comportamento de src/compression_unit.v + src/hash_engine.v:

    Para cada engine i em [0, P):
        hash_out[i] = popcount(key & matrix_window[i +: W]) mod 2

onde W=8 e matrix_window tem W+P-1 = 15 bits.
"""

from __future__ import annotations

W = 8
P = 8
MATRIX_WINDOW_BITS = W + P - 1  # 15


def _slice(matrix_window: int, i: int) -> int:
    """Equivalente Verilog: matrix_window[i +: W]."""
    return (matrix_window >> i) & ((1 << W) - 1)


def compress(key: int, matrix_window: int) -> int:
    """Compute hash_out de P=8 bits para um par (key, matrix_window).

    key:           8 bits
    matrix_window: 15 bits
    retorno:       inteiro 0..255 cujo bit i corresponde a hash_out[i]
    """
    if not 0 <= key < (1 << W):
        raise ValueError(f"key fora do range de {W} bits: {key:#x}")
    if not 0 <= matrix_window < (1 << MATRIX_WINDOW_BITS):
        raise ValueError(
            f"matrix_window fora do range de {MATRIX_WINDOW_BITS} bits: {matrix_window:#x}"
        )

    result = 0
    for i in range(P):
        anded = key & _slice(matrix_window, i)
        parity = bin(anded).count("1") & 1
        result |= parity << i
    return result
