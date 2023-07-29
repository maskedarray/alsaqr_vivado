# Copyright (c) 2021 ETH Zurich.
# Thomas Benz <tbenz@iis.ee.ethz.ch>
# Paul Scheffler <paulsc@iis.ee.ethz.ch>

# Based on scripts from:
# Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
# Florian Zaruba <zarubaf@iis.ee.ethz.ch>
# Stefan Mach <smach@iis.ee.ethz.ch>
# Andreas Kurth <andkurt@iis.ee.ethz.ch>

# Synthesis Flow in TSMC65 for HyperBus


#####################
##   Config        ##
#####################

if {![info exists tck_sys]} {
    set tck_sys 3
}

if {![info exists param_dw]} {
    set param_dw 128
}

set tck_phy 5
set design hyperbus_synth_wrap
set num_cores 12
set corner SS

set delay_in_sys 0.2
set delay_out_sys 0.2

set jitter_sys 0.05
set jitter_phy 0.05
set jitter_rwds_in 0.05

set clk_rwds_ping 9.47

set params "\
NumChips=>3,\
AxiIdWidth=>6,\
AxiAddrWidth=>48,\
AxiDataWidth=>${param_dw},\
AxiUserWidth=>1,\
RegAddrWidth=>32,\
RegDataWidth=>32\
"

#####################
##   Prepare DC    ##
#####################

# identifier
set identifier ${design}_${tck_sys}ns_${param_dw}_${corner}

# create output folders
sh mkdir -p reports/${identifier}
sh mkdir -p out/${identifier}
sh mkdir -p save/${identifier}

# modify work directory to be unique
set work_path ./WORK/work_${design}
sh rm -rf ${work_path}
sh mkdir -p ${work_path}
define_design_lib work -path ${work_path}

rad
set_host_options -max_cores ${num_cores}

# load worst case libraries from std cells and memory macros
source scripts/init_tech.tcl

# Infer multibit registers for all buses during RTL reading
set hdlin_infer_multibit default_all

# Keep RTL attributes
set_app_var hdlin_sv_enable_rtl_attributes true


#####################
##   Read Design   ##
#####################

# Read in generated delay line macro
lappend link_library ../../models/generic_delay_D4_O1_3P750_CG0_mid.db

source scripts/analyze.tcl > reports/${identifier}/analyze.rpt


#####################
##   Elaborate     ##
#####################

elaborate ${design} -architecture verilog -library work -parameters ${params} > reports/${identifier}/elaborate.rpt
link

# Get templated design name
set elab_design [get_object_name [get_designs -filter "hdl_template==${design}"]]

# write post-elab reports
link                            > reports/${identifier}/link_elab.rpt
list_designs                    > reports/${identifier}/designs.rpt
analyze_datapath_extraction     > reports/${identifier}/dp_extraction.rpt
analyze_rtl_congestion -nosplit > reports/${identifier}/congestion.rpt
check_design -nosplit           > reports/${identifier}/check_design_elab.rpt


#####################
##   Constraints   ##
#####################

# We let the backend tool generate the buffer tree for these signals.
set_ideal_network clk_sys_i
set_ideal_network clk_phy_i
set_ideal_network rst_sys_ni
set_ideal_network rst_phy_ni

# Set the critical range - not only consider longest path
set_critical_range 0.8 ${elab_design}

# Assume we do not operate in test mode
set_case_analysis 0 [get_ports test_mode_i]

# Create the system clock
create_clock -name clk_sys -period ${tck_sys} [get_ports clk_sys_i]
set_clock_uncertainty [expr {${jitter_sys}*${tck_sys}}] clk_sys

# Create the PHY clock
create_clock -name clk_phy -period ${tck_phy} [get_ports clk_phy_i]
set_clock_uncertainty [expr {${jitter_phy}*${tck_phy}}] clk_phy

# Create generated clock for for outgoing RWDS after delay
set clk_tx_shift [expr 0.25*${tck_phy}]
create_generated_clock  -name clk_tx -edges {1 2 3} -edge_shift "$clk_tx_shift $clk_tx_shift $clk_tx_shift" \
    -source i_hyperbus/i_phy/i_trx/i_delay_tx_clk_90/i_delay/clk_i \
    i_hyperbus/i_phy/i_trx/i_delay_tx_clk_90/i_delay/clk_o

# Create generated clock for incoming RWDS: interpreted as outgoing clock after some round-trip time
create_generated_clock  -name clk_rwds_in -edges {1 2 3} -edge_shift "$clk_rwds_ping $clk_rwds_ping $clk_rwds_ping" \
    -source [get_ports hyper_rwds_o] [get_ports hyper_rwds_i]
set_clock_uncertainty [expr {${jitter_rwds_in}*${tck_phy}}] clk_rwds_in

# Create generated clock for incoming RWDS after delay
set clk_rx_shift [expr 0.25*${tck_phy}]
create_generated_clock  -name clk_rx -edges {1 2 3} -edge_shift "$clk_rx_shift $clk_rx_shift $clk_rx_shift" \
    -source i_hyperbus/i_phy/i_trx/i_delay_rx_rwds_90/i_delay/clk_i \
    i_hyperbus/i_phy/i_trx/i_delay_rx_rwds_90/i_delay/clk_o

