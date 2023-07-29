add log -r /*

# No hold violations on CDC dst fifos! There are 2 sync FF for that :)
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_axi_cdc_dst}                                  OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_axi_cdc_dst/*}                                OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_axi_cdc_dst/*/*}                              OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_axi_cdc_dst/*/*/*}                            OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_axi_cdc_dst/*/*/*/*}                          OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_reg_master_cdc_intf}                          OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_reg_master_cdc_intf/*}                        OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_reg_master_cdc_intf/*/*}                      OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/udma_channel_bind_0__i_reg_cdc_master_intf}     OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/udma_channel_bind_0__i_reg_cdc_master_intf/*}   OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/udma_channel_bind_0__i_reg_cdc_master_intf/*/*} OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/udma_channel_bind_1__i_reg_cdc_master_intf}     OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/udma_channel_bind_1__i_reg_cdc_master_intf/*}   OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/udma_channel_bind_1__i_reg_cdc_master_intf/*/*} OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_cdc_fifo_tx/i_dst}                            OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_cdc_fifo_tx/i_dst/*}                          OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_cdc_fifo_tx/i_dst/*/*}                        OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_cdc_fifo_tx/i_dst/*/*/*}                      OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_cdc_fifo_tx/i_src}                            OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_cdc_fifo_tx/i_src/*}                          OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_cdc_fifo_tx/i_src/*/*}                        OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_cdc_fifo_rx/i_dst}                            OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_cdc_fifo_rx/i_dst/*}                          OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_cdc_fifo_rx/i_dst/*/*}                        OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_cdc_fifo_rx/i_dst/*/*/*}                      OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_cdc_fifo_rx/i_src}                            OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_cdc_fifo_rx/i_src/*}                          OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/i_cdc_fifo_rx/i_src/*/*}                        OFF
tcheck_set {/hyperbus_tb/fix/i_dut/i_hyperbus_macro/i_hyperbus_macro/udma_hyper/udma_cfg_outbuff_i/r_tx_en_reg }     OFF

run -all
