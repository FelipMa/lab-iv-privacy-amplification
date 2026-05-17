# Como rodar e validar a v1 (hardware Toeplitz)

Validação da `compression_unit` (v1, W=8, P=8) com duas memórias altsyncram do Quartus. O mesmo conjunto de arquivos serve para simulação no ModelSim **e** para síntese na DE2-115.

**Esta branch** (`test/v1-altysncram-hardware-toeplitz-validation`) muda o
`compression_unit.v` para implementar multiplicação por matriz **Toeplitz**
(T[i,j] depende de i−j), batendo com a referência Python que usa
`scipy.linalg.toeplitz`. A versão anterior, baseada em part-select contíguo
(`matrix_window[i +: W]`), implementava Hankel.

## Estrutura

```
src/
  top.v                       # top sintetizavel (DE2-115) com input_rom + DUT + output_ram
  compression_unit.v          # DUT
  hash_engine.v               # usado pelo DUT
  lab_iv_privacy_amplification.qsf   # projeto Quartus
  tb_mem_validation/
    input_rom.v               # altsyncram ROM (carrega input_vectors.mif)
    output_ram.v              # altsyncram RAM (In-System Memory Editor: ORAM)
    top_mem_tb.v              # testbench (simulacao)
    input_vectors.mif         # gerado pelo Python
    expected_outputs.hex      # gerado pelo Python (inspecao)
    sim/output_dump.hex       # gerado pelo testbench na simulacao
high_level_simulation/
  compression_model.py        # modelo Toeplitz (numpy + scipy)
  gen_mif.py                  # gera .mif e expected
  validate_dump.py            # compara dump com referencia
  requirements.txt
```

## Setup comum

```bash
pip install -r high_level_simulation/requirements.txt
python3 high_level_simulation/gen_mif.py
```

Produz `src/tb_mem_validation/input_vectors.mif` (16 palavras de 23 bits) e `expected_outputs.hex` (16 bytes esperados).

## Fluxo 1 — Simulação (ModelSim/Questa Altera)

A partir de `src/tb_mem_validation/`:

```bash
vlib work
vlog *.v ../compression_unit.v ../hash_engine.v
vsim -L altera_mf_ver work.top_mem_tb -do "run -all; quit"
```

Gera `sim/output_dump.hex`. Em seguida:

```bash
python3 high_level_simulation/validate_dump.py
```

Saída esperada: `PASS: 16/16 vetores ok`.

## Fluxo 2 — FPGA (DE2-115)

### Compilar e programar

1. Abrir `src/lab_iv_privacy_amplification.qpf` no Quartus.
2. `Processing → Start Compilation`. O entity `top` está configurado no `.qsf`. O `.mif` é encontrado via `SEARCH_PATH=tb_mem_validation`.
3. Conectar a DE2-115 via USB-Blaster, abrir `Tools → Programmer`, carregar o `.sof` gerado em `output_files/` e clicar `Start`.

### Executar o experimento

Após programar:

1. Pressionar `KEY[0]` (mapeado como `rst_fpga`) — reseta o contador de ciclos.
2. Soltar `KEY[0]` — o circuito processa os 16 vetores (18 ciclos a 50 MHz = 360 ns).
3. `LEDR[0]` (mapeado como `LED_done`) acende = `done`. A output_ram contém os 16 bytes.

### Extrair o output

`Tools → In-System Memory Content Editor`:

1. Clicar `Scan Chain`. O instance `ORAM` (definido em `output_ram.v` via `lpm_hint`) aparece.
2. Selecionar `ORAM` e clicar `Read Data from In-System Memory`.
3. `File → Save File` salvando como `.hex` (formato Intel HEX) em `src/tb_mem_validation/sim/output_dump.hex` — ou outro caminho que você preferir.

Se a ferramenta exportar em formato Intel HEX (com checksums), converta para o formato simples (um byte hex por linha) antes de rodar a validação. Como são só 16 bytes, é trivial fazer à mão ou com um script ad-hoc.

### Validar

```bash
python3 high_level_simulation/validate_dump.py
```

Mesma saída esperada do fluxo de simulação: `PASS: 16/16 vetores ok`.

## Parâmetros

| Parâmetro | Valor | Onde mudar |
|---|---|---|
| W (largura da key) | 8 | `compression_model.py`, `top_mem_tb.v`, `top.v` |
| P (paralelismo / largura do hash) | 8 | idem |
| matrix_window | W+P−1 = 15 bits | derivado |
| Profundidade das memórias | 16 | `gen_mif.py` (DEPTH), TBs |
| Vetores | 4 determinísticos + 12 random (seed=0) | `gen_mif.py` |

## Mudando os vetores

Editar `high_level_simulation/gen_mif.py` (`deterministic_vectors` / `random_vectors`), rodar de novo o gen_mif, recompilar e revalidar. Para o FPGA é preciso recompilar o projeto Quartus, já que o `.mif` é inicializado em tempo de configuração.
