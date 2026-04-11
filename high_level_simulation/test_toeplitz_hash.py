"""
Testes do modelo de hash Toeplitz.

Vetores de teste deterministicos usando inteiros hexadecimais.
As mesmas entradas/saidas podem ser usadas nos testbenches Verilog
para verificar que ambas implementacoes concordam.
"""

import pytest
import numpy as np

from toeplitz_hash import (
    KEY_BITS,
    SEED_BITS,
    bits_to_int,
    int_to_bits,
    toeplitz_hash,
)


@pytest.mark.parametrize(
    "seed_hex, key_hex, expected_hex",
    [
        (0x0000000000000000, 0x00000000, 0x00000000),
        (0x7FFFFFFFFFFFFFFF, 0xFFFFFFFF, 0x00000000),
        (0x0000000000000001, 0x00000001, 0x00000001),
        (0x5555555555555555, 0xAAAAAAAA, 0xCCCCCCCC),
        (0x01234567890ABCDE, 0xDEADBEEF, 0x894C0251),
        (0x7FFFFFFFFFFFFFFF, 0x00000001, 0xFFFFFFFF),
        (0x3A5C6F8912DE4B70, 0xCAFEBABE, 0x090B2525),
    ],
)
def test_toeplitz_hash(seed_hex, key_hex, expected_hex):
    seed = int_to_bits(seed_hex, SEED_BITS)
    key = int_to_bits(key_hex, KEY_BITS)
    h = toeplitz_hash(key, seed)
    result = bits_to_int(h)
    assert result == expected_hex, (
        f"seed=0x{seed_hex:016X} key=0x{key_hex:08X}: "
        f"got 0x{result:08X}, expected 0x{expected_hex:08X}"
    )
