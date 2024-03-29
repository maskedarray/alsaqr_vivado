# Copyright (c) 2021 ETH Zurich.
# Thomas Benz <tbenz@iis.ee.ethz.ch>
# Paul Scheffler <paulsc@iis.ee.ethz.ch>

# Based on scripts from:
# Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
# Florian Zaruba <zarubaf@iis.ee.ethz.ch>
# Stefan Mach <smach@iis.ee.ethz.ch>
# Andreas Kurth <andkurt@iis.ee.ethz.ch>

# Synthesis Flow in GF22 for HyperBus

####################################################################
## Environment Setup
####################################################################
set TRIAL_DIR "trial5_25_11_2021"
set DESIGN_NAME "hyperbus_synth_wrap"

source .synopsys_dc.setup
source ./design_setup.tcl

sh date
sh echo "Current git version is `git rev-parse --short HEAD`"

suppress_message { VER-130 }
set_host_option -max_core 8
set timing_enable_through_paths true

set compile_timing_high_effort true
set_app_var hdlin_sv_enable_rtl_attributes true
set_app_var write_name_nets_same_as_ports true
set_app_var hdlin_infer_multibit default_all
set compile_clock_gating_through_hierarchy true

sh mkdir -p ${TRIAL_DIR}/unmapped
sh mkdir -p ${TRIAL_DIR}/logs
sh mkdir -p ${TRIAL_DIR}/reports
sh date > ${TRIAL_DIR}/lock_date


####################################################################
## ANALYZE THE RTL CODE or Read the GTECH 
####################################################################
file delete -force -- ./work
source -echo -verbose ./scripts/analyze.tcl > ${TRIAL_DIR}/logs/analyze.log

####################################################################
## ELABORATE HYPER TOP LEVEL
####################################################################
elaborate ${DESIGN_NAME} -work work > ${TRIAL_DIR}/reports/d00_elaborate.log
check_design                        > ${TRIAL_DIR}/reports/d01_check_design_postElab.rpt
current_design hyperbus_synth_wrap
write -format verilog -hier -o ./${TRIAL_DIR}/unmapped/${DESIGN_NAME}_chip_unmapped.v
write -format ddc -hier -o ./${TRIAL_DIR}/unmapped/${DESIGN_NAME}_chip_unmapped.ddc ${DESIGN_NAME}
report_timing -loop -max_paths 100 > ./${TRIAL_DIR}/timing_loops.rpt

####################################################################
## LINK
####################################################################
link                                                      > ${TRIAL_DIR}/reports/d03_link_alsaqr.rpt

####################################################################
## UNIQUIFY
####################################################################
after 1000
set uniquify_naming_style "hyperbus_%s_%d"
uniquify -force                                           > ${TRIAL_DIR}/reports/d04_pre_synth_uniquify.rpt

####################################################################
## SET OPERATING CONDITIONS
####################################################################
set_operating_conditions -max SSG_0P72V_0P00V_0P00V_0P00V_M40C

####################################################################
## ADD CONSTRAINTS
####################################################################
source -echo -verbose ./constraints.sdc       > ${TRIAL_DIR}/reports/d06_constr_clk.rpt

## AVOID SYNOPSYS MODIFICATIONS TO IOPWROK AND PWROK ON PADS
set_dont_touch [get_nets  {i_hyperbus_macro/pad*/RETC}   ]
set_dont_touch [get_nets  {i_hyperbus_macro/pad*/PWROK}  ]
set_dont_touch [get_nets  {i_hyperbus_macro/pad*/IOPWROK}]
set_dont_touch [get_nets  {i_hyperbus_macro/pad*/BIAS}   ]

