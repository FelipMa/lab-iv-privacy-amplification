import random

def toeplitz_hash_slice(key, matrix_window, W, P):
    hash_out = 0
    for i in range(P):
        matrix_slice = (matrix_window >> i) & ((1 << W) - 1)
        and_res = key & matrix_slice
        xor_sum = 0
        while and_res > 0:
            xor_sum ^= (and_res & 1)
            and_res >>= 1
        hash_out |= (xor_sum << i)
    return hash_out

def main():
    W = 64
    P = 64
    key = 0x3A7D9E4B2F5C8A10
    matrix_window = 0x5E8A9B1C3D2E4F0A7B6C5D4E3F2A1B0C & ((1 << (W + P - 1)) - 1)
    
    expected_hash = toeplitz_hash_slice(key, matrix_window, W, P)
    
    print(f"Key:            0x{key:016X}")
    print(f"Matrix Window:  0x{matrix_window:032X}")
    print(f"Expected Hash:  0x{expected_hash:016X}")
    print(f"Upper 32 bits:  0x{(expected_hash >> 32) & 0xFFFFFFFF:08X}")
    print(f"Lower 32 bits:  0x{expected_hash & 0xFFFFFFFF:08X}")

if __name__ == "__main__":
    main()
