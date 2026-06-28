vlib work
vmap work work

vlog -work work aes_sbox_rom_2p.v
vlog -work work AES.v
vlog -work work CTR_seed_controller.v
vlog -work work CTR_seed_controller_tb.v

vsim -t 1ps work.CTR_seed_controller_tb
run -all
