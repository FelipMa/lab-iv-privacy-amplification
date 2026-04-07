"""
Tests for the Toeplitz hash model.

Independent reference using scipy.linalg.toeplitz + numpy matmul.
Verilog cross-checks apply the Hankel-to-Toeplitz seed mapping at
the test boundary only.
"""

import random

import numpy as np
import pytest

from toeplitz_hash import (
    KEY_BITS,
    OUTPUT_BITS,
    SEED_BITS,
    bits_to_int,
    build_toeplitz_matrix,
    int_to_bits,
    toeplitz_hash,
)


# -- int_to_bits / bits_to_int ------------------------------------ #

class TestIntBitsConversion:

    @pytest.mark.parametrize(
        "value, width, expected_bits",
        [
            (0x0, 4, [0, 0, 0, 0]),
            (0xF, 4, [1, 1, 1, 1]),
            (0xA, 4, [0, 1, 0, 1]),       # 1010 -> LSB-first: [0,1,0,1]
            (0x1, 32, [1] + [0] * 31),
            (0x8000_0000, 32, [0] * 31 + [1]),
            (0xFFFF_FFFF, 32, [1] * 32),
        ],
    )
    def test_int_to_bits_known(self, value, width, expected_bits):
        result = int_to_bits(value, width)
        np.testing.assert_array_equal(result, expected_bits)
        assert result.dtype == np.uint8

    def test_round_trip(self):
        rng = random.Random(42)
        for width in [1, 4, 8, 16, 32, 63]:
            for _ in range(200):
                value = rng.getrandbits(width)
                assert bits_to_int(int_to_bits(value, width)) == value

    def test_masks_excess_bits(self):
        bits = int_to_bits(0x1_0000_0001, 32)
        assert bits_to_int(bits) == 1


# -- build_toeplitz_matrix ----------------------------------------- #

class TestBuildToeplitzMatrix:

    def test_shape(self):
        seed = np.zeros(SEED_BITS, dtype=np.uint8)
        T = build_toeplitz_matrix(seed)
        assert T.shape == (OUTPUT_BITS, KEY_BITS)
        assert T.dtype == np.uint8

    def test_toeplitz_property(self):
        """Constant descending diagonals."""
        rng = random.Random(77)
        for _ in range(50):
            seed = np.array(
                [rng.randint(0, 1) for _ in range(SEED_BITS)], dtype=np.uint8
            )
            T = build_toeplitz_matrix(seed)
            for i in range(T.shape[0] - 1):
                for j in range(T.shape[1] - 1):
                    assert T[i, j] == T[i + 1, j + 1]

    def test_first_row_from_seed(self):
        """First row == seed[0:32]."""
        rng = random.Random(10)
        for _ in range(50):
            seed = np.array(
                [rng.randint(0, 1) for _ in range(SEED_BITS)], dtype=np.uint8
            )
            T = build_toeplitz_matrix(seed)
            np.testing.assert_array_equal(T[0], seed[:KEY_BITS])

    def test_first_col_from_seed(self):
        """First col == [seed[0], seed[32], ..., seed[62]]."""
        rng = random.Random(20)
        for _ in range(50):
            seed = np.array(
                [rng.randint(0, 1) for _ in range(SEED_BITS)], dtype=np.uint8
            )
            T = build_toeplitz_matrix(seed)
            expected_col = np.empty(OUTPUT_BITS, dtype=np.uint8)
            expected_col[0] = seed[0]
            expected_col[1:] = seed[KEY_BITS:]
            np.testing.assert_array_equal(T[:, 0], expected_col)

    def test_binary_only(self):
        seed = np.ones(SEED_BITS, dtype=np.uint8)
        T = build_toeplitz_matrix(seed)
        assert set(np.unique(T)).issubset({0, 1})


# -- Manual row-by-row: b_i = sum(T[i,j]*a[j]) mod 2 ------------- #

class TestToeplitzHashManual:

    def test_small_manual_example(self):
        """Known seed+key, verify output == first column."""
        # first_row = alternating [1,0,...], first_col_rest = [1,1,1,0,...,0]
        first_row = np.array([1, 0] * 16, dtype=np.uint8)
        first_col_rest = np.zeros(31, dtype=np.uint8)
        first_col_rest[:3] = 1
        seed = np.concatenate([first_row, first_col_rest])

        # key = [1, 0, ..., 0] -> output = first column of T
        key = np.zeros(KEY_BITS, dtype=np.uint8)
        key[0] = 1

        h = toeplitz_hash(key, seed)

        expected_col = np.empty(OUTPUT_BITS, dtype=np.uint8)
        expected_col[0] = seed[0]
        expected_col[1:] = seed[KEY_BITS:]
        np.testing.assert_array_equal(h, expected_col)

    def test_identity_like_seed(self):
        """seed=[1,0,...,0] -> identity matrix -> hash(key) == key."""
        seed = np.zeros(SEED_BITS, dtype=np.uint8)
        seed[0] = 1
        T = build_toeplitz_matrix(seed)
        np.testing.assert_array_equal(T, np.eye(32, dtype=np.uint8))

        rng = random.Random(99)
        for _ in range(50):
            key = np.array(
                [rng.randint(0, 1) for _ in range(KEY_BITS)], dtype=np.uint8
            )
            np.testing.assert_array_equal(toeplitz_hash(key, seed), key)

    def test_row_by_row_dot_product(self):
        """Explicit loop vs matmul for 200 random inputs."""
        rng = random.Random(55)
        for _ in range(200):
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


# -- Full 32-bit output ------------------------------------------- #

class TestFullOutput:

    def test_always_32_bits(self):
        seed = np.zeros(SEED_BITS, dtype=np.uint8)
        key = np.zeros(KEY_BITS, dtype=np.uint8)
        assert toeplitz_hash(key, seed).shape == (32,)

    def test_all_zeros(self):
        seed = np.zeros(SEED_BITS, dtype=np.uint8)
        key = np.zeros(KEY_BITS, dtype=np.uint8)
        np.testing.assert_array_equal(
            toeplitz_hash(key, seed), np.zeros(OUTPUT_BITS, dtype=np.uint8)
        )

    def test_all_ones_even_parity(self):
        """All-ones: 32 set bits per row -> even parity -> 0."""
        seed = np.ones(SEED_BITS, dtype=np.uint8)
        key = np.ones(KEY_BITS, dtype=np.uint8)
        np.testing.assert_array_equal(
            toeplitz_hash(key, seed), np.zeros(OUTPUT_BITS, dtype=np.uint8)
        )

    def test_result_is_binary(self):
        rng = random.Random(88)
        for _ in range(100):
            seed = np.array(
                [rng.randint(0, 1) for _ in range(SEED_BITS)], dtype=np.uint8
            )
            key = np.array(
                [rng.randint(0, 1) for _ in range(KEY_BITS)], dtype=np.uint8
            )
            h = toeplitz_hash(key, seed)
            assert h.dtype == np.uint8
            assert set(np.unique(h)).issubset({0, 1})


# -- Verilog cross-check ------------------------------------------ #
#
# Verilog uses a Hankel sliding window; Python uses standard Toeplitz.
# Equivalence:  H @ k  =  T @ reverse(k)   (mod 2)
# with:  first_row = reverse(verilog_seed[0:32])
#        first_col = verilog_seed[31:63]

def _verilog_to_toeplitz_args(
    verilog_key: int,
    verilog_matrix_window: int,
) -> tuple[np.ndarray, np.ndarray]:
    """Map Verilog integers to (key_array, seed_array) for toeplitz_hash."""
    verilog_seed = int_to_bits(verilog_matrix_window, SEED_BITS)

    first_row = verilog_seed[:KEY_BITS][::-1]
    first_col_rest = verilog_seed[KEY_BITS:]
    python_seed = np.concatenate([first_row, first_col_rest])
    python_key = int_to_bits(verilog_key, KEY_BITS)[::-1].copy()

    return python_key, python_seed


class TestVerilogCrossCheck:
    """Cross-check against deterministic Verilog TB vectors.
    Compares relevant output bits (0..P-1) only.
    """

    # -- hash_engine_tb.v (single output bit) --------------------------

    @pytest.mark.parametrize(
        "verilog_key, verilog_matrix, expected_bit, description",
        [
            (0x0000_0000, 0x0000_0000, 0, "Zeros"),
            (0xFFFF_FFFF, 0xFFFF_FFFF, 0, "All ones (even parity)"),
            (0x0000_0001, 0x0000_0001, 1, "Single bit active"),
            (0xAAAA_AAAA, 0x5555_5555, 0, "No overlap"),
            (0x0000_0003, 0x0000_0003, 0, "2 bits even"),
            (0x0000_0007, 0x0000_0007, 1, "3 bits odd"),
        ],
    )
    def test_hash_engine_vectors(
        self, verilog_key, verilog_matrix, expected_bit, description
    ):
        key, seed = _verilog_to_toeplitz_args(verilog_key, verilog_matrix)
        h = toeplitz_hash(key, seed)
        assert h[0] == expected_bit, description

    # -- compression_unit_tb.v (P=4) -----------------------------------

    @pytest.mark.parametrize(
        "verilog_key, verilog_mw, expected_packed, description",
        [
            (0x0000_0000, 0x0000_0000_0000_0000, 0b0000, "Zeros"),
            (0xFFFF_FFFF, 0x7FFF_FFFF_FFFF_FFFF, 0b0000, "All ones"),
            (0x0000_0001, 0x0000_0000_0000_0001, 0b0001, "Only bit 0"),
            (0xAAAA_AAAA, 0x5555_5555_5555_5555, 0b0000, "Alternating"),
            (0x0000_0001, 0x0000_0000_0000_000A, 0b1010, "Sliding window LSB"),
            (0x8000_0000, 0x0000_0004_8000_0000, 0b1001, "Sliding window MSB"),
        ],
    )
    def test_compression_unit_vectors(
        self, verilog_key, verilog_mw, expected_packed, description
    ):
        P = 4
        key, seed = _verilog_to_toeplitz_args(verilog_key, verilog_mw)
        h = toeplitz_hash(key, seed)
        result_packed = bits_to_int(h[:P])
        assert result_packed == expected_packed, (
            f"{description}: got {result_packed:#06b}, expected {expected_packed:#06b}"
        )

    def test_random_cross_check(self):
        """2000 random inputs: Python model vs naive Verilog algorithm."""
        rng = random.Random(42)
        for _ in range(2000):
            verilog_key = rng.getrandbits(32)
            verilog_mw = rng.getrandbits(63)

            # Naive Verilog: XOR-reduce(key AND window[i +: 32]) per bit
            naive_result = []
            for i in range(OUTPUT_BITS):
                row = (verilog_mw >> i) & 0xFFFF_FFFF
                bit = bin(verilog_key & row).count("1") % 2
                naive_result.append(bit)

            key, seed = _verilog_to_toeplitz_args(verilog_key, verilog_mw)
            h = toeplitz_hash(key, seed)

            np.testing.assert_array_equal(
                h[:OUTPUT_BITS], naive_result,
                err_msg=f"key=0x{verilog_key:08X}, mw=0x{verilog_mw:016X}",
            )
