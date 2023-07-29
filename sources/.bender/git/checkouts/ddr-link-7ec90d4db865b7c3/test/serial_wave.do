onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_serial_link/fix/clk
add wave -noupdate /tb_serial_link/fix/rst_n
add wave -noupdate -expand -group ddr_phy /tb_serial_link/fix/ddr_ext_clk
add wave -noupdate -expand -group ddr_phy -expand /tb_serial_link/fix/ddr_o
add wave -noupdate -expand -group ddr_phy -expand /tb_serial_link/fix/ddr_i
add wave -noupdate -group {DDR 1 AXI} -expand /tb_serial_link/fix/ddr_1_in_req
add wave -noupdate -group {DDR 1 AXI} -expand /tb_serial_link/fix/ddr_1_in_rsp
add wave -noupdate -group {DDR 1 AXI} /tb_serial_link/fix/ddr_1_out_req
add wave -noupdate -group {DDR 1 AXI} /tb_serial_link/fix/ddr_1_out_rsp
add wave -noupdate -group {DDR 2 AXI} /tb_serial_link/fix/ddr_2_in_req
add wave -noupdate -group {DDR 2 AXI} /tb_serial_link/fix/ddr_2_in_rsp
add wave -noupdate -group {DDR 2 AXI} -expand /tb_serial_link/fix/ddr_2_out_req
add wave -noupdate -group {DDR 2 AXI} -expand /tb_serial_link/fix/ddr_2_out_rsp
add wave -noupdate -group {DDR 1 AXI CUT} -expand /tb_serial_link/fix/ddr_1_out_req_cut
add wave -noupdate -group {DDR 1 AXI CUT} -expand /tb_serial_link/fix/ddr_1_out_rsp_cut
add wave -noupdate -group {DDR 2 AXI CUT} -expand /tb_serial_link/fix/ddr_2_out_req_cut
add wave -noupdate -group {DDR 2 AXI CUT} -expand /tb_serial_link/fix/ddr_2_out_rsp_cut
add wave -noupdate -group {MEM 1 AXI} -expand /tb_serial_link/fix/i_axi_to_mem_1/axi_req_i
add wave -noupdate -group {MEM 1 AXI} -expand /tb_serial_link/fix/i_axi_to_mem_1/axi_resp_o
add wave -noupdate -group {MEM 2 AXI} -expand /tb_serial_link/fix/i_axi_to_mem_2/axi_req_i
add wave -noupdate -group {MEM 2 AXI} -expand -subitemconfig {/tb_serial_link/fix/i_axi_to_mem_2/axi_resp_o.r -expand} /tb_serial_link/fix/i_axi_to_mem_2/axi_resp_o
add wave -noupdate -group {PHY STATES} -label {phy out state 1} /tb_serial_link/fix/i_serial_link_1/phy_out_state_q
add wave -noupdate -group {PHY STATES} -label {phy in state 1} /tb_serial_link/fix/i_serial_link_1/phy_in_state_q
add wave -noupdate -group {PHY STATES} -label {phy out state 2} /tb_serial_link/fix/i_serial_link_2/phy_out_state_q
add wave -noupdate -group {PHY STATES} -label {phy in state 2} /tb_serial_link/fix/i_serial_link_2/phy_in_state_q
add wave -noupdate -group {MAC STATES} -label {mst state 1} /tb_serial_link/fix/i_serial_link_1/mst_state_q
add wave -noupdate -group {MAC STATES} -label {slv state 1} /tb_serial_link/fix/i_serial_link_1/slv_state_q
add wave -noupdate -group {MAC STATES} -label {mst state 2} /tb_serial_link/fix/i_serial_link_2/mst_state_q
add wave -noupdate -group {MAC STATES} -label {slv state 2} /tb_serial_link/fix/i_serial_link_2/slv_state_q
add wave -noupdate -group {MEM 1 } /tb_serial_link/fix/i_axi_to_mem_1/clk_i
add wave -noupdate -group {MEM 1 } /tb_serial_link/fix/i_axi_to_mem_1/rst_ni
add wave -noupdate -group {MEM 1 } /tb_serial_link/fix/i_axi_to_mem_1/busy_o
add wave -noupdate -group {MEM 1 } /tb_serial_link/fix/i_axi_to_mem_1/mem_req_o
add wave -noupdate -group {MEM 1 } /tb_serial_link/fix/i_axi_to_mem_1/mem_gnt_i
add wave -noupdate -group {MEM 1 } /tb_serial_link/fix/i_axi_to_mem_1/mem_addr_o
add wave -noupdate -group {MEM 1 } /tb_serial_link/fix/i_axi_to_mem_1/mem_wdata_o
add wave -noupdate -group {MEM 1 } /tb_serial_link/fix/i_axi_to_mem_1/mem_strb_o
add wave -noupdate -group {MEM 1 } /tb_serial_link/fix/i_axi_to_mem_1/mem_atop_o
add wave -noupdate -group {MEM 1 } /tb_serial_link/fix/i_axi_to_mem_1/mem_we_o
add wave -noupdate -group {MEM 1 } /tb_serial_link/fix/i_axi_to_mem_1/mem_rvalid_i
add wave -noupdate -group {MEM 1 } /tb_serial_link/fix/i_axi_to_mem_1/mem_rdata_i
add wave -noupdate -group {MEM 2} /tb_serial_link/fix/i_axi_to_mem_2/clk_i
add wave -noupdate -group {MEM 2} /tb_serial_link/fix/i_axi_to_mem_2/rst_ni
add wave -noupdate -group {MEM 2} /tb_serial_link/fix/i_axi_to_mem_2/busy_o
add wave -noupdate -group {MEM 2} /tb_serial_link/fix/i_axi_to_mem_2/mem_req_o
add wave -noupdate -group {MEM 2} /tb_serial_link/fix/i_axi_to_mem_2/mem_gnt_i
add wave -noupdate -group {MEM 2} /tb_serial_link/fix/i_axi_to_mem_2/mem_addr_o
add wave -noupdate -group {MEM 2} /tb_serial_link/fix/i_axi_to_mem_2/mem_wdata_o
add wave -noupdate -group {MEM 2} /tb_serial_link/fix/i_axi_to_mem_2/mem_strb_o
add wave -noupdate -group {MEM 2} /tb_serial_link/fix/i_axi_to_mem_2/mem_atop_o
add wave -noupdate -group {MEM 2} /tb_serial_link/fix/i_axi_to_mem_2/mem_we_o
add wave -noupdate -group {MEM 2} /tb_serial_link/fix/i_axi_to_mem_2/mem_rvalid_i
add wave -noupdate -group {MEM 2} /tb_serial_link/fix/i_axi_to_mem_2/mem_rdata_i
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {8568557 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 220
configure wave -valuecolwidth 40
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
configure wave -timelineunits ps
update
WaveRestoreZoom {7957281 ps} {8018755 ps}
