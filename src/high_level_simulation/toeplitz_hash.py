"""
Toeplitz hash model for privacy amplification in QKD.

Computes h = (T @ a) mod 2, where T is a 32x32 Toeplitz matrix
built from a 63-element binary seed and a is a 32-bit key vector.

This is the Python equivalent of compression_unit.v / hash_engine.v.
"""

from __future__ import annotations

import numpy as np
from numpy.typing import NDArray
from scipy.linalg import toeplitz

KEY_BITS = 32
OUTPUT_BITS = 32
SEED_BITS = KEY_BITS + OUTPUT_BITS - 1  # 63


def build_toeplitz_matrix(seed: NDArray[np.uint8]) -> NDArray[np.uint8]:
    """Build 32x32 binary Toeplitz matrix from 63-element seed.

    Seed layout::

        first_row = seed[0:32]
        first_col = [seed[0], seed[32], ..., seed[62]]

    Resulting matrix (constant descending diagonals)::

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
    """Compute full 32-bit Toeplitz hash: (T @ key) mod 2."""
    T = build_toeplitz_matrix(seed)
    return (T @ key) % 2