####################################################################
## INSERT CLK GATING CELLS
####################################################################
# clock gating
identify_clock_gating
report_clock_gating -multi_stage -nosplit > ./${TRIAL_DIR}/reports/d07_clk_gating.rpt
set_preserve_clock_gate [all_clock_gates]
set_attribute [get_cells  $CLK_GATE_CELL  ] is_clock_gating_cell true 
set_attribute [get_cells  $CLK_GATE_CELL  ] clock_gating_integrated_cell latch_posedge_precontrol 
set_clock_gating_style -minimum_bitwidth 8 -positive_edge_logic integrated:$CLK_GATE_CELL -control_point  before  -control_signal scan_enable  -max_fanout 256

report_clocks                                                       > ./${TRIAL_DIR}/reports/d08_clocks.rpt

####################################################################
## UNGROUPING
####################################################################
check_design                                              > ./${TRIAL_DIR}/reports/d09_check_design_precompile.rpt
compile_ultra -no_autoungroup -timing  
check_design                                              > ./${TRIAL_DIR}/reports/d10_check_design_postcompile.rpt
report_clock_gating -multi_stage -nosplit                 > ./${TRIAL_DIR}/reports/d11_clk_gating.rpt

####################################################################
## POST SYNTHESIS UNIQUIFY 
####################################################################
set uniquify_naming_style "hyperbus_%s_%d"
uniquify -force                                           > ./${TRIAL_DIR}/reports/d13_uniquify_post_synth.rpt

####################################################################
## POST SYNTHESIS DDC
####################################################################
sh mkdir -p ./${TRIAL_DIR}/mapped
write -f ddc -hierarchy  -output ./${TRIAL_DIR}/mapped/alsaqr_postsyn.ddc

####################################################################
## POST SYNTHESIS NETLIST
####################################################################
change_names -rules verilog -hier
define_name_rules fixbackslashes -allowed "A-Za-z0-9_" -first_restricted "\\" -remove_chars
change_names -rule fixbackslashes -h
sh mkdir -p ./${TRIAL_DIR}/netlists
write -format verilog -hier -o ./${TRIAL_DIR}/netlists/hyperbus_chip.v

####################################################################
## REPORTS
####################################################################
report_timing      -nosplit                                                                                  > ./${TRIAL_DIR}/reports/timing.rpt
report_area  -hier -nosplit                                                                                  > ./${TRIAL_DIR}/reports/area.rpt
report_resources -hierarchy                                                                                  > ./${TRIAL_DIR}/reports/dp_resource.rpt
report_clock_gating                                                                                          > ./${TRIAL_DIR}/reports/clock_gating_postsyn.rpt
report_units                                                                                                 > ./${TRIAL_DIR}/reports/units.rpt

report_timing -max_paths 10 -to clk_sys                                                                > ./${TRIAL_DIR}/reports/timing_sys_clock.rpt
report_timing -max_paths 10 -to clk_phy_0                                                              > ./${TRIAL_DIR}/reports/timing_phy_clock.rpt
report_timing -max_paths 10 -to clk_phy_90                                                             > ./${TRIAL_DIR}/reports/timing_phy_clock90.rpt
report_timing -max_paths 10 -to clk_rwds_sample0                                                       > ./${TRIAL_DIR}/reports/timing_rwds0_sample_clock.rpt
report_timing -max_paths 10 -to clk_rwds_sample1                                                       > ./${TRIAL_DIR}/reports/timing_rwds1_sample_clock.rpt
report_timing -max_paths 10 -to clk_rwds_delayed0                                                      > ./${TRIAL_DIR}/reports/timing_rwds0_delayed_clock.rpt
report_timing -max_paths 10 -to clk_rwds_delayed1                                                      > ./${TRIAL_DIR}/reports/timing_rwds1_delayed_clock.rpt

####################################################################
## WRITE OUT CONSTRAINTS
####################################################################
write_sdc   ../innovus/src/constraints.sdc

####################################################################
## START GUI
####################################################################
sh date
sh echo "Current git version is `git rev-parse --short HEAD`"
sh echo "Synthesis of hyperbus has finished."
start_gui
