onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /tb_sistema_completo/clk_150
add wave -noupdate -radix hexadecimal /tb_sistema_completo/rst
add wave -noupdate -radix hexadecimal -childformat {{{/tb_sistema_completo/wire_key_addr[4]} -radix hexadecimal} {{/tb_sistema_completo/wire_key_addr[3]} -radix hexadecimal} {{/tb_sistema_completo/wire_key_addr[2]} -radix hexadecimal} {{/tb_sistema_completo/wire_key_addr[1]} -radix hexadecimal} {{/tb_sistema_completo/wire_key_addr[0]} -radix hexadecimal}} -subitemconfig {{/tb_sistema_completo/wire_key_addr[4]} {-radix hexadecimal} {/tb_sistema_completo/wire_key_addr[3]} {-radix hexadecimal} {/tb_sistema_completo/wire_key_addr[2]} {-radix hexadecimal} {/tb_sistema_completo/wire_key_addr[1]} {-radix hexadecimal} {/tb_sistema_completo/wire_key_addr[0]} {-radix hexadecimal}} /tb_sistema_completo/wire_key_addr
add wave -noupdate -radix binary /tb_sistema_completo/wire_key_q
add wave -noupdate -radix hexadecimal -childformat {{{/tb_sistema_completo/wire_matrix_addr[4]} -radix hexadecimal} {{/tb_sistema_completo/wire_matrix_addr[3]} -radix hexadecimal} {{/tb_sistema_completo/wire_matrix_addr[2]} -radix hexadecimal} {{/tb_sistema_completo/wire_matrix_addr[1]} -radix hexadecimal} {{/tb_sistema_completo/wire_matrix_addr[0]} -radix hexadecimal}} -subitemconfig {{/tb_sistema_completo/wire_matrix_addr[4]} {-radix hexadecimal} {/tb_sistema_completo/wire_matrix_addr[3]} {-radix hexadecimal} {/tb_sistema_completo/wire_matrix_addr[2]} {-radix hexadecimal} {/tb_sistema_completo/wire_matrix_addr[1]} {-radix hexadecimal} {/tb_sistema_completo/wire_matrix_addr[0]} {-radix hexadecimal}} /tb_sistema_completo/wire_matrix_addr
add wave -noupdate -radix binary /tb_sistema_completo/wire_matrix_q
add wave -noupdate -radix hexadecimal /tb_sistema_completo/SAIDA_HASH
add wave -noupdate -radix hexadecimal /tb_sistema_completo/LEDG
add wave -noupdate -divider Matrix
add wave -noupdate -radix hexadecimal /tb_sistema_completo/uut_rom_matrix/q
add wave -noupdate -radix hexadecimal /tb_sistema_completo/uut_rom_matrix/address
add wave -noupdate -divider {Input Buffer}
add wave -noupdate -radix hexadecimal /tb_sistema_completo/uut_rom_key/q
add wave -noupdate -radix hexadecimal /tb_sistema_completo/uut_rom_key/address
add wave -noupdate -divider {Compression Unit}
add wave -noupdate /tb_sistema_completo/uut_top/u_compression_unit/key
add wave -noupdate /tb_sistema_completo/uut_top/u_compression_unit/matrix_window
add wave -noupdate /tb_sistema_completo/uut_top/u_compression_unit/hash_out
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {16691 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 583
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {16104 ps} {16452 ps}
