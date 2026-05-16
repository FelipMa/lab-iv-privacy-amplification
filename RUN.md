# Como rodar e validar a v1

Fluxo ponta-a-ponta da validação da `compression_unit` (v1, W=8, P=8) usando duas memórias altsyncram do Quartus e referência numpy/scipy em Python.

## Estrutura envolvida

```
src/
  compression_unit.v          # DUT
  hash_engine.v               # usado pelo DUT
  tb_mem_validation/
    input_rom.v               # altsyncram ROM (carrega input_vectors.mif)
    output_ram.v              # altsyncram RAM
    top_mem_tb.v              # testbench
    input_vectors.mif         # gerado pelo Python
    expected_outputs.hex      # gerado pelo Python (debug/inspeção)
    sim/                      # output_dump.hex aparece aqui
high_level_simulation/
  compression_model.py        # modelo Toeplitz (numpy + scipy)
  gen_mif.py                  # gera .mif e expected
  validate_dump.py            # compara dump com referência
  requirements.txt
```

## Passo a passo

### 1. Dependências Python

```bash
pip install -r high_level_simulation/requirements.txt
```

### 2. Gerar entradas e esperados

```bash
python3 high_level_simulation/gen_mif.py
```

Produz:
- `src/tb_mem_validation/input_vectors.mif` (16 palavras de 23 bits, `{matrix_window, key}`)
- `src/tb_mem_validation/expected_outputs.hex` (16 bytes, opcional para inspeção)

### 3. Simulação no ModelSim/Questa Altera

Da pasta `src/tb_mem_validation/sim/`:

```bash
vlib work
vlog ../*.v ../../compression_unit.v ../../hash_engine.v
vsim -L altera_mf_ver work.top_mem_tb -do "run -all; quit"
```

A flag `-L altera_mf_ver` é necessária para resolver os IPs altsyncram.
Ao final, o `$writememh` grava `output_dump.hex` no diretório atual (`sim/`).

### 4. Validação

```bash
python3 high_level_simulation/validate_dump.py
```

Lê `src/tb_mem_validation/input_vectors.mif`, recomputa o hash esperado para cada entrada via `compression_model.compress` (matriz Toeplitz construída com `scipy.linalg.toeplitz` + matmul numpy `mod 2`) e compara contra `src/tb_mem_validation/sim/output_dump.hex`.

Saída esperada se tudo funcionar:

```
addr  key matrix  got expected  status
   0 0x00 0x0000 0x00 0x00   PASS
   ...
  15 0xb5 0x6f25 0x1b 0x1b   PASS

PASS: 16/16 vetores ok
```

Exit code 0 = sucesso, 1 = falha.

## Parâmetros do experimento

| Parâmetro | Valor | Onde mudar |
|---|---|---|
| W (largura da key) | 8 | `compression_model.py`, `top_mem_tb.v`, `input_rom.v` |
| P (paralelismo / largura do hash) | 8 | idem |
| matrix_window | W+P−1 = 15 bits | derivado |
| Profundidade das memórias | 16 | `gen_mif.py` (DEPTH), `top_mem_tb.v` |
| Vetores | 4 determinísticos + 12 random (seed=0) | `gen_mif.py` |

## Mudando os vetores de teste

Editar `high_level_simulation/gen_mif.py` (funções `deterministic_vectors` ou `random_vectors`), rodar de novo o passo 2, recompilar a simulação e revalidar.
