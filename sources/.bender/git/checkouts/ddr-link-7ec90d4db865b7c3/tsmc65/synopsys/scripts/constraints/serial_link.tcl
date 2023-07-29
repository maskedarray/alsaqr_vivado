# Copyright (c) 2021 ETH Zurich.
# Thomas Benz <tbenz@iis.ee.ethz.ch>
# Paul Scheffler <paulsc@iis.ee.ethz.ch>

# Based on scripts from:
# Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
# Florian Zaruba <zarubaf@iis.ee.ethz.ch>
# Stefan Mach <smach@iis.ee.ethz.ch>
# Andreas Kurth <andkurt@iis.ee.ethz.ch>

# Synthesis constraints for hyperbus in Zest in TSMC65
# Dependencies: sourcing of common_cells.tcl and tc_clk.tcl


#####################
##   Config        ##
#####################

# Parameters
set ddr_clk   ddr_clk_i
set ddr_tck   2.5

set soc_clk   clk_i
set soc_tck   4

set soc_reset rst_ni

set serial_link_inst "i_serial_link"


#####################
##   Constraints   ##
#####################

set_case_analysis 0 [get_ports testmode_i]

set_ideal_network [get_ports ${ddr_clk}]
set_ideal_network [get_ports ${soc_clk}]
set_ideal_network [get_ports ${soc_reset}]

# Create clock at serial link
puts "\[serial link\] Information: Creating ${soc_clk} with period ${soc_tck}"
create_clock -name soc_clk -period ${soc_tck} [get_ports ${soc_clk}]

# Create clock at serial link
puts "\[serial link\] Information: Creating ${ddr_clk} with period ${ddr_tck}"
create_clock -name ddr_clk -period ${ddr_tck} [get_ports ${ddr_clk}]

# Create generated clock for sample clock 0
set ddr_clk_samp_0_shift [expr 0.5*${ddr_tck}]
puts "\[serial link\] Information: Creating ddr_clk_samp_0 with delay ${ddr_clk_samp_0_shift}"
create_generated_clock  -name ddr_clk_samp_0 -edges {1 2 3} \
    -edge_shift "${ddr_clk_samp_0_shift} ${ddr_clk_samp_0_shift} ${ddr_clk_samp_0_shift}" \
    -source ${serial_link_inst}/i_delay/clk_i \
    ${serial_link_inst}/i_delay/clk_o[0]

# Create generated clock for sample clock 1
set ddr_clk_samp_1_shift [expr 0.25*${ddr_tck}]
puts "\[serial link\] Information: Creating ddr_clk_samp_1 with delay ${ddr_clk_samp_1_shift}"
create_generated_clock  -name ddr_clk_samp_1 -edges {1 2 3} \
    -edge_shift "${ddr_clk_samp_1_shift} ${ddr_clk_samp_1_shift} ${ddr_clk_samp_1_shift}" \
    -source ${serial_link_inst}/i_delay/clk_i \
    ${serial_link_inst}/i_delay/clk_o[1]

# Inform tool that system and PHY clock and derived clocks are asynchronous to all others,
# but may have timed arcs to cells clocked by them
puts "\[serial link\] Information: Creating clk_group_ddr"
set_clock_groups -name clk_group_ddr  -asynchronous -allow_paths \
    -group "soc_clk ddr_clk ddr_clk_samp_0 ddr_clk_samp_1"

# Telescope Synchronizer
puts "\[serial link\] Information: False Path between sample_clk[0] and sample_clk[1]"
set_max_delay ${ddr_clk_samp_1_shift} \
                -through [get_pins ${serial_link_inst}/ddr_q2_reg[*]/Q] \
                -through [get_pins ${serial_link_inst}/ddr_q3_reg[*]/D]
set_false_path  -hold \
                -through [get_pins ${serial_link_inst}/ddr_q2_reg[*]/Q] \
                -through [get_pins ${serial_link_inst}/ddr_q3_reg[*]/D]

puts "\[serial link\] Information: False Path between sample_clk[1] and ddr_clk_i"
set_max_delay ${ddr_clk_samp_1_shift} \
                -through [get_pins ${serial_link_inst}/ddr_q3_reg[*]/Q]
set_false_path  -hold \
                -through [get_pins ${serial_link_inst}/ddr_q3_reg[*]/Q]

