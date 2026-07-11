# ============================================================
# TimeQuest SDC - Privacy Amplification
# Entrada física: CLOCK_50 = 50 MHz
# PLL interno: gera clock de 150 MHz
# ============================================================

set_time_format -unit ns -decimal_places 3

# Clock físico de entrada: 50 MHz => 20 ns
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# Deriva automaticamente o clock gerado pelo PLL
derive_pll_clocks

# Incertezas recomendadas
derive_clock_uncertainty

# ------------------------------------------------------------
# Portas JTAG reservadas da Altera/Intel
# Usadas por infraestrutura interna de debug/JTAG.
# Não fazem parte do datapath síncrono do projeto.
# ------------------------------------------------------------
set_false_path -from [get_ports -nowarn {altera_reserved_tdi}]
set_false_path -from [get_ports -nowarn {altera_reserved_tms}]
set_false_path -to   [get_ports -nowarn {altera_reserved_tdo}]

set_false_path -to   [get_ports -nowarn {LEDR[*]}]
set_false_path -from [get_ports -nowarn {SW[*]}]
