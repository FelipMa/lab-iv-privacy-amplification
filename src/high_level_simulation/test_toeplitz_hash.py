"""
Tests for the Toeplitz hash model.

These tests verify the Python reference model independently.
The Verilog testbenches verify the hardware separately.
Both should agree on the same test vectors.
"""

import random

import numpy as np

from toeplitz_hash import (
    KEY_BITS,
    OUTPUT_BITS,
    SEED_BITS,
    build_toeplitz_matrix,
    toeplitz_hash,
)


class TestToeplitzHash:
    def test_row_by_row_matches_matmul(self):
        """Explicit loop vs matmul for random inputs."""
        rng = random.Random(55)
        for _ in range(50):
            seed = np.array(
                [rng.randint(0, 1) for _ in range(SEED_BITS)], dtype=np.uint8
            )
            key = np.array(
                [rng.randint(0, 1) for _ in range(KEY_BITS)], dtype=np.uint8
            )
            T = build_toeplitz_matrix(seed)
            h = toeplitz_hash(key, seed)

            for i in range(OUTPUT_BITS):
                expected_bit = sum(T[i, j] * key[j] for j in range(KEY_BITS)) % 2
                assert h[i] == expected_bit
