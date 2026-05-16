"""Modelo de referencia Toeplitz parametrizavel (W, P) para a compression_unit.

Espelha o algoritmo de toeplitz_hash.py (32-bit) parametrizando para os
valores usados pelo testbench de validacao (W=P=8 por default).

Construcao da matriz T de shape (P, W) a partir do matrix_window (W+P-1 bits),
com bits indexados em LSB-first:

    first_row[j] = matrix_window[j]            para j em [0, W)
    first_col[0] = matrix_window[0]
    first_col[i] = matrix_window[W + i - 1]    para i em [1, P)
    T = toeplitz(first_col, first_row)

A operacao calculada e:

    hash = (T @ key) mod 2

com key de W bits e hash de P bits.
"""

from __future__ import annotations

import numpy as np
from numpy.typing import NDArray
from scipy.linalg import toeplitz

DEFAULT_W = 8
DEFAULT_P = 8


def int_to_bits(value: int, width: int) -> NDArray[np.uint8]:
    """Inteiro -> vetor binario LSB-first. Bit 0 do valor -> indice 0."""
    return np.array([(value >> i) & 1 for i in range(width)], dtype=np.uint8)


def bits_to_int(bits: NDArray[np.uint8]) -> int:
    """Vetor binario LSB-first -> inteiro. Inverso de int_to_bits."""
    result = 0
    for i, b in enumerate(bits):
        result |= int(b) << i
    return result


def build_toeplitz_matrix(
    matrix_window: int,
    *,
    W: int = DEFAULT_W,
    P: int = DEFAULT_P,
) -> NDArray[np.uint8]:
    """Constroi a matriz Toeplitz P x W a partir do matrix_window (W+P-1 bits)."""
    mw_bits = int_to_bits(matrix_window, W + P - 1)
    first_row = mw_bits[:W]
    first_col = np.empty(P, dtype=np.uint8)
    first_col[0] = mw_bits[0]
    first_col[1:] = mw_bits[W : W + P - 1]
    return toeplitz(first_col, first_row).astype(np.uint8)


def compress(
    key: int,
    matrix_window: int,
    *,
    W: int = DEFAULT_W,
    P: int = DEFAULT_P,
) -> int:
    """Calcula hash de P bits aplicando (T @ key) mod 2 via numpy."""
    mw_width = W + P - 1
    if not 0 <= key < (1 << W):
        raise ValueError(f"key fora do range de {W} bits: {key:#x}")
    if not 0 <= matrix_window < (1 << mw_width):
        raise ValueError(
            f"matrix_window fora do range de {mw_width} bits: {matrix_window:#x}"
        )

    key_bits = int_to_bits(key, W)
    T = build_toeplitz_matrix(matrix_window, W=W, P=P)
    hash_bits = (T @ key_bits) % 2
    return bits_to_int(hash_bits)
