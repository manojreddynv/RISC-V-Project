# RISC-V RV32I 5-stage pipeline timing constraints
# Top-level ports: clk, rst_n, dbg_status[7:0]
# Assumption: 100 MHz clock -> 10 ns period

create_clock -name clk -period 7.000 [get_ports clk]

# rst_n is an asynchronous reset in the RTL
set_false_path -from [get_ports rst_n]

# If dbg_status is only a debug/keep-alive output, this can be enabled:
# set_false_path -to [get_ports {dbg_status[*]}]
