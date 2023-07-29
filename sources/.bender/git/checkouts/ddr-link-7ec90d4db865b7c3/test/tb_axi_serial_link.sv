// Copyright 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Paul Scheffler <paulsc@iis.ee.ethz.ch>
// Author: Thomas Benz <tbenz@iis.ee.ethz.ch>


module tb_axi_serial_link();

  `include "axi/assign.svh"
  `include "axi/typedef.svh"

  // ==============
  //    Config
  // ==============

  localparam int unsigned IdWidth      = 16;
  localparam int unsigned AddrWidth    = 64;
  localparam int unsigned DataWidth    = 512;
  localparam int unsigned StrbWidth    = DataWidth / 8;
  localparam int unsigned LogDataBytes = $clog2(StrbWidth);
  localparam int unsigned UserWidth    = 1;

  localparam time         TckDdr          = 10ns;
  localparam time         TckSys          = 5ns;
  localparam int unsigned RstClkCyclesSys = 1;

  // ==============
  //    DDR Link
  // ==============

  // AXI types for model
  typedef logic [IdWidth-1:0  ]  ddr_id_t;
  typedef logic [AddrWidth-1:0]  ddr_addr_t;
  typedef logic [DataWidth-1:0]  ddr_data_t;
  typedef logic [StrbWidth-1:0]  ddr_strb_t;
  typedef logic [UserWidth-1:0]  ddr_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(ddr_aw_chan_t, ddr_addr_t, ddr_id_t, ddr_user_t)
  `AXI_TYPEDEF_W_CHAN_T(ddr_w_chan_t, ddr_data_t, ddr_strb_t, ddr_user_t)
  `AXI_TYPEDEF_B_CHAN_T(ddr_b_chan_t, ddr_id_t, ddr_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ddr_ar_chan_t, ddr_addr_t, ddr_id_t, ddr_user_t)
  `AXI_TYPEDEF_R_CHAN_T(ddr_r_chan_t, ddr_data_t, ddr_id_t, ddr_user_t)
  `AXI_TYPEDEF_REQ_T(ddr_req_t, ddr_aw_chan_t, ddr_w_chan_t, ddr_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(ddr_resp_t, ddr_b_chan_t, ddr_r_chan_t)

  // Reqbus types for model
  typedef struct packed {
    logic [31:0]  addr;
    logic         write;
    logic [31:0]  wdata;
    logic [3:0]   wstrb;
    logic         valid;
  } ddr_reg_req_t;

  typedef struct packed {
    logic [31:0]  rdata;
    logic         error;
    logic         ready;
  } ddr_reg_rsp_t;

  // Model signals
  logic         ddr_ext_clk;
  ddr_req_t     ddr_1_out_req, ddr_2_out_req;
  ddr_resp_t    ddr_1_out_rsp, ddr_2_out_rsp;
  ddr_req_t     ddr_1_in_req,  ddr_2_in_req;
  ddr_resp_t    ddr_1_in_rsp,  ddr_2_in_rsp;
  ddr_reg_req_t ddr_1_cfg_req;
  ddr_reg_rsp_t ddr_1_cfg_resp;
  ddr_reg_req_t ddr_2_cfg_req;
  ddr_reg_rsp_t ddr_2_cfg_resp;

  // link
  wire [3:0] ddr_o;
  wire [3:0] ddr_i;

  // clock and reset
  logic clk;
  logic rst_n;
  // DDR link clock and reset
  clk_rst_gen #(
    .ClkPeriod    ( TckDdr        ),
    .RstClkCycles ( 5             )
  ) i_clk_rst_gen_ddr (
    .clk_o  ( ddr_ext_clk ),
    .rst_no (  )
  );

  // system clock and reset
  clk_rst_gen #(
    .ClkPeriod    ( TckSys           ),
    .RstClkCycles ( RstClkCyclesSys  )
  ) i_clk_rst_gen_sys (
    .clk_o  ( clk    ),
    .rst_no ( rst_n  )
  );

  // first serial instance
  serial_link #(
    .axi_req_t        ( ddr_req_t       ),
    .axi_rsp_t        ( ddr_resp_t      ),
    .aw_chan_t        ( ddr_aw_chan_t   ),
    .ar_chan_t        ( ddr_ar_chan_t   ),
    .cfg_req_t        ( ddr_reg_req_t   ),
    .cfg_rsp_t        ( ddr_reg_rsp_t   )
  ) i_serial_link_1 (
      .clk_i          ( clk             ),
      .rst_ni         ( rst_n           ),
      .testmode_i     ( 1'b0            ),
      .axi_in_req_i   ( ddr_1_in_req    ),
      .axi_in_rsp_o   ( ddr_1_in_rsp    ),
      .axi_out_req_o  ( ddr_1_out_req   ),
      .axi_out_rsp_i  ( ddr_1_out_rsp   ),
      .cfg_req_i      ( ddr_1_cfg_req   ),
      .cfg_rsp_o      ( ddr_1_cfg_resp  ),
      .ddr_clk_i      ( ddr_ext_clk     ),
      .ddr_i          ( ddr_i           ),
      .ddr_o          ( ddr_o           )
  );

  // second serial instance
  serial_link #(
    .axi_req_t        ( ddr_req_t       ),
    .axi_rsp_t        ( ddr_resp_t      ),
    .aw_chan_t        ( ddr_aw_chan_t   ),
    .ar_chan_t        ( ddr_ar_chan_t   ),
    .cfg_req_t        ( ddr_reg_req_t   ),
    .cfg_rsp_t        ( ddr_reg_rsp_t   )
  ) i_serial_link_2 (
      .clk_i          ( clk             ),
      .rst_ni         ( rst_n           ),
      .testmode_i     ( 1'b0            ),
      .axi_in_req_i   ( ddr_2_in_req    ),
      .axi_in_rsp_o   ( ddr_2_in_rsp    ),
      .axi_out_req_o  ( ddr_2_out_req   ),
      .axi_out_rsp_i  ( ddr_2_out_rsp   ),
      .cfg_req_i      ( ddr_2_cfg_req   ),
      .cfg_rsp_o      ( ddr_2_cfg_resp  ),
      .ddr_clk_i      ( ddr_ext_clk     ),
      .ddr_i          ( ddr_o           ),
      .ddr_o          ( ddr_i           )
  );

  assign ddr_1_cfg_req = '0;
  assign ddr_2_cfg_req = '0;

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( AddrWidth    ),
    .AXI_DATA_WIDTH ( DataWidth    ),
    .AXI_ID_WIDTH   ( IdWidth      ),
    .AXI_USER_WIDTH ( UserWidth    )
  ) ddr_1_in(clk), ddr_2_out(clk);

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( AddrWidth    ),
    .AXI_DATA_WIDTH ( DataWidth    ),
    .AXI_ID_WIDTH   ( IdWidth      ),
    .AXI_USER_WIDTH ( UserWidth    )
  ) ddr_2_in(clk), ddr_1_out(clk);

  `AXI_ASSIGN_TO_REQ(ddr_1_in_req, ddr_1_in)
  `AXI_ASSIGN_FROM_RESP(ddr_1_in, ddr_1_in_rsp)

  `AXI_ASSIGN_TO_REQ(ddr_2_in_req, ddr_2_in)
  `AXI_ASSIGN_FROM_RESP(ddr_2_in, ddr_2_in_rsp)

  `AXI_ASSIGN_FROM_REQ(ddr_1_out, ddr_1_out_req)
  `AXI_ASSIGN_TO_RESP(ddr_1_out_rsp, ddr_1_out)

  `AXI_ASSIGN_FROM_REQ(ddr_2_out, ddr_2_out_req)
  `AXI_ASSIGN_TO_RESP(ddr_2_out_rsp, ddr_2_out)

  // master type
  typedef axi_test::axi_rand_master #(
    .AW                   ( AddrWidth          ),
    .DW                   ( DataWidth          ),
    .IW                   ( IdWidth            ),
    .UW                   ( UserWidth          ),
    .TA                   ( 100ps              ),
    .TT                   ( 500ps              ),
    .MAX_READ_TXNS        ( 2                  ),
    .MAX_WRITE_TXNS       ( 2                  ),
    .AX_MIN_WAIT_CYCLES   ( 0                  ),
    .AX_MAX_WAIT_CYCLES   ( 100                ),
    .W_MIN_WAIT_CYCLES    ( 0                  ),
    .W_MAX_WAIT_CYCLES    ( 100                ),
    .RESP_MIN_WAIT_CYCLES ( 0                  ),
    .RESP_MAX_WAIT_CYCLES ( 100                ),
    .AXI_MAX_BURST_LEN    ( 0                  ),
    .TRAFFIC_SHAPING      ( 0                  ),
    .AXI_EXCLS            ( 1'b1               ),
    .AXI_ATOPS            ( 1'b0               ),
    .AXI_BURST_FIXED      ( 1'b1               ),
    .AXI_BURST_INCR       ( 1'b1               ),
    .AXI_BURST_WRAP       ( 1'b1               )
  ) axi_rand_master_t;

  // slave type
  typedef axi_test::axi_rand_slave #(
    .AW                   ( AddrWidth          ),
    .DW                   ( DataWidth          ),
    .IW                   ( IdWidth            ),
    .UW                   ( UserWidth          ),
    .TA                   ( 100ps              ),
    .TT                   ( 500ps              ),
    .RAND_RESP            ( 0                  ),
    .AX_MIN_WAIT_CYCLES   ( 0                  ),
    .AX_MAX_WAIT_CYCLES   ( 100                ),
    .R_MIN_WAIT_CYCLES    ( 0                  ),
    .R_MAX_WAIT_CYCLES    ( 100                ),
    .RESP_MIN_WAIT_CYCLES ( 0                  ),
    .RESP_MAX_WAIT_CYCLES ( 100                )
  ) axi_rand_slave_t;

  static axi_rand_master_t axi_rand_master_1 = new ( ddr_1_in  );
  static axi_rand_master_t axi_rand_master_2 = new ( ddr_2_in  );

  static axi_rand_slave_t axi_rand_slave_1   = new ( ddr_1_out );
  static axi_rand_slave_t axi_rand_slave_2   = new ( ddr_2_out );

  logic [1:0] mst_done;

  initial begin
    axi_rand_slave_1.reset();
    wait_for_reset();
    wait_for_link_1_train_complete();
    wait_for_link_2_train_complete();
    axi_rand_slave_1.run();
  end

  initial begin
    axi_rand_slave_2.reset();
    wait_for_reset();
    wait_for_link_1_train_complete();
    wait_for_link_2_train_complete();
    axi_rand_slave_2.run();
  end

  initial begin
    mst_done[0] = 0;
    axi_rand_master_1.reset();
    wait_for_reset();
    wait_for_link_1_train_complete();
    wait_for_link_2_train_complete();
    axi_rand_master_1.run(250, 250);
    mst_done[0] = 1;
  end

  initial begin
    mst_done[1] = 0;
    axi_rand_master_2.reset();
    wait_for_reset();
    wait_for_link_1_train_complete();
    wait_for_link_2_train_complete();
    axi_rand_master_2.run(250, 250);
    mst_done[1] = 1;
  end

  initial begin
    while (mst_done != '1) begin
      @(posedge clk);
    end
    stop_sim();
  end

  // ==============
  //    Checks
  // ==============

  axi_channel_compare #(
    .aw_chan_t ( ddr_aw_chan_t ),
    .w_chan_t  ( ddr_w_chan_t  ),
    .b_chan_t  ( ddr_b_chan_t  ),
    .ar_chan_t ( ddr_ar_chan_t ),
    .r_chan_t  ( ddr_r_chan_t  ),
    .req_t     ( ddr_req_t     ),
    .resp_t    ( ddr_resp_t    )
  ) i_axi_channel_compare_1_to_2 (
    .clk_i     ( clk            ),
    .axi_a_req ( ddr_1_in_req   ),
    .axi_a_res ( ddr_1_in_rsp   ),
    .axi_b_req ( ddr_2_out_req  ),
    .axi_b_res ( ddr_2_out_rsp  )
  );

  axi_channel_compare #(
    .aw_chan_t ( ddr_aw_chan_t ),
    .w_chan_t  ( ddr_w_chan_t  ),
    .b_chan_t  ( ddr_b_chan_t  ),
    .ar_chan_t ( ddr_ar_chan_t ),
    .r_chan_t  ( ddr_r_chan_t  ),
    .req_t     ( ddr_req_t     ),
    .resp_t    ( ddr_resp_t    )
  ) i_axi_channel_compare_2_to_1 (
    .clk_i     ( clk            ),
    .axi_a_req ( ddr_2_in_req   ),
    .axi_a_res ( ddr_2_in_rsp   ),
    .axi_b_req ( ddr_1_out_req  ),
    .axi_b_res ( ddr_1_out_rsp  )
  );

  // ==============
  //    Tasks
  // ==============

  task automatic wait_for_reset();
    @(posedge rst_n);
    $display("[SYS] Reset complete");
  endtask

  task automatic wait_for_link_1_train_complete();
    while(i_serial_link_1.phy_in_state_q != i_serial_link_1.PHYIdle) begin
      @(posedge clk);
    end
    $display("[DDR1] Calibration Done");
  endtask

  task automatic wait_for_link_2_train_complete();
    while(i_serial_link_2.phy_in_state_q != i_serial_link_2.PHYIdle) begin
      @(posedge clk);
    end
    $display("[DDR2] Calibration Done");
  endtask

  task automatic stop_sim();
    repeat(50) begin
      @(posedge clk);
    end
    $display("[SYS] Simulation Stopped (%d ns)", $time);
    $stop();
  endtask

endmodule : tb_axi_serial_link
