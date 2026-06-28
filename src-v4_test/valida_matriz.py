import math

def gerar_log_definitivo(N, W, P, L, filename="log_toeplitz_topdown_bottomup_array.txt"):
    CYCLES = math.ceil(N / W)
    BATCHES = math.ceil(L / P)

    # Tamanho total do array 1D necessário
    TOTAL_M = N + L - 1
    digits = len(str(TOTAL_M - 1))
    
    # Geração do Array 1D genérico simulando a semente (m00, m01, m02...)
    M = [f"m{str(i).zfill(digits)}" for i in range(TOTAL_M)]

    with open(filename, "w", encoding="utf-8") as f:
        f.write("=======================================================================\n")
        f.write(" LOG DEFINITIVO: MATRIZ DE TOEPLITZ PERFEITA E ALINHAMENTO DE HARDWARE \n")
        f.write("=======================================================================\n\n")
        
        f.write("GEOMETRIA MATEMÁTICA DEFINIDA:\n")
        f.write("- Processamento das Janelas : Cima para Baixo (Top-Down), Esquerda para a Direita.\n")
        f.write("- Mapeamento do Array 1D    : Baixo para Cima (Bottom-Up), Esquerda para a Direita.\n")
        f.write(f"- Parâmetros do Hardware    : N={N}, W={W}, P={P}, L={L}\n\n")

        f.write("-----------------------------------------------------------------------\n")
        f.write("1. ARRAY GERAL DA SEMENTE (1D) - [ ESQUERDA -> DIREITA ]\n")
        f.write("-----------------------------------------------------------------------\n")
        f.write("[ ")
        for i in range(0, len(M), 16):
            if i + 16 < len(M):
                f.write(", ".join(M[i:i+16]) + ",\n  ")
            else:
                f.write(", ".join(M[i:i+16]))
        f.write(" ]\n\n")

        f.write("-----------------------------------------------------------------------\n")
        f.write("2. A MATRIZ DE TOEPLITZ GLOBAL (L x N)\n")
        f.write("-----------------------------------------------------------------------\n")
        f.write("Fórmula Teórica: Índice = (L - 1 - Linha_Global) + Coluna_Global\n")
        f.write("O elemento 'm00' ancora o canto inferior esquerdo. As diagonais (\\) são constantes.\n\n")
        
        for r in range(L):
            linha = []
            for c in range(N):
                idx = (L - 1 - r) + c
                linha.append(M[idx])
            nome_linha = f"Linha Global {str(r).zfill(2)}"
            
            # Adiciona marcadores de Topo e Base para verificação geométrica
            if r == 0: nome_linha += " (Topo)"
            elif r == L - 1: nome_linha += " (Base)"
            else: nome_linha += "       "
            f.write(f"{nome_linha}: [ " + " ".join(linha) + " ]\n")

        f.write("\n-----------------------------------------------------------------------\n")
        f.write("3. EXTRAÇÃO DAS JANELAS POR LOTE E CICLO (PROCESSAMENTO TOP-DOWN)\n")
        f.write("-----------------------------------------------------------------------\n")
        f.write("SEM INVERSÃO EM SOFTWARE: O array é fatiado puro e o hardware lê usando `window[(P - 1 - i) +: W]`.\n")
        
        for b in range(BATCHES):
            f.write(f"\n=======================================================\n")
            f.write(f" LOTE {b} (Processa do Topo para Baixo: Linhas {b*P} até {(b+1)*P - 1})\n")
            f.write(f"=======================================================\n")
            
            for c_idx in range(CYCLES):
                f.write(f"\n  --- Ciclo {c_idx} (Avanço Esquerda-Direita: Colunas {c_idx*W} até {(c_idx+1)*W - 1}) ---\n")
                
                row_base = b * P
                col_base = c_idx * W
                
                # =========================================================================
                # 1. CÁLCULO DAS JANELAS EXATAS
                # =========================================================================
                min_idx = (L - 1) - (row_base + P - 1) + col_base
                max_idx = (L - 1) - row_base + (col_base + W - 1)
                
                f.write(f"  [Passo A] Limites da Janela Requisitada no Array 1D:\n")
                f.write(f"    - Menor Índice : (L - 1) - (LinhaBase + P - 1) + ColunaBase\n")
                f.write(f"    - Cálculo Min  : ({L}-1) - ({row_base}+{P}-1) + {col_base} = {min_idx}\n")
                f.write(f"    - Maior Índice : (L - 1) - LinhaBase + (ColunaBase + W - 1)\n")
                f.write(f"    - Cálculo Max  : ({L}-1) - {row_base} + ({col_base}+{W}-1) = {max_idx}\n\n")
                
                raw_window = []
                for k in range(min_idx, max_idx + 1):
                    if k < 0 or k >= TOTAL_M:
                        raw_window.append(f"m{'0'*digits}") # Zero-Padding lógicos para Out-Of-Bounds
                    else:
                        raw_window.append(M[k])
                
                f.write(f"  [Passo B] Janela PURA Entregue ao Hardware (Tamanho {W+P-1}):\n")
                f.write("    [ " + ", ".join(raw_window) + " ]\n\n")
                
                # =========================================================================
                # 2. VALIDAÇÃO DO ROTEAMENTO NO HARDWARE
                # =========================================================================
                f.write(f"  [Passo C] Distribuição Mapeada nos Motores (Verilog offset: P - 1 - i):\n")
                for i in range(P):
                    r_global = row_base + i
                    if r_global < L:
                        start_h = P - 1 - i
                        end_h = start_h + W
                        hw_row = raw_window[start_h : end_h]
                        f.write(f"    Motor H{i} (Offset {start_h} | L.Global {str(r_global).zfill(2)}): [ " + " ".join(hw_row) + " ]\n")

    return filename

if __name__ == "__main__":
    arquivo_gerado = gerar_log_definitivo(N=24, W=8, P=4, L=12)
    print(f"Sucesso! Abra o arquivo '{arquivo_gerado}'.")