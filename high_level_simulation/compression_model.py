"""Modelo de referencia parametrizavel para a compression_unit (v1).

O hardware (src/compression_unit.v + src/hash_engine.v) calcula, para cada
engine i em [0, P):

    hash_out[i] = XOR_j ( key[j] AND matrix_window[i + j] )    com j em [0, W)

Em forma matricial sobre GF(2):

    hash_out = (M @ key) mod 2

onde M tem shape (P, W) e M[i, j] = matrix_window_bits[i + j]. As anti-
diagonais de M sao constantes -> M e uma matriz de **Hankel**, construida
aqui via scipy.linalg.hankel.

Defaults W=8, P=8 sao os usados pelo testbench de validacao
src/tb_mem_validation/top_mem_tb.v.
"""

from __future__ import annotations

import numpy as np
from numpy.typing import NDArray
from scipy.linalg import hankel

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


def build_hash_matrix(
    matrix_window: int,
    *,
    W: int = DEFAULT_W,
    P: int = DEFAULT_P,
) -> NDArray[np.uint8]:
    """Constroi a matriz P x W de Hankel: M[i, j] = matrix_window_bits[i + j]."""
    mw_width = W + P - 1
    bits = int_to_bits(matrix_window, mw_width)
    return hankel(bits[:P], bits[P - 1 : P + W - 1]).astype(np.uint8)


def compress(
    key: int,
    matrix_window: int,
    *,
    W: int = DEFAULT_W,
    P: int = DEFAULT_P,
) -> int:
    """Calcula hash_out de P bits aplicando (M @ key) mod 2 via numpy."""
    mw_width = W + P - 1
    if not 0 <= key < (1 << W):
        raise ValueError(f"key fora do range de {W} bits: {key:#x}")
    if not 0 <= matrix_window < (1 << mw_width):
        raise ValueError(
            f"matrix_window fora do range de {mw_width} bits: {matrix_window:#x}"
        )

    key_bits = int_to_bits(key, W)
    M = build_hash_matrix(matrix_window, W=W, P=P)
    hash_bits = (M @ key_bits) % 2
    return bits_to_int(hash_bits)