# Inform tool that system and PHY-derived clocks are asynchronous, but may have timed arcs between them
set_clock_groups -asynchronous -allow_paths -group {clk_sys} -group {clk_phy clk_tx clk_rwds_in clk_rx}

# Overconstrain System-side I/O
set_fanout_load 8 [all_outputs]
set_input_delay  [expr { ${delay_in_sys} *${tck_sys} }] -clock clk_sys [remove_from_collection [all_inputs] [get_ports {hyper* clk_phy_i}]]
set_output_delay [expr { ${delay_out_sys}*${tck_sys} }] -clock clk_sys [remove_from_collection [all_outputs] [get_ports {hyper*}]]

# Constrain i_cdc_2phase crossings (clocks already async above)
foreach_in_collection des_ref [get_cells i_hyperbus/i_cdc_2phase_*] {
    set des [get_object_name $des_ref]
    set_ungroup                 $des false
    set_boundary_optimization   $des false
    set_dont_touch              [get_nets $des/async*]      true
    set_ungroup                 [get_cells $des/*]          false
    set_boundary_optimization   [get_cells $des/*]          false
    set_dont_touch              [get_cells $des/*/*_reg]    true
    set async_ports [get_ports $des/*/async_*]
    set_max_delay [expr min(${tck_sys}, ${tck_phy})] -through ${async_ports} -through ${async_ports}
    set_false_path -hold -through ${async_ports} -through ${async_ports}
}

# Constrain i_cdc_fifo_gray CDC FIFOs (clocks already async above)
set async_pins [get_pins -hierarchical -filter async]
set_ungroup [get_designs cdc_fifo_gray*] false
set_boundary_optimization [get_designs cdc_fifo_gray*] false
set_max_delay [expr min(${tck_sys}, ${tck_phy})] -through ${async_pins} -through ${async_pins}
set_false_path -hold -through ${async_pins} -through ${async_pins}

# Constrain config register false paths to PHY
set cfg_from  [get_pins i_hyperbus/i_cfg_regs/cfg_o*]
set cfg_to    [get_pins i_hyperbus/i_phy/cfg_i*]
set_max_delay [expr min(${tck_sys}, ${tck_phy})] -through ${cfg_from} -through ${cfg_to}
set_false_path -hold -through ${cfg_from} -through ${cfg_to}

# Report on clock definitions
report_clocks -nosplit > reports/${identifier}/clocks.rpt

# Write out SDC
write_sdc save/${identifier}/constraints.sdc

# write checkpoint
write_file -format ddc -hierarchy -output save/${identifier}/elab.ddc


#####################
## Compile Options ##
#####################

# Choose timing-driven multibit register mapping
set_multibit_options -mode timing_driven

# remove assign statements from the netlist
set_fix_multiple_port_nets -all -buffer_constants

# run additional optimizations
#set_app_var compile_timing_high_effort true    # topo only?


#####################
##    Compile      ##
#####################

# Compile first
compile_ultra -no_autoungroup -gate_clock > reports/${identifier}/compile.rpt

# write checkpoint
write_file -format ddc -hierarchy -output save/${identifier}/compile.ddc

# reduce area w/o affecting power & timing
optimize_netlist -area > reports/${identifier}/optimize_area.rpt

# post-compile reports #report_clock_gate_savings
check_design -nosplit                    > reports/${identifier}/check_design_synth.rpt
analyze_datapath                         > reports/${identifier}/datapath.rpt
report_datapath_gating -nosplit -gated   > reports/${identifier}/dp_gating.rpt
report_datapath_gating -nosplit -ungated > reports/${identifier}/dp_gating_ungated.rpt
report_net_fanout                        > reports/${identifier}/cell_fanout.rpt
report_power -hierarchy -nosplit         > reports/${identifier}/power.rpt
#report_congestion -effort high           > reports/${identifier}/congestion.rpt  # topo only?
report_resources -hierarchy -nosplit     > reports/${identifier}/ressources.rpt
report_hierarchy -nosplit                > reports/${identifier}/hierarchy.rpt
report_qor                               > reports/${identifier}/qor.rpt
report_timing -nosplit -max_paths 300    > reports/${identifier}/timing.rpt
report_area -nosplit -hierarchy          > reports/${identifier}/area.rpt


#####################
##   Write Data    ##
#####################

# prepare verilog dump
change_names -rules verilog -hierarchy
#define_name_rules fixbackslashes -allowed "A-Za-z0-9_" -first_restricted "\\" -remove_chars
#change_names -rule fixbackslashes -h

# extract netlist, sdc, and test model
write_file -hierarchy -format verilog -output out/${identifier}/${design}.v
write_sdc -nosplit out/${identifier}/${design}.sdc
write_sdf out/${identifier}/${design}.sdf
write_file -format ddc -hierarchy -output save/${identifier}/final.ddc
# write_test_model -format ctl -output out/${identifier}/${design}.clt
#write_scan_def -output out/${identifier}/${design}.def

#exit
