set_time_format -unit ns -decimal_places 3

# Definição do clock físico de entrada (50 MHz)
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# Derivação automática dos 150MHz internos do PLL
derive_pll_clocks
derive_clock_uncertainty

# Margens para pinos externos
set_input_delay -clock CLOCK_50 2.0 [remove_from_collection [all_inputs] [get_ports {CLOCK_50}]]
set_output_delay -clock CLOCK_50 2.0 [all_outputs]

# Ignora o cruzamento assíncrono para os pinos externos de feedback
set_false_path -from [all_registers] -to [get_ports {LEDG[0]}]
set_false_path -from [all_registers] -to [get_ports {SAIDA_HASH[*]}]