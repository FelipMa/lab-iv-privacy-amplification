def main():
    try:
        with open("expected_hashes.hex", "r") as f:
            expected = [line.strip().lower() for line in f if line.strip()]
    except FileNotFoundError:
        print("Erro: O arquivo 'expected_hashes.hex' nao foi encontrado. Execute 'generate_vectors.py' primeiro.")
        return

    try:
        with open("output_hashes.hex", "r") as f:
            output = [line.strip().lower() for line in f if line.strip()]
    except FileNotFoundError:
        print("Erro: O arquivo 'output_hashes.hex' (gerado pela simulacao Verilog) nao foi encontrado.")
        print("Certifique-se de rodar a simulacao no ModelSim/Questa ate o fim.")
        return

    if len(expected) != len(output):
        print(f"Erro: Quantidade de linhas diferente! Esperado: {len(expected)}, Obtido: {len(output)}")
        return

    success = True
    for i, (exp, out) in enumerate(zip(expected, output)):
        # Normalize and pad/strip if there's any difference in width representation
        exp_val = int(exp, 16)
        out_val = int(out, 16)
        if exp_val != out_val:
            print(f"Erro na linha {i+1}:")
            print(f"  Esperado: 0x{exp}")
            print(f"  Obtido:   0x{out}")
            success = False
            break

    if success:
        print("Sucesso! Todos os 100 resultados gerados pelo hardware coincidem com o esperado em software.")
    else:
        print("Falha na comparacao de resultados.")

if __name__ == "__main__":
    main()
