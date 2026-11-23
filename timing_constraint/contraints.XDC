# Primary 50 MHz System Clock (20.000 ns period)
create_clock -period 20.000 -name sys_clk -waveform {0.000 10.000} [get_ports clk]

# Input & Output Delay Constraints
set_input_delay  -clock sys_clk -max 2.000 [get_ports {rst_n coin_in[*] coin_valid item_sel[*] sel_valid cancel_btn}]
set_input_delay  -clock sys_clk -min 0.500 [get_ports {rst_n coin_in[*] coin_valid item_sel[*] sel_valid cancel_btn}]

set_output_delay -clock sys_clk -max 2.000 [get_ports {dispense[*] change_out[*] balance[*] out_of_stock}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {dispense[*] change_out[*] balance[*] out_of_stock}]