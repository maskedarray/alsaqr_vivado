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


module fixture_serial_link();

  `include "axi/assign.svh"
  `include "axi/typedef.svh"

  // ==============
  //    Config
  // ==============

  localparam int unsigned IdWidth2t1   =  6;
  localparam int unsigned IdWidth1t2   =  6;
  localparam int unsigned AddrWidth    = 64;
  localparam int unsigned DataWidth    = 64;
  localparam int unsigned StrbWidth    = DataWidth / 8;
  localparam int unsigned LogDataBytes = $clog2(StrbWidth);
  localparam int unsigned UserWidth    =  1;

  localparam time         TckDdr          = 10ns;
  localparam time         TckSys          = 5ns;
  localparam int unsigned RstClkCyclesSys = 1;

  // ==============
  //    DDR Link
  // ==============

  // AXI types for model
  typedef logic [IdWidth2t1-1:0] ddr_id_2_to_1_t;
  typedef logic [IdWidth1t2-1:0] ddr_id_1_to_2_t;
  typedef logic [AddrWidth-1:0]  ddr_addr_t;
  typedef logic [DataWidth-1:0]  ddr_data_t;
  typedef logic [StrbWidth-1:0]  ddr_strb_t;
  typedef logic [UserWidth-1:0]  ddr_user_t;

  typedef union packed {
    logic [StrbWidth-1:0][7:0] bytes;
    logic [DataWidth-1:0]      data;
  } block_t;

  `AXI_TYPEDEF_AW_CHAN_T(ddr_aw_chan_2_to_1_t, ddr_addr_t, ddr_id_2_to_1_t, ddr_user_t)
  `AXI_TYPEDEF_AW_CHAN_T(ddr_aw_chan_1_to_2_t, ddr_addr_t, ddr_id_1_to_2_t, ddr_user_t)
  `AXI_TYPEDEF_W_CHAN_T(ddr_w_chan_t, ddr_data_t, ddr_strb_t, ddr_user_t)
  `AXI_TYPEDEF_B_CHAN_T(ddr_b_chan_2_to_1_t, ddr_id_2_to_1_t, ddr_user_t)
  `AXI_TYPEDEF_B_CHAN_T(ddr_b_chan_1_to_2_t, ddr_id_1_to_2_t, ddr_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ddr_ar_chan_2_to_1_t, ddr_addr_t, ddr_id_2_to_1_t, ddr_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ddr_ar_chan_1_to_2_t, ddr_addr_t, ddr_id_1_to_2_t, ddr_user_t)
  `AXI_TYPEDEF_R_CHAN_T(ddr_r_chan_2_to_1_t, ddr_data_t, ddr_id_2_to_1_t, ddr_user_t)
  `AXI_TYPEDEF_R_CHAN_T(ddr_r_chan_1_to_2_t, ddr_data_t, ddr_id_1_to_2_t, ddr_user_t)
  `AXI_TYPEDEF_REQ_T(ddr_req_2_to_1_t, ddr_aw_chan_2_to_1_t, ddr_w_chan_t, ddr_ar_chan_2_to_1_t)
  `AXI_TYPEDEF_RESP_T(ddr_resp_2_to_1_t, ddr_b_chan_2_to_1_t, ddr_r_chan_2_to_1_t)
  `AXI_TYPEDEF_REQ_T(ddr_req_1_to_2_t, ddr_aw_chan_1_to_2_t, ddr_w_chan_t, ddr_ar_chan_1_to_2_t)
  `AXI_TYPEDEF_RESP_T(ddr_resp_1_to_2_t, ddr_b_chan_1_to_2_t, ddr_r_chan_1_to_2_t)

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
  logic              ddr_ext_clk;
  ddr_req_1_to_2_t   ddr_1_in_req;
  ddr_resp_1_to_2_t  ddr_1_in_rsp;
  ddr_req_2_to_1_t   ddr_1_out_req, ddr_1_out_req_cut;
  ddr_resp_2_to_1_t  ddr_1_out_rsp, ddr_1_out_rsp_cut;
  ddr_req_2_to_1_t   ddr_2_in_req;
  ddr_resp_2_to_1_t  ddr_2_in_rsp;
  ddr_req_1_to_2_t   ddr_2_out_req, ddr_2_out_req_cut;
  ddr_resp_1_to_2_t  ddr_2_out_rsp, ddr_2_out_rsp_cut;
  ddr_reg_req_t      ddr_1_cfg_req;
  ddr_reg_rsp_t      ddr_1_cfg_resp;
  ddr_reg_req_t      ddr_2_cfg_req;
  ddr_reg_rsp_t      ddr_2_cfg_resp;

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
    .axi_req_t        ( ddr_req_1_to_2_t     ),
    .axi_rsp_t        ( ddr_resp_1_to_2_t    ),
    .aw_chan_t        ( ddr_aw_chan_1_to_2_t ),
    .ar_chan_t        ( ddr_ar_chan_1_to_2_t ),
    .cfg_req_t        ( ddr_reg_req_t        ),
    .cfg_rsp_t        ( ddr_reg_rsp_t        )
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

  // first serial instance
  serial_link #(
    .axi_req_t        ( ddr_req_2_to_1_t     ),
    .axi_rsp_t        ( ddr_resp_2_to_1_t    ),
    .aw_chan_t        ( ddr_aw_chan_2_to_1_t ),
    .ar_chan_t        ( ddr_ar_chan_2_to_1_t ),
    .cfg_req_t        ( ddr_reg_req_t        ),
    .cfg_rsp_t        ( ddr_reg_rsp_t        )
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

  // cut out paths to prevent stalling from serial link sending AW and W after one another,
  // and axi_2_mem requesting both at a time
  axi_multicut #(
    .NoCuts     ( 1                    ),
    .aw_chan_t  ( ddr_aw_chan_2_to_1_t ),
    .w_chan_t   ( ddr_w_chan_t         ),
    .b_chan_t   ( ddr_b_chan_2_to_1_t  ),
    .ar_chan_t  ( ddr_ar_chan_2_to_1_t ),
    .r_chan_t   ( ddr_r_chan_2_to_1_t  ),
    .req_t      ( ddr_req_2_to_1_t     ),
    .resp_t     ( ddr_resp_2_to_1_t    )
  ) i_axi_multicut_1 (
    .clk_i      ( clk                 ),
    .rst_ni     ( rst_n               ),
    .slv_req_i  ( ddr_1_out_req       ),
    .slv_resp_o ( ddr_1_out_rsp       ),
    .mst_req_o  ( ddr_1_out_req_cut   ),
    .mst_resp_i ( ddr_1_out_rsp_cut   )
  );

  axi_multicut #(
    .NoCuts     ( 1                    ),
    .aw_chan_t  ( ddr_aw_chan_1_to_2_t ),
    .w_chan_t   ( ddr_w_chan_t         ),
    .b_chan_t   ( ddr_b_chan_1_to_2_t  ),
    .ar_chan_t  ( ddr_ar_chan_1_to_2_t ),
    .r_chan_t   ( ddr_r_chan_1_to_2_t  ),
    .req_t      ( ddr_req_1_to_2_t     ),
    .resp_t     ( ddr_resp_1_to_2_t    )
  ) i_axi_multicut_2 (
    .clk_i      ( clk                 ),
    .rst_ni     ( rst_n               ),
    .slv_req_i  ( ddr_2_out_req       ),
    .slv_resp_o ( ddr_2_out_rsp       ),
    .mst_req_o  ( ddr_2_out_req_cut   ),
    .mst_resp_i ( ddr_2_out_rsp_cut   )
  );

  // memories
  block_t mem_1 [logic [AddrWidth-1:0]];
  block_t mem_2 [logic [AddrWidth-1:0]];

  block_t model_mem_1 [logic [AddrWidth-1:0]];
  block_t model_mem_2 [logic [AddrWidth-1:0]];

  logic valid_1_q, valid_2_q;
  logic req_1, req_2;

  logic [AddrWidth-1:0] mem_addr_1,  mem_addr_2, mem_addr_1_q, mem_addr_2_q;
  logic [DataWidth-1:0] mem_wdata_1, mem_wdata_2;
  logic [DataWidth-1:0] mem_rdata_1, mem_rdata_2;
  logic [StrbWidth-1:0] mem_strb_1,  mem_strb_2;
  logic                 mem_we_1,    mem_we_2;

  axi_to_mem #(
    .axi_req_t   ( ddr_req_2_to_1_t  ),
    .axi_resp_t  ( ddr_resp_2_to_1_t ),
    .AddrWidth   ( AddrWidth         ),
    .DataWidth   ( DataWidth         ),
    .IdWidth     ( IdWidth2t1        ),
    .NumBanks    ( 1                 ),
    .BufDepth    ( 4                 )
  ) i_axi_to_mem_1 (
    .clk_i       ( clk               ),
    .rst_ni      ( rst_n             ),
    .busy_o      ( ),
    .axi_req_i   ( ddr_1_out_req_cut ),
    .axi_resp_o  ( ddr_1_out_rsp_cut ),
    .mem_req_o   ( req_1             ),
    .mem_gnt_i   ( 1'b1              ),
    .mem_addr_o  ( mem_addr_1        ),
    .mem_wdata_o ( mem_wdata_1       ),
    .mem_strb_o  ( mem_strb_1        ),
    .mem_atop_o  ( ),
    .mem_we_o    ( mem_we_1          ),
    .mem_rvalid_i( valid_1_q         ),
    .mem_rdata_i ( mem_rdata_1       )
  );

  axi_to_mem #(
    .axi_req_t   ( ddr_req_1_to_2_t  ),
    .axi_resp_t  ( ddr_resp_1_to_2_t ),
    .AddrWidth   ( AddrWidth         ),
    .DataWidth   ( DataWidth         ),
    .IdWidth     ( IdWidth1t2        ),
    .NumBanks    ( 1                 ),
    .BufDepth    ( 4                 )
  ) i_axi_to_mem_2 (
    .clk_i       ( clk               ),
    .rst_ni      ( rst_n             ),
    .busy_o      ( ),
    .axi_req_i   ( ddr_2_out_req_cut ),
    .axi_resp_o  ( ddr_2_out_rsp_cut ),
    .mem_req_o   ( req_2             ),
    .mem_gnt_i   ( 1'b1              ),
    .mem_addr_o  ( mem_addr_2        ),
    .mem_wdata_o ( mem_wdata_2       ),
    .mem_strb_o  ( mem_strb_2        ),
    .mem_atop_o  ( ),
    .mem_we_o    ( mem_we_2          ),
    .mem_rvalid_i( valid_2_q         ),
    .mem_rdata_i ( mem_rdata_2       )
  );

  // answer macro
  always_ff @(posedge clk or negedge rst_n) begin
      if(~rst_n) begin
        valid_1_q <= '0;
        valid_2_q <= '0;
        mem_addr_1_q <= '0;
        mem_addr_2_q <= '0;
      end else begin
        valid_1_q <= req_1 & 1;
        valid_2_q <= req_2 & 1;
        mem_addr_1_q <= mem_addr_1;
        mem_addr_2_q <= mem_addr_2;
      end
  end

  // write mem 1
  always_ff @(posedge clk) begin
    if (mem_we_1 & req_1) begin
      for (int i = 0; i < StrbWidth; i++) begin
        if (mem_strb_1[i]) begin
          mem_1[mem_addr_1].bytes[i] = mem_wdata_1[i*8+:8];
        end
      end
    end
  end

  // write mem 2
  always_ff @(posedge clk) begin
    if (mem_we_2 & req_2) begin
      for (int i = 0; i < StrbWidth; i++) begin
        if (mem_strb_2[i]) begin
          mem_2[mem_addr_2].bytes[i] = mem_wdata_2[i*8+:8];
        end
      end
    end
  end

  // read mem 1
  always_comb begin
    if (mem_1.exists(mem_addr_1_q))
      mem_rdata_1 = mem_1[mem_addr_1_q].data;
    else
      mem_rdata_1 = 'x;
  end

  // read mem 2
  always_comb begin
    if (mem_2.exists(mem_addr_2_q))
      mem_rdata_2 = mem_2[mem_addr_2_q].data;
    else
      mem_rdata_2 = 'x;
  end

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( AddrWidth    ),
    .AXI_DATA_WIDTH ( DataWidth    ),
    .AXI_ID_WIDTH   ( IdWidth1t2   ),
    .AXI_USER_WIDTH ( UserWidth    )
  ) ddr_1_in(clk), ddr_2_out(clk);

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( AddrWidth    ),
    .AXI_DATA_WIDTH ( DataWidth    ),
    .AXI_ID_WIDTH   ( IdWidth2t1   ),
    .AXI_USER_WIDTH ( UserWidth    )
  ) ddr_2_in(clk), ddr_1_out(clk);

  `AXI_ASSIGN_TO_REQ(ddr_1_in_req, ddr_1_in)
  `AXI_ASSIGN_FROM_RESP(ddr_1_in, ddr_1_in_rsp)

  `AXI_ASSIGN_TO_REQ(ddr_2_in_req, ddr_2_in)
  `AXI_ASSIGN_FROM_RESP(ddr_2_in, ddr_2_in_rsp)

  typedef axi_test::axi_driver #(
    .AW ( AddrWidth      ),
    .DW ( DataWidth      ),
    .IW ( IdWidth1t2     ),
    .UW ( UserWidth      ),
    .TA ( 100ps          ),
    .TT ( 500ps          )
  ) ddr_1_driver_in_t;

  typedef axi_test::axi_driver #(
    .AW ( AddrWidth      ),
    .DW ( DataWidth      ),
    .IW ( IdWidth2t1     ),
    .UW ( UserWidth      ),
    .TA ( 100ps          ),
    .TT ( 500ps          )
  ) ddr_2_driver_in_t;

  ddr_1_driver_in_t ddr_1_driver_in = new(ddr_1_in);
  ddr_2_driver_in_t ddr_2_driver_in = new(ddr_2_in);

  initial begin
    @(negedge rst_n);
    ddr_1_driver_in.reset_master();
    ddr_2_driver_in.reset_master();
  end

  // TODO: tasks to send config requests and receive responses
  assign ddr_1_cfg_req = '0;
  assign ddr_2_cfg_req = '0;

task automatic ddr_1_write_size_link(
    input logic [AddrWidth-1:0]  addr,
    input logic [3:0]            size,
    ref logic   [DataWidth-1:0]  data [$]    // Actual lanes
  );
    automatic ddr_1_driver_in_t::ax_beat_t ax = new();
    automatic ddr_1_driver_in_t::w_beat_t w = new();
    automatic ddr_1_driver_in_t::b_beat_t b;
    automatic int i = 0;
    automatic int size_bytes = (1 << size);
    @(posedge clk);
    $display("[DDR1] Write address: %h, len: %0d", addr, data.size()-1);
    ax.ax_addr  = addr;
    ax.ax_id    = 7;
    ax.ax_len   = data.size() - 1;
    ax.ax_size  = size;
    ax.ax_burst = axi_pkg::BURST_INCR;
    ax.ax_region = 2;
    ax.ax_prot   = 1;
    ax.ax_cache  = 3;
    ax.ax_qos    = 1;
    $write("[DDR1] - Sending AW... ");
    ddr_1_driver_in.send_aw(ax);
    $display("OK (1)");
    do begin
      w.w_strb = (~('1 << size_bytes)) << addr[LogDataBytes-1:0];
      w.w_data = data[i];
      w.w_last = (i == ax.ax_len);
      $write("[DDR1] - Sending W... ");
      ddr_1_driver_in.send_w(w);
      $display("OK (1)");
      i++;
      addr += size_bytes;
      addr &= size_bytes - 1;
    end while (i <= ax.ax_len);
    $write("[DDR1] - Waiting for B... ");
    ddr_1_driver_in.recv_b(b);
    $display("OK (1)");
  endtask

  task automatic ddr_1_read_size_link(
    input logic [AddrWidth-1:0]  addr,
    input logic [3:0]            size,
    input logic [7:0]            len,
    ref logic   [DataWidth-1:0]  data [$]
  );
    automatic ddr_1_driver_in_t::ax_beat_t ax = new();
    automatic ddr_1_driver_in_t::r_beat_t r;
    automatic int i = 0;
    @(posedge clk);
    $display("[DDR1] Read address: %h, len: %0d", addr, len);
    ax.ax_addr  = addr;
    ax.ax_id    = '0;
    ax.ax_len   = len;
    ax.ax_size  = size;
    ax.ax_burst = axi_pkg::BURST_INCR;
    $write("[DDR1] - Sending AR... ");
    ddr_1_driver_in.send_ar(ax);
    $display("OK (1)");
    do begin
      $write("[DDR1] - Sending R... ");
      ddr_1_driver_in.recv_r(r);
      $display("OK (1)");
      // data.push_front(r.r_data & ((~('1 << (8 << size))) << (addr[$clog2(AddrWidth):0] * 8)));
      data.push_back(r.r_data);
      i++;
      addr += (1 << size);
      addr &= (1 << size) - 1;
    end while (!r.r_last);
  endtask

task automatic ddr_2_write_size_link(
    input logic [AddrWidth-1:0]  addr,
    input logic [3:0]            size,
    ref logic   [DataWidth-1:0]  data [$]    // Actual lanes
  );
    automatic ddr_2_driver_in_t::ax_beat_t ax = new();
    automatic ddr_2_driver_in_t::w_beat_t w = new();
    automatic ddr_2_driver_in_t::b_beat_t b;
    automatic int i = 0;
    automatic int size_bytes = (1 << size);
    @(posedge clk);
    $display("[DDR2] Write address: %h, len: %0d", addr, data.size()-1);
    ax.ax_addr  = addr;
    ax.ax_id    = '0;
    ax.ax_len   = data.size() - 1;
    ax.ax_size  = size;
    ax.ax_burst = axi_pkg::BURST_INCR;
    $write("[DDR2] - Sending AW... ");
    ddr_2_driver_in.send_aw(ax);
    $display("OK (2)");
    do begin
      w.w_strb = (~('1 << size_bytes)) << addr[LogDataBytes-1:0];
      w.w_data = data[i];
      w.w_last = (i == ax.ax_len);
      $write("[DDR2] - Sending W... ");
      ddr_2_driver_in.send_w(w);
      $display("OK (2)");
      i++;
      addr += size_bytes;
      addr &= size_bytes - 1;
    end while (i <= ax.ax_len);
    $write("[DDR2] - Waiting for B... ");
    ddr_2_driver_in.recv_b(b);
    $display("OK (2)");
  endtask

  task automatic ddr_2_read_size_link(
    input logic [AddrWidth-1:0]  addr,
    input logic [3:0]            size,
    input logic [7:0]            len,
    ref logic   [DataWidth-1:0]  data [$]
  );
    automatic ddr_2_driver_in_t::ax_beat_t ax = new();
    automatic ddr_2_driver_in_t::r_beat_t r;
    automatic int i = 0;
    @(posedge clk);
    $display("[DDR2] Read address: %h, len: %0d", addr, len);
    ax.ax_addr  = addr;
    ax.ax_id    = '0;
    ax.ax_len   = len;
    ax.ax_size  = size;
    ax.ax_burst = axi_pkg::BURST_INCR;
    $write("[DDR2] - Sending AR... ");
    ddr_2_driver_in.send_ar(ax);
    $display("OK (2)");
    do begin
      $write("[DDR2] - Sending R... ");
      ddr_2_driver_in.recv_r(r);
      $display("OK (2)");
      // data.push_back(r.r_data & ((~('1 << (8 << size))) << (addr[$clog2(AddrWidth):0] * 8)));
      data.push_back(r.r_data);
      i++;
      addr += (1 << size);
      addr &= (1 << size) - 1;
    end while (!r.r_last);
  endtask

  // model memory tasks
  task automatic ddr_1_write_size_model(
    input logic [AddrWidth-1:0]  addr,
    input logic [3:0]            size,
    ref logic   [DataWidth-1:0]  data [$]
  );
    automatic int size_bytes = (1 << size);
    automatic int i = 0;
    automatic int j = 0;
    automatic logic [StrbWidth-1:0] strb = 0;
    automatic logic [AddrWidth-1:0] waddr = 0;
    // write
    repeat(data.size()) begin
      waddr = (addr >> LogDataBytes) << LogDataBytes;
      strb = ((1 << size_bytes) - 1) << addr[LogDataBytes-1:0];
      repeat(StrbWidth) begin
        if (strb[j] == 1) begin
          model_mem_2[waddr].bytes[j] = data[i][8*j +: 8];
          $display("[Model1] Write %h to %h", data[i][8*j +: 8], waddr + j);
        end
        j++;
      end
      i++;
      addr += size_bytes;
      addr &= size_bytes - 1;
    end
  endtask

  task automatic ddr_1_read_size_model(
    input logic [AddrWidth-1:0]  addr,
    input logic [3:0]            size,
    input logic [7:0]            len,
    ref logic   [DataWidth-1:0]  data [$]
  );
    automatic int size_bytes = (1 << size);
    automatic int i = 0;
    automatic logic [AddrWidth-1:0] raddr = 0;
    automatic logic [DataWidth-1:0] rdata = 0;
    // read
    repeat(len + 1) begin
      raddr = (addr >> LogDataBytes) << LogDataBytes;
      if(model_mem_2.exists(raddr))
        rdata = model_mem_2[raddr].data;
      else
        rdata = 'x;
      // enqueue
      data.push_back(rdata);
      $display("[Model1] Read %h from %h", rdata, raddr);
      i++;
      addr += size_bytes;
    end
  endtask

  task automatic ddr_2_write_size_model(
    input logic [AddrWidth-1:0]  addr,
    input logic [3:0]            size,
    ref logic   [DataWidth-1:0]  data [$]
  );
    automatic int size_bytes = (1 << size);
    automatic int i = 0;
    automatic int j = 0;
    automatic logic [StrbWidth-1:0] strb = 0;
    automatic logic [AddrWidth-1:0] waddr = 0;
    // write
    repeat(data.size()) begin
      waddr = (addr >> LogDataBytes) << LogDataBytes;
      strb = ((1 << size_bytes) - 1) << addr[LogDataBytes-1:0];
      repeat(StrbWidth) begin
        if (strb[j] == 1) begin
          model_mem_1[waddr].bytes[j] = data[i][8*j +: 8];
          $display("[Model2] Write %h to %h", data[i][8*j +: 8], waddr + j);
        end
        j++;
      end
      i++;
      addr += size_bytes;
      addr &= size_bytes - 1;
    end
  endtask

  task automatic ddr_2_read_size_model(
    input logic [AddrWidth-1:0]  addr,
    input logic [3:0]            size,
    input logic [7:0]            len,
    ref logic   [DataWidth-1:0]  data [$]
  );
    automatic int size_bytes = (1 << size);
    automatic int i = 0;
    automatic logic [AddrWidth-1:0] raddr = 0;
    automatic logic [DataWidth-1:0] rdata = 0;
    // read
    repeat(len + 1) begin
      raddr = (addr >> LogDataBytes) << LogDataBytes;
      if(model_mem_1.exists(raddr))
        rdata = model_mem_1[raddr].data;
      else
        rdata = 'x;
      // enqueue
      data.push_back(rdata);
      $display("[Model2] Read %h from %h", rdata, raddr);
      i++;
      addr += size_bytes;
    end
  endtask

  task automatic ddr_1_read_size_direct_memory(
    input logic [AddrWidth-1:0]  addr,
    input logic [3:0]            size,
    input logic [7:0]            len,
    ref logic   [DataWidth-1:0]  data [$]
  );
    automatic int size_bytes = (1 << size);
    automatic int i = 0;
    automatic logic [AddrWidth-1:0] raddr = 0;
    automatic logic [DataWidth-1:0] rdata = 0;
    // read
    repeat(len + 1) begin
      raddr = (addr >> LogDataBytes) << LogDataBytes;
      if(mem_2.exists(raddr))
        rdata = mem_2[raddr].data;
      else
        rdata = 'x;
      // enqueue
      data.push_back(rdata);
      $display("[MEM1] Read %h from %h", rdata, raddr);
      i++;
      addr += size_bytes;
    end
  endtask

  task automatic ddr_2_read_size_direct_memory(
    input logic [AddrWidth-1:0]  addr,
    input logic [3:0]            size,
    input logic [7:0]            len,
    ref logic   [DataWidth-1:0]  data [$]
  );
    automatic int size_bytes = (1 << size);
    automatic int i = 0;
    automatic logic [AddrWidth-1:0] raddr = 0;
    automatic logic [DataWidth-1:0] rdata = 0;
    // read
    repeat(len + 1) begin
      raddr = (addr >> LogDataBytes) << LogDataBytes;
      if(mem_1.exists(raddr))
        rdata = mem_1[raddr].data;
      else
        rdata = 'x;
      // enqueue
      data.push_back(rdata);
      $display("[MEM2] Read %h from %h", rdata, raddr);
      i++;
      addr += size_bytes;
    end
  endtask

  task automatic display_read(
    input logic [7:0]            len,
    ref logic   [DataWidth-1:0]  data [$]
  );
    repeat(len + 1) begin
      $display("%h",data.pop_front());
    end
  endtask

  task automatic ddr_1_write_size(
    input logic [AddrWidth-1:0]  addr,
    input logic [3:0]            size,
    ref logic   [DataWidth-1:0]  data [$]
  );
    ddr_1_write_size_model(addr, size, data);
    ddr_1_write_size_link(addr, size, data);
  endtask

  task automatic ddr_2_write_size(
    input logic [AddrWidth-1:0]  addr,
    input logic [3:0]            size,
    ref logic   [DataWidth-1:0]  data [$]
  );
    ddr_2_write_size_model(addr, size, data);
    ddr_2_write_size_link(addr, size, data);
  endtask

  task automatic ddr_1_read_size_compare(
    input logic [AddrWidth-1:0]  addr,
    input logic [3:0]            size,
    input logic [7:0]            len,
    ref logic   [DataWidth-1:0]  data [$]
  );
    automatic int i = 0;
    automatic logic [DataWidth-1:0] rdata_link  [$];
    automatic logic [DataWidth-1:0] rdata_model [$];
    automatic logic [DataWidth-1:0] rdata_mem   [$];

    ddr_1_read_size_model(addr, size, len, rdata_model);
    ddr_1_read_size_link (addr, size, len, rdata_link);
    ddr_1_read_size_direct_memory(addr, size, len, rdata_mem);

    repeat(len + 1) begin
      if(rdata_link[i] === rdata_model[i]) begin
        data.push_back(rdata_link[i]);
        $display("[DDR1] Transfer %8h - size: %2d, len: %2d matches!", addr, size, len);
      end else begin
        $error("[DDR1] Mismatch with model: %h != model: %h", rdata_link[i], rdata_model[i]);
      end
    end

    repeat(len + 1) begin
      if(rdata_link[i] === rdata_mem[i]) begin
        $display("[DDR1] Transfer %8h - size: %2d, len: %2d matches!", addr, size, len);
      end else begin
        $error("[DDR1] Mismatch in memory: %h != memory: %h", rdata_link[i], rdata_mem[i]);
      end
    end
  endtask

  task automatic ddr_2_read_size_compare(
    input logic [AddrWidth-1:0]  addr,
    input logic [3:0]            size,
    input logic [7:0]            len,
    ref logic   [DataWidth-1:0]  data [$]
  );
    automatic int i = 0;
    automatic logic [DataWidth-1:0] rdata_link  [$];
    automatic logic [DataWidth-1:0] rdata_model [$];
    automatic logic [DataWidth-1:0] rdata_mem   [$];

    ddr_2_read_size_model(addr, size, len, rdata_model);
    ddr_2_read_size_link (addr, size, len, rdata_link);
    ddr_2_read_size_direct_memory(addr, size, len, rdata_mem);

    repeat(len + 1) begin
      if(rdata_link[i] === rdata_mem[i]) begin
        $display("[DDR2] Transfer %8h - size: %2d, len: %2d matches!", addr, size, len);
      end else begin
        $error("[DDR2] Mismatch in memory: %h != memory: %h", rdata_link[i], rdata_mem[i]);
      end
    end

    repeat(len + 1) begin
      if(rdata_link[i] === rdata_model[i]) begin
        data.push_back(rdata_link[i]);
        $display("[DDR2] Transfer %8h - size: %2d, len: %2d matches!", addr, size, len);
      end else begin
        $error("[DDR2] Mismatch with model: %h != model: %h", rdata_link[i], rdata_model[i]);
      end
    end
  endtask

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



endmodule : fixture_serial_link
