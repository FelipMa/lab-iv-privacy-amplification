"""
Modelo de hash Toeplitz para amplificacao de privacidade em QKD.

Calcula h = (T @ a) mod 2, onde T e uma matriz Toeplitz 32x32 binaria
construida a partir de uma seed de 63 elementos, e a e um vetor chave de 32 bits.

Equivalente em Python de compression_unit.v / hash_engine.v.
"""

from __future__ import annotations

import numpy as np
from numpy.typing import NDArray
from scipy.linalg import toeplitz

KEY_BITS = 32
OUTPUT_BITS = 32
SEED_BITS = KEY_BITS + OUTPUT_BITS - 1  # 63


def build_toeplitz_matrix(seed: NDArray[np.uint8]) -> NDArray[np.uint8]:
    """Constroi matriz Toeplitz 32x32 binaria a partir de uma seed de 63 elementos.

    Layout da seed::

        primeira_linha = seed[0:32]
        primeira_coluna = [seed[0], seed[32], ..., seed[62]]

    Matriz resultante (diagonais descendentes constantes)::

        T = | s0   s1   ...  s31  |
            | s32  s0   ...  s30  |
            | ...                 |
            | s62  s61  ...  s0   |
    """
    first_row = seed[:KEY_BITS]
    first_col = np.empty(OUTPUT_BITS, dtype=np.uint8)
    first_col[0] = seed[0]
    first_col[1:] = seed[KEY_BITS:]

    return toeplitz(first_col, first_row).astype(np.uint8)


def toeplitz_hash(
    key: NDArray[np.uint8],
    seed: NDArray[np.uint8],
) -> NDArray[np.uint8]:
    """Calcula hash Toeplitz completo de 32 bits: (T @ key) mod 2."""
    T = build_toeplitz_matrix(seed)
    return (T @ key) % 2


def int_to_bits(value: int, width: int) -> NDArray[np.uint8]:
    """Inteiro para vetor binario LSB-first. Bit 0 do valor -> indice 0."""
    return np.array([(value >> i) & 1 for i in range(width)], dtype=np.uint8)


def bits_to_int(bits: NDArray[np.uint8]) -> int:
    """Vetor binario LSB-first para inteiro. Inverso de int_to_bits."""
    result = 0
    for i, b in enumerate(bits):
        result |= int(b) << i
    return result
