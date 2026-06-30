# wave.do - sinais essenciais para validar a chave final
onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -divider "TB"
add wave -radix binary       /tb_sistema_completo/clock
add wave -radix binary       /tb_sistema_completo/reset
add wave -radix unsigned     /tb_sistema_completo/batch_count
add wave -radix hexadecimal  /tb_sistema_completo/chave_final

add wave -divider "SAIDAS DO TOP"
add wave -radix hexadecimal  /tb_sistema_completo/hash_register
add wave -radix binary       /tb_sistema_completo/batch_ready
add wave -radix binary       /tb_sistema_completo/done

add wave -divider "CONTROLE"
add wave -radix unsigned     /tb_sistema_completo/uut_top/u_controlador/current_state
add wave -radix unsigned     /tb_sistema_completo/uut_top/u_controlador/batch_idx
add wave -radix unsigned     /tb_sistema_completo/uut_top/u_controlador/words_idx
add wave -radix binary       /tb_sistema_completo/uut_top/sys_reset
add wave -radix binary       /tb_sistema_completo/uut_top/enable
add wave -radix binary       /tb_sistema_completo/uut_top/clear_acc
add wave -radix binary       /tb_sistema_completo/uut_top/buf_go
add wave -radix binary       /tb_sistema_completo/uut_top/seed_go
add wave -radix binary       /tb_sistema_completo/uut_top/ram_we
add wave -radix unsigned     /tb_sistema_completo/uut_top/ram_address

add wave -divider "DADOS DA OPERACAO"
add wave -radix binary       /tb_sistema_completo/uut_top/buf_ready
add wave -radix binary       /tb_sistema_completo/uut_top/buf_out_valid
add wave -radix binary       /tb_sistema_completo/uut_top/seed_ready
add wave -radix hexadecimal  /tb_sistema_completo/uut_top/safe_key
add wave -radix hexadecimal  /tb_sistema_completo/uut_top/safe_window
add wave -radix hexadecimal  /tb_sistema_completo/uut_top/current_hash_out

add wave -divider "INPUT BUFFER"
add wave -radix unsigned     /tb_sistema_completo/uut_top/u_input_buffer/state
add wave -radix unsigned     /tb_sistema_completo/uut_top/u_input_buffer/valid_count
add wave -radix unsigned     /tb_sistema_completo/uut_top/rom_key_addr
add wave -radix hexadecimal  /tb_sistema_completo/uut_top/rom_key_q
add wave -radix hexadecimal  /tb_sistema_completo/uut_top/buf_out_data

add wave -divider "SEED GENERATOR"
add wave -radix unsigned     /tb_sistema_completo/uut_top/u_seed_generator/state
add wave -radix unsigned     /tb_sistema_completo/uut_top/u_seed_generator/batch_idx
add wave -radix unsigned     /tb_sistema_completo/uut_top/u_seed_generator/cycles_done
add wave -radix unsigned     /tb_sistema_completo/uut_top/u_seed_generator/valid_bits
add wave -radix hexadecimal  /tb_sistema_completo/uut_top/current_matrix_window

configure wave -namecolwidth 260
configure wave -valuecolwidth 160
update
