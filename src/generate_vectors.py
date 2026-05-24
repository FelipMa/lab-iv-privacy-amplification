import random

def toeplitz_hash_slice(key, matrix_window, W, P):
    """
    Computes the expected Toeplitz hash for a single key and matrix window.
    key: int (W bits)
    matrix_window: int (W + P - 1 bits)
    W: key size in bits
    P: output hash size in bits (parallelism)
    """
    hash_out = 0
    # Process each bit of the output hash (representing each hash engine)
    for i in range(P):
        # Extract W-bit slice of the matrix window starting at bit i
        # In Verilog: matrix_window[i +: W]
        # In Python: slice from bit i to i+W-1
        matrix_slice = (matrix_window >> i) & ((1 << W) - 1)
        
        # Bitwise AND between key and slice
        and_res = key & matrix_slice
        
        # XOR reduction (odd/even parity of 1s)
        xor_sum = 0
        while and_res > 0:
            xor_sum ^= (and_res & 1)
            and_res >>= 1
            
        # Set the i-th bit of the output hash
        hash_out |= (xor_sum << i)
        
    return hash_out

def main():
    W = 64
    P = 64
    num_vectors = 100
    
    random.seed(42)  # For reproducibility
    
    keys = []
    matrices = []
    expected_hashes = []
    
    for _ in range(num_vectors):
        # Generate random W-bit key
        key = random.getrandbits(W)
        # Generate random (W + P - 1)-bit matrix window
        matrix_window = random.getrandbits(W + P - 1)
        
        # Compute expected hash
        expected_hash = toeplitz_hash_slice(key, matrix_window, W, P)
        
        keys.append(key)
        matrices.append(matrix_window)
        expected_hashes.append(expected_hash)
        
    # Write files in hex format
    # Using lowercase hex, padded to exact widths:
    # W bits = W/4 hex chars (64 bits = 16 hex chars)
    # W+P-1 bits = 127 bits. We pad to 128 bits = 32 hex chars for easy read by $readmemh
    with open("keys.hex", "w") as f:
        for k in keys:
            f.write(f"{k:016x}\n")
            
    with open("matrices.hex", "w") as f:
        for m in matrices:
            f.write(f"{m:032x}\n")
            
    with open("expected_hashes.hex", "w") as f:
        for h in expected_hashes:
            f.write(f"{h:016x}\n")
            
    print(f"Gerados {num_vectors} vetores de teste para W={W}, P={P}.")
    print("Arquivos criados:")
    print(" - keys.hex (16 caracteres hex por linha)")
    print(" - matrices.hex (32 caracteres hex por linha, correspondente a 128 bits)")
    print(" - expected_hashes.hex (16 caracteres hex por linha)")

if __name__ == "__main__":
    main()
