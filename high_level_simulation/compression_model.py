from __future__ import annotations

import numpy as np
from scipy.linalg import toeplitz

W = 8
P = 8


def int_to_bits(value, width):
    return np.array([(value >> i) & 1 for i in range(width)], dtype=np.uint8)


def bits_to_int(bits):
    result = 0
    for i, b in enumerate(bits):
        result |= int(b) << i
    return result


def build_toeplitz_matrix(matrix_window):
    mw_bits = int_to_bits(matrix_window, W + P - 1)
    first_row = mw_bits[:W]
    first_col = np.empty(P, dtype=np.uint8)
    first_col[0] = mw_bits[0]
    first_col[1:] = mw_bits[W : W + P - 1]
    return toeplitz(first_col, first_row).astype(np.uint8)


def compress(key, matrix_window):
    key_bits = int_to_bits(key, W)
    T = build_toeplitz_matrix(matrix_window)
    return bits_to_int((T @ key_bits) % 2)
