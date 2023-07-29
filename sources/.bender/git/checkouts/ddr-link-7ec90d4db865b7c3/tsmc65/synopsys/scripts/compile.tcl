rad
#set_app_var hdlin_sv_enable_rtl_attributes true
lappend link_library ../../models/generic_delay_D4_O2_3P750_1P875_CG1_mid.db
source scripts/analyze.tcl


elaborate serial_link_synth_wrapper -parameters AxiAddrWidth=>32,AxiDataWidth=>64,AxiIdInWidth=>2,AxiIdOutWidth=>2,AxiUserWidth=>1,RegAddrWidth=>32,RegDataWidth=>32

source scripts/constraints/serial_link.tcl
source scripts/constraints/common_cells.tcl


compile_ultra -no_autoungroup
#write_file -format verilog -hierarchy -output out/serial_link.v

report_timing > reports/timing.rpt
