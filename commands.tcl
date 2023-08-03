cd [get_property DIRECTORY [current_project]]
source ./sources/alsaqr/tcl/generated/compile.tcl
set_property top alsaqr_xilinx [current_fileset]

# add ip distributed memory generator and name it: xilinx_rom_bank_1024x64 if version option is available: version=8.0
# add ip clk_wiz and name it: xilinx_clk_mngr
# add ip ddr4 and name it ddr4_0
# add ip axi quad spi and name it xilinx_qspi

set_property -dict [list CONFIG.depth {1024} CONFIG.data_width {64} CONFIG.memory_type {rom} CONFIG.input_options {registered} CONFIG.output_options {non_registered} CONFIG.single_port_output_clock_enable {false} CONFIG.default_data {ffffffff}] [get_ips  xilinx_rom_bank_1024x64]

set_property -dict [list CONFIG.PRIM_IN_FREQ {250.000} \
                        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50} \
                        CONFIG.RESET_TYPE {ACTIVE_LOW} \
                        CONFIG.CLKIN1_JITTER_PS {40.0} \
                        CONFIG.MMCM_DIVCLK_DIVIDE {25} \
                        CONFIG.MMCM_CLKFBOUT_MULT_F {105.750} \
                        CONFIG.MMCM_CLKIN1_PERIOD {4.000} \
                        CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
                        CONFIG.MMCM_CLKOUT0_DIVIDE_F {88.125} \
                        CONFIG.RESET_PORT {resetn} \
                        CONFIG.CLKOUT1_JITTER {350.612} \
                        CONFIG.CLKOUT1_PHASE_ERROR {426.712} ] [get_ips xilinx_clk_mngr]
                        
set_property -dict [list CONFIG.C0.DDR4_TimePeriod {1600} \
                        CONFIG.C0.DDR4_InputClockPeriod {4000} \
                        CONFIG.C0.DDR4_Specify_MandD {false} \
                        CONFIG.C0.DDR4_CLKOUT0_DIVIDE {8} \
                        CONFIG.C0.DDR4_MemoryPart {MT40A256M16GE-083E} \
                        CONFIG.C0.DDR4_DataWidth {16} \
                        CONFIG.C0.DDR4_AxiSelection {true} \
                        CONFIG.C0.DDR4_AUTO_AP_COL_A3 {true} \
                        CONFIG.C0.DDR4_CasLatency {9} CONFIG.C0.DDR4_CasWriteLatency {9} \
                        CONFIG.C0.DDR4_AxiDataWidth {64} CONFIG.C0.DDR4_AxiAddressWidth {29} \
                        CONFIG.C0.DDR4_AxiIDWidth {8} \
                        CONFIG.C0.BANK_GROUP_WIDTH {1} \
                        CONFIG.System_Clock {No_Buffer} ] [get_ips ddr4_0]
                        
set_property -dict [list CONFIG.C_SPI_MEMORY {2} CONFIG.C_USE_STARTUP {1} CONFIG.C_USE_STARTUP_INT {1} CONFIG.C_SPI_MODE {2} CONFIG.C_SCK_RATIO {2}] [get_ips xilinx_qspi]

update_compile_order -fileset sources_1
auto_detect_xpm

add_files -fileset constrs_1 -norecurse "./sources/alsaqr/tcl/fmc_board_vcu118.xdc"
add_files -fileset constrs_1 -norecurse "./sources/alsaqr/tcl/ddr_vcu118.xdc"
add_files -fileset constrs_1 -norecurse "./sources/alsaqr/tcl/fmc_board_validation_vcu118.xdc"
read_xdc ./sources/alsaqr/tcl/constraints.xdc
add_files -fileset constrs_1 -norecurse "./sources/alsaqr/tcl/constraints_peripherals.xdc"


                        


