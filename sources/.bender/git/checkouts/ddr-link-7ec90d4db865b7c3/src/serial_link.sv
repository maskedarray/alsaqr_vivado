// Copyright 2020 ETH Zurich
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
// Florian Zaruba <zarubaf@iis.ee.ethz.ch>
// Stefan Mach <smach@iis.ee.ethz.ch>
// Thomas Benz <tbenz@iis.ee.ethz.ch>
// Paul Scheffler <paulsc@iis.ee.ethz.ch>
// Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>

/// A simple serial link to go off-chip
module serial_link #(
  parameter type axi_req_t  = logic,
  parameter type axi_rsp_t  = logic,
  parameter type aw_chan_t  = logic,
  parameter type ar_chan_t  = logic,
  parameter type r_chan_t   = logic,
  parameter type w_chan_t   = logic,
  parameter type b_chan_t   = logic,
  parameter type cfg_req_t  = logic,
  parameter type cfg_rsp_t  = logic
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic       testmode_i,
  input  axi_req_t   axi_in_req_i,
  output axi_rsp_t   axi_in_rsp_o,
  output axi_req_t   axi_out_req_o,
  input  axi_rsp_t   axi_out_rsp_i,
  input  cfg_req_t   cfg_req_i,
  output cfg_rsp_t   cfg_rsp_o,
  input  logic       ddr_clk_i,
  input  logic [3:0] ddr_i,
  output logic [3:0] ddr_o
);

  localparam int DataBits     = $bits(axi_in_rsp_o.r.data);
  localparam int StrbBits     = DataBits / 8;
  localparam int IdBits       = $bits(axi_in_rsp_o.r.id);
  localparam int RUserBits    = $bits(axi_in_rsp_o.r.user);
  localparam int WUserBits    = $bits(axi_in_req_i.w.user);
  localparam int BUserBits    = $bits(axi_in_rsp_o.b.user);

  //                                                    v- response bits ------------v
  localparam int MidBits      = (StrbBits   > (IdBits + 2)) ? StrbBits   : (IdBits + 2);
  localparam int RWUserBits   = (RUserBits  > WUserBits)    ? RUserBits  : WUserBits;
  localparam int UserBits     = (RWUserBits > BUserBits)    ? RWUserBits : BUserBits;

  //                                                            v- last bit
  localparam int PayloadBits  = DataBits + MidBits + UserBits + 1;

  // Header
  localparam int AwHeaderWidth   = $bits(aw_chan_t);
  localparam int ArHeaderWidth   = $bits(ar_chan_t);

  localparam int AxHeaderWidth   = (AwHeaderWidth > ArHeaderWidth) ? AwHeaderWidth : ArHeaderWidth;

  localparam int PhyDataBits  = (AxHeaderWidth > PayloadBits) ? AxHeaderWidth : PayloadBits;

  localparam int DataBytes    = (PhyDataBits + 7) / 8; // ceiling divide
  localparam int LogDataBytes = $clog2(DataBytes);

  localparam bit [7:0] TrainingPattern = 8'b10100101;
  localparam bit [7:0] TrainingPatternRev = {TrainingPattern[3:0], TrainingPattern[7:4]};

  logic ddr_rst_n;
  logic [31:0] phy_cfg_req_addr;

  assign phy_cfg_req_addr = {'h0,phy_cfg_req.addr[2:0]};

  // TODO(zarubaf,fschuiki) ICEBOX: Fix
  // B beats are generated on the write side without the knowledge of the
  // receiver. Hence we also have no means to see whether writes actually
  // succeeded.
  typedef enum logic [7:0]  {
    Idle  = 0,
    TagAW = 1,
    TagW  = 2,
    TagAR = 3,
    TagR  = 4,
    TagB  = 5,
    TagMaskB = (1 << 6), // legacy
    TagMaskCredit = (1 << 7),
    TagMask = TagMaskB | TagMaskCredit
  } tag_e;

  typedef struct packed {
    tag_e tag;
    logic [PhyDataBits-1:0] data;
  } phy_payload_t;

  typedef struct packed {
    logic [ DataBits-1:0] data;
    logic [   IdBits-1:0] id;
    logic [          1:0] resp;
    logic                 last;
    logic [RUserBits-1:0] user;
  } r_payload_t;

  typedef struct packed {
    logic [ DataBits-1:0] data;
    logic [ StrbBits-1:0] strb;
    logic                 last;
    logic [WUserBits-1:0] user;
  } w_payload_t;

  typedef struct packed {
    logic [   IdBits-1:0] id;
    logic [          1:0] resp;
    logic [BUserBits-1:0] user;
  } b_payload_t;

  typedef struct packed {
    logic [AxHeaderWidth-1:0]  ax;
  } header_data_t;

  phy_payload_t phy_in_payload, phy_out_payload, phy_out_cdc_payload;
  logic phy_in_ready, phy_out_ready, phy_out_cdc_ready;
  logic phy_in_valid, phy_out_valid, phy_out_cdc_valid;

  // PHY FSM
  typedef enum logic [2:0] {
    PHYIdle          = 0,
    PHYBusy          = 1,
    PHYTrain         = 2,
    PHYTrainSample   = 3,
    PHYTrainNext     = 4,
    PHYTrainDecide   = 5,
    PHYTrainWaitPeer = 6,
    PHYTrainWaitIdle = 7
  } phy_state_e;

  // Delay FSM
  logic [2:0] delay_line_state_d, delay_line_state_q;
  logic [3:0] delay_line_value_d, delay_line_value_q;
  logic delay_line_enable;
  logic [3:0] delay_set_value;
  logic delay_set_valid, delay_set_ready;

  phy_state_e phy_out_state_d, phy_out_state_q;
  phy_state_e phy_in_state_d, phy_in_state_q;
  logic [LogDataBytes-1:0] phy_out_index_d, phy_out_index_q;
  logic [LogDataBytes-1:0] phy_in_index_d, phy_in_index_q;
  logic [3:0] phy_out_credit_d, phy_out_credit_q;
  logic [3:0] credit_to_send_d, credit_to_send_q;
  logic       inc_phy_out_credit;
  logic       inc_credit_to_send;
  logic       phy_in_keep_idle_q, phy_in_keep_idle_d;
  logic       phy_out_keep_idle_q, phy_out_keep_idle_d;
  logic       phy_out_goto_train;

  logic [$clog2(3)-1:0] mac_in_sel;

  logic [DataBytes:0] recv_fifo_empty;
  logic [DataBytes:0] recv_fifo_push;
  logic [DataBytes:0][7:0] recv_fifo_data_out;
  logic [DataBytes*8+7:0]  recv_fifo_data_flat_out;
  logic recv_fifo_pop;

  phy_payload_t mac_out_data, mac_in_data;
  logic         mac_out_valid, mac_out_ready, mac_in_valid, mac_in_ready;

  phy_payload_t mst_out_data, mst_in_data;
  logic         mst_out_valid, mst_out_ready, mst_in_valid, mst_in_ready, b_in_ready, b_in_valid;

  phy_payload_t slv_out_data, slv_in_data;
  logic         slv_out_valid, slv_out_ready, slv_in_valid, slv_in_ready;

  logic [7:0] data_in_q, data_out_q, data_out_d;
  logic [7:0] ddr_q, ddr_q2, ddr_q3;

  logic [15:0] delay_mask_d, delay_mask_q;
  logic [7:0][15:0] delay_mask_neighbors;
  logic [7:0][3:0] delay_mask_neighbors_first;
  logic [7:0] delay_mask_neighbors_empty;
  logic [7:0] delay_mask_highest_valid;
  logic [3:0] delay_mask_select;
  logic       delay_mask_sane;
  logic [1:0] sane_count_d, sane_count_q;
  logic       ddr_clk_gated;
  logic [1:0] sample_clk;

  cfg_req_t    phy_cfg_req;
  cfg_rsp_t    phy_cfg_rsp;
  logic [31:0] phy_cfg_bitstrb;


  //////////////////////////////////////////
  //   MEDIA ACCESS CONTROL ARBITRATION   //
  //////////////////////////////////////////

  // Protocol arbitration on out port.
  stream_arbiter #(.DATA_T(phy_payload_t), .N_INP(2)) i_stream_arbiter (
    .clk_i       ( clk_i                          ),
    .rst_ni      ( rst_ni                         ),
    .inp_data_i  ( {mst_out_data,  slv_out_data}  ),
    .inp_valid_i ( {mst_out_valid, slv_out_valid} ),
    .inp_ready_o ( {mst_out_ready, slv_out_ready} ),
    .oup_data_o  ( mac_out_data                   ),
    .oup_valid_o ( mac_out_valid                  ),
    .oup_ready_i ( mac_out_ready                  )
  );

  stream_demux #(
    .N_OUP ( 3 )
  ) i_stream_demux (
    .inp_valid_i ( mac_in_valid ),
    .inp_ready_o ( mac_in_ready ),
    .oup_sel_i   ( mac_in_sel   ),
    .oup_valid_o ( {b_in_valid, mst_in_valid, slv_in_valid} ),
    .oup_ready_i ( {b_in_ready, mst_in_ready, slv_in_ready} )
  );

  // select destination
  always_comb begin : proc_in_select
    case(mac_in_data.tag)
      TagR    : mac_in_sel = 2'b01;
      TagB    : mac_in_sel = 2'b10;
      default : mac_in_sel = 2'b00;
    endcase
  end

  assign mst_in_data = mac_in_data;
  assign slv_in_data = mac_in_data;


  /////////////////////////////////////
  //   MEDIA ACCESS CONTROL MASTER   //
  /////////////////////////////////////

  typedef enum logic [1:0] {
    MstIdle, MstRead, MstWrite, MstWriteAck
  } mst_state_e;

  mst_state_e mst_state_d, mst_state_q;

  always_comb begin
    axi_in_rsp_o = '0;

    mst_out_data = '0;
    mst_out_valid = '0;
    mst_in_ready = 1'b0;
    b_in_ready = 1'b0;

    mst_state_d = mst_state_q;

    unique case (mst_state_q)
      MstIdle: begin
        if (axi_in_req_i.aw_valid) begin
          // write transaction
          mst_out_valid = 1'b1;
          mst_out_data.tag = TagAW;
          mst_out_data.data = header_data_t'{
            ax:  axi_in_req_i.aw
          };
          axi_in_rsp_o.aw_ready = mst_out_ready;
          if (axi_in_rsp_o.aw_ready) mst_state_d = MstWrite;
        end else if (axi_in_req_i.ar_valid) begin
          // read transaction
          mst_out_valid = 1'b1;
          mst_out_data.tag = TagAR;
          mst_out_data.data = header_data_t'{
            ax:  axi_in_req_i.ar
          };
          axi_in_rsp_o.ar_ready = mst_out_ready;
          if (axi_in_rsp_o.ar_ready) mst_state_d = MstRead;
        end
      end

      MstWrite: begin
        if (axi_in_req_i.w_valid) begin
          automatic w_payload_t w_payload = '0;
          w_payload.data = axi_in_req_i.w.data;
          w_payload.strb = axi_in_req_i.w.strb;
          w_payload.last = axi_in_req_i.w.last;
          w_payload.user = axi_in_req_i.w.user;
          mst_out_valid = 1'b1;
          mst_out_data.tag = TagW;
          mst_out_data.data = w_payload;
          axi_in_rsp_o.w_ready = mst_out_ready;
          if (axi_in_rsp_o.w_ready && axi_in_req_i.w.last) mst_state_d = MstWriteAck;
        end
      end

      MstWriteAck: begin
        if (b_in_valid) begin
          automatic b_payload_t b_payload = b_payload_t'(mst_in_data.data);
          axi_in_rsp_o.b_valid = 1'b1;
          axi_in_rsp_o.b.id   = b_payload.id;
          axi_in_rsp_o.b.resp = b_payload.resp;
          axi_in_rsp_o.b.user = b_payload.user;
          if (axi_in_req_i.b_ready) begin
            mst_state_d = MstIdle;
            b_in_ready = 1;
          end
        end
      end

      MstRead: begin
        if (mst_in_valid) begin
          automatic r_payload_t r_payload = r_payload_t'(mst_in_data.data);
          axi_in_rsp_o.r_valid = 1'b1;
          axi_in_rsp_o.r.data = r_payload.data;
          axi_in_rsp_o.r.id   = r_payload.id;
          axi_in_rsp_o.r.resp = r_payload.resp;
          axi_in_rsp_o.r.last = r_payload.last;
          axi_in_rsp_o.r.user = r_payload.user;
          mst_in_ready = axi_in_req_i.r_ready;
          if (axi_in_req_i.r_ready) begin
            if (axi_in_rsp_o.r.last) mst_state_d = MstIdle;
          end
        end
      end
      default:;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mst_state_q <= MstIdle;
    end else begin
      mst_state_q <= mst_state_d;
    end
  end


  ////////////////////////////////////
  //   MEDIA ACCESS CONTROL SLAVE   //
  ////////////////////////////////////

  typedef enum logic [1:0] {
    SlvIdle, SlvRead, SlvWrite, SlvWriteAck
  } slv_state_e;

  slv_state_e slv_state_d, slv_state_q;

  always_comb begin
    axi_out_req_o = '0;

    slv_state_d = slv_state_q;

    slv_out_data = '0;
    slv_out_valid = '0;
    slv_in_ready = 1'b0;

    unique case (slv_state_q)
      SlvIdle: begin
        if (slv_in_valid) begin
          if (slv_in_data.tag == TagAR) begin
            automatic header_data_t data;
            data = slv_in_data.data;
            axi_out_req_o.ar = ar_chan_t'(data);
            axi_out_req_o.ar_valid = 1'b1;
            slv_in_ready = axi_out_rsp_i.ar_ready;
            if (axi_out_rsp_i.ar_ready && axi_out_req_o.ar_valid) slv_state_d = SlvRead;
          end else if (slv_in_data.tag == TagAW) begin
            automatic header_data_t data;
            data = slv_in_data.data;
            axi_out_req_o.aw = aw_chan_t'(data);
            axi_out_req_o.aw_valid = 1'b1;
            slv_in_ready = axi_out_rsp_i.aw_ready;
            if (axi_out_rsp_i.aw_ready && axi_out_req_o.aw_valid) slv_state_d = SlvWrite;
          end
        end
      end

      SlvRead: begin
        if (axi_out_rsp_i.r_valid) begin
          automatic r_payload_t r_payload;
          r_payload.data = axi_out_rsp_i.r.data;
          r_payload.id   = axi_out_rsp_i.r.id;
          r_payload.resp = axi_out_rsp_i.r.resp;
          r_payload.last = axi_out_rsp_i.r.last;
          r_payload.user = axi_out_rsp_i.r.user;
          slv_out_data.tag = TagR;
          slv_out_data.data = r_payload;
          axi_out_req_o.r_ready = slv_out_ready;
          slv_out_valid = 1'b1;
          if (axi_out_rsp_i.r.last & axi_out_req_o.r_ready) slv_state_d = SlvIdle;
        end
      end

      SlvWrite: begin
        if (slv_in_valid) begin
          automatic w_payload_t w_payload;
          w_payload = w_payload_t'(slv_in_data.data);
          axi_out_req_o.w.data = w_payload.data;
          axi_out_req_o.w.strb = w_payload.strb;
          axi_out_req_o.w.last = w_payload.last;
          axi_out_req_o.w.user = w_payload.user;
          axi_out_req_o.w_valid = 1'b1;
          slv_in_ready = axi_out_rsp_i.w_ready;
          if (axi_out_rsp_i.w_ready) begin
            if (axi_out_req_o.w.last) slv_state_d = SlvWriteAck;
          end
        end
      end

      SlvWriteAck: begin
        if (axi_out_rsp_i.b_valid) begin
          automatic b_payload_t b_payload;
          slv_out_valid = 1'b1;
          slv_out_data.tag = TagB;
          b_payload.id   = axi_out_rsp_i.b.id;
          b_payload.resp = axi_out_rsp_i.b.resp;
          b_payload.user = axi_out_rsp_i.b.user;
          slv_out_data.data = b_payload;
          if (slv_out_ready) begin
            axi_out_req_o.b_ready = 1;
            slv_state_d = SlvIdle;
          end
        end
      end

      default:;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      slv_state_q <= SlvIdle;
    end else begin
      slv_state_q <= slv_state_d;
    end
  end


  ////////////////////////////////
  //   CLOCK DOMAIN CROSSINGS   //
  ////////////////////////////////

  rstgen i_rstgen (.clk_i(ddr_clk_i), .rst_ni, .test_mode_i(testmode_i), .rst_no(ddr_rst_n), .init_no());

  cdc_2phase #(
    .T ( phy_payload_t )
  ) i_cdc_out (
    .src_clk_i   ( clk_i               ),
    .src_rst_ni  ( rst_ni              ),
    .src_data_i  ( mac_out_data        ),
    .src_valid_i ( mac_out_valid       ),
    .src_ready_o ( mac_out_ready       ),

    .dst_clk_i   ( ddr_clk_i           ),
    .dst_rst_ni  ( ddr_rst_n           ),
    .dst_data_o  ( phy_out_cdc_payload ),
    .dst_valid_o ( phy_out_cdc_valid   ),
    .dst_ready_i ( phy_out_cdc_ready   )
  );

  stream_register #(
    .T ( phy_payload_t )
  ) i_stream_reg_out (
      .clk_i   ( ddr_clk_i           ),
      .rst_ni  ( ddr_rst_n           ),
      .testmode_i,
      .clr_i   ( 1'b0                ),

      .data_i  ( phy_out_cdc_payload ),
      .valid_i ( phy_out_cdc_valid   ),
      .ready_o ( phy_out_cdc_ready   ),

      .data_o  ( phy_out_payload     ),
      .valid_o ( phy_out_valid       ),
      .ready_i ( phy_out_ready       )
  );

  cdc_2phase #(
    .T ( phy_payload_t )
  ) i_cdc_in (
    .src_clk_i   ( ddr_clk_i      ),
    .src_rst_ni  ( ddr_rst_n      ),
    .src_data_i  ( phy_in_payload ),
    .src_valid_i ( phy_in_valid   ),
    .src_ready_o ( phy_in_ready   ),

    .dst_clk_i   ( clk_i          ),
    .dst_rst_ni  ( rst_ni         ),
    .dst_data_o  ( mac_in_data    ),
    .dst_valid_o ( mac_in_valid   ),
    .dst_ready_i ( mac_in_ready   )
  );

  reg_cdc #(
    .req_t(cfg_req_t),
    .rsp_t(cfg_rsp_t)
  ) i_cdc_cfg (
    .src_clk_i   ( clk_i         ),
    .src_rst_ni  ( rst_ni        ),
    .src_req_i   ( cfg_req_i     ),
    .src_rsp_o   ( cfg_rsp_o     ),

    .dst_clk_i   ( ddr_clk_i     ),
    .dst_rst_ni  ( ddr_rst_n     ),
    .dst_req_o   ( phy_cfg_req   ),
    .dst_rsp_i   ( phy_cfg_rsp   )
  );

  always_comb for (int i = 0; i < 32; i++) phy_cfg_bitstrb[i] = phy_cfg_req.wstrb[i/8];


  /////////////////
  //   PHY OUT   //
  /////////////////

  always_comb begin
    phy_out_ready = 1'b0;
    phy_out_state_d = phy_out_state_q;
    phy_out_index_d = phy_out_index_q;
    phy_out_credit_d = phy_out_credit_q;
    credit_to_send_d = credit_to_send_q;

    data_out_d = '0;

    unique case (phy_out_state_q)
      PHYIdle: begin
        if (phy_out_valid && phy_out_credit_q != '0) begin
          phy_out_state_d = PHYBusy;
          phy_out_index_d = '0;
          data_out_d = phy_out_payload.tag;
          phy_out_credit_d--;
        end
        if (credit_to_send_q != 0) begin
          data_out_d |= TagMaskCredit;
          credit_to_send_d--;
        end
      end

      PHYBusy: begin
        phy_out_index_d = phy_out_index_q + 1;
        data_out_d = phy_out_payload.data >> (phy_out_index_q * 8);
        if (phy_out_index_q == DataBytes-1) begin
          phy_out_state_d = PHYIdle;
          phy_out_ready = 1'b1;
        end
      end

      PHYTrain: begin
        data_out_d = TrainingPattern;
        unique case (phy_in_state_q)
          PHYTrainWaitPeer: begin
            data_out_d[0] = 0;
          end
          PHYTrainWaitIdle: begin
            data_out_d = '0;
          end
          PHYIdle: begin
            data_out_d = '0;
            phy_out_state_d = PHYIdle;
          end
          default:;
        endcase
      end

      default:;
    endcase

    if (inc_phy_out_credit) phy_out_credit_d++;
    if (inc_credit_to_send) credit_to_send_d++;

    // Allow for the cfg interface to forcefully transition the FSM into other
    // states.
    if (phy_cfg_req.valid && phy_cfg_req_addr == serial_link_pkg::SerialCfgStatus && phy_cfg_req.write) begin
        if (phy_cfg_req.wdata[17] & phy_cfg_bitstrb[17]) phy_out_state_d = PHYTrain;
        if (phy_cfg_req.wdata[19] & phy_cfg_bitstrb[19]) phy_out_state_d = PHYIdle;
    end

    // Enter training mode if the training pattern was observed on the receiving
    // side.
    if (phy_out_goto_train) phy_out_state_d = PHYTrain;
  end


  ////////////////
  //   PHY IN   //
  ////////////////

  always_comb begin
    phy_in_state_d = phy_in_state_q;
    phy_in_index_d = phy_in_index_q;
    inc_phy_out_credit = 1'b0;
    delay_mask_d = delay_mask_q;
    recv_fifo_push = '0;
    delay_set_valid = 0;
    delay_set_value = 0;
    sane_count_d = sane_count_q;
    phy_cfg_rsp = '0;
    phy_cfg_rsp.ready = 1;
    phy_in_keep_idle_d = phy_in_keep_idle_q;
    phy_out_keep_idle_d = phy_out_keep_idle_q;
    phy_out_goto_train = 0;

    unique case (phy_in_state_q)
      PHYIdle: begin
        if (data_in_q[7:1] == TrainingPattern[7:1]) begin
          phy_in_state_d = PHYTrain;
          phy_out_goto_train = 1;
        end else begin
          // Otherwise give the tag the regular treatment.
          if ((data_in_q & ~TagMask) != 0) begin
            phy_in_state_d = PHYBusy;
            phy_in_index_d = '0;
            recv_fifo_push[DataBytes] = 1'b1;
          end
          // Check whether the credit flag was set.
          if (data_in_q & TagMaskCredit) inc_phy_out_credit = 1'b1;
        end
      end

      PHYBusy: begin
        phy_in_index_d++;
        recv_fifo_push = 1 << phy_in_index_q;
        if (phy_in_index_q == DataBytes-1) phy_in_state_d = PHYIdle;
      end

      PHYTrain: begin
        delay_mask_d = '1;
        phy_in_index_d = 0;
        delay_set_value = 0;
        delay_set_valid = 1;
        if (delay_set_ready) phy_in_state_d = PHYTrainSample;
      end

      PHYTrainSample: begin
        // `| 1` to ignore the train-done bit indication from the peer
        delay_mask_d[delay_line_value_q] &= (data_in_q | 1 == TrainingPattern);
        if (phy_in_index_q != 3) begin
          phy_in_index_d++;
        end else begin
          phy_in_index_d = '0;
          if (delay_line_value_q != 15) begin
            // More delays to be tested.
            phy_in_state_d = PHYTrainNext;
          end else begin
            // Last delay has just been tested.
            phy_in_state_d = PHYTrainDecide;
          end
        end
      end

      PHYTrainNext: begin
        delay_set_value = delay_line_value_q + 1;
        delay_set_valid = 1;
        if (delay_set_ready) phy_in_state_d = PHYTrainSample;
      end

      PHYTrainDecide: begin
        if (delay_mask_sane) begin
          if (sane_count_q != 2) begin
            phy_in_state_d = PHYTrain;
            sane_count_d++;
          end else begin
            // Pick delay and signal to the peer that we are done with training.
            delay_set_value = delay_mask_select;
            delay_set_valid = 1;
            if (delay_set_ready) phy_in_state_d = PHYTrainWaitPeer;
          end
        end else begin
          // If the delay mask did not look sane, start the training again.
          phy_in_state_d = PHYTrain;
          sane_count_d = '0;
        end
      end

      PHYTrainWaitPeer: begin
        // Wait for the other side to finish training.
        if (data_in_q[0] == 0) phy_in_state_d = PHYTrainWaitIdle;
      end

      PHYTrainWaitIdle: begin
        // Wait for the other side to put the bus into idle mode.
        if (data_in_q == 0) phy_in_state_d = PHYIdle;
      end

      default:;
    endcase

    if (phy_cfg_req.valid) begin
      unique case (phy_cfg_req_addr)
        serial_link_pkg::SerialCfgStatus: begin
          phy_cfg_rsp.rdata[0] = (phy_in_state_q  == PHYIdle);
          phy_cfg_rsp.rdata[1] = (phy_out_state_q == PHYIdle);
          phy_cfg_rsp.rdata[2] = (phy_in_state_q  == PHYBusy);
          phy_cfg_rsp.rdata[3] = (phy_out_state_q == PHYBusy);
          phy_cfg_rsp.rdata[4] = (phy_in_state_q  != PHYIdle && phy_in_state_q  != PHYBusy);
          phy_cfg_rsp.rdata[5] = (phy_out_state_q != PHYIdle && phy_out_state_q != PHYBusy);
          phy_cfg_rsp.rdata[11:8] = phy_in_state_q;
          phy_cfg_rsp.rdata[15:12] = phy_out_state_q;
          phy_cfg_rsp.rdata[20] = phy_in_keep_idle_q;
          phy_cfg_rsp.rdata[21] = phy_out_keep_idle_q;
          if (phy_cfg_req.write) begin
            if (phy_cfg_req.wdata[16] & phy_cfg_bitstrb[16]) phy_in_state_d = PHYTrain;
            if (phy_cfg_req.wdata[18] & phy_cfg_bitstrb[18]) phy_in_state_d = PHYIdle;
            if (phy_cfg_bitstrb[20]) phy_in_keep_idle_d = phy_cfg_req.wdata[20];
            if (phy_cfg_bitstrb[21]) phy_out_keep_idle_d = phy_cfg_req.wdata[21];
          end
          phy_cfg_rsp.ready = 1;
        end
        serial_link_pkg::SerialCfgTrainingMask: begin
          phy_cfg_rsp.rdata = delay_mask_q;
          phy_cfg_rsp.ready = 1;
        end
        serial_link_pkg::SerialCfgDelay: begin
          phy_cfg_rsp.rdata = delay_line_value_q;
          if (phy_cfg_req.write) begin
            delay_set_value
              = (delay_line_value_q & ~phy_cfg_bitstrb)
              | (phy_cfg_req.wdata  &  phy_cfg_bitstrb);
            delay_set_valid = 1;
            phy_cfg_rsp.ready = delay_set_ready;
          end else begin
            phy_cfg_rsp.ready = 1;
          end
        end
        default: begin
          phy_cfg_rsp.error = 1;
          phy_cfg_rsp.ready = 1;
        end
      endcase
    end
  end

  // Compute a mask over consecutive one-bits in the delay mask.
  always_comb begin
    delay_mask_neighbors[0] = delay_mask_q & (delay_mask_q << 1);
    delay_mask_neighbors[1] = delay_mask_neighbors[0] & (delay_mask_neighbors[0] >> 1);
    for (int i = 1; i < 4; i++) begin
        delay_mask_neighbors[i*2+0] = delay_mask_neighbors[i*2-1] & (delay_mask_neighbors[i*2-1] << 1);
        delay_mask_neighbors[i*2+1] = delay_mask_neighbors[i*2+0] & (delay_mask_neighbors[i*2+0] >> 1);
    end
    delay_mask_sane = (delay_mask_neighbors[0] != 0);
  end

  // For each consecutive bit mask, find the first non-zero entry and check
  // whether there even were any non-zero entries.
  for (genvar i = 0; i < 8; i++) begin
    lzc #(
      .WIDTH ( 16 ),
      .MODE  ( 0  )
    ) i_lzc (
      .in_i    ( delay_mask_neighbors[i]       ),
      .cnt_o   ( delay_mask_neighbors_first[i] ),
      .empty_o ( delay_mask_neighbors_empty[i] )
    );
  end

  // For all consecutive bits, find the largest non-zero entry.
  always_comb begin
    delay_mask_highest_valid = ~delay_mask_neighbors_empty ^ (~delay_mask_neighbors_empty >> 1);
    delay_mask_select = 0;
    for (int i = 0; i < 8; i++)
      delay_mask_select |= delay_mask_highest_valid[i] ? delay_mask_neighbors_first[i] : '0;
  end

  // Instantiate receive FIFOs for each of the 8 bit subwords that we transfer
  // per flits.
  for (genvar i = 0; i < DataBytes + 1; i++) begin : gen_recv_fifo
    logic [7:0] recv_fifo_data_in;

    fifo_v3 #(
      .FALL_THROUGH ( 1'b0 ),
      .DATA_WIDTH   ( 8    ),
      .DEPTH        ( 4    )
    ) i_fifo_v3 (
      .clk_i      ( ddr_clk_i                    ),
      .rst_ni     ( ddr_rst_n                    ),
      .flush_i    ( 1'b0                         ),
      .testmode_i ( testmode_i                   ),
      .full_o     (                              ),
      .empty_o    ( recv_fifo_empty[i]           ),
      .usage_o    (                              ),
      .data_i     ( recv_fifo_data_in            ),
      .push_i     ( recv_fifo_push[i]            ),
      .data_o     ( recv_fifo_data_out[i]        ),
      .pop_i      ( recv_fifo_pop                )
    );
    // clear upper bit which contains control flow
    assign recv_fifo_data_in = (i == DataBytes) ? data_in_q & ~TagMask : data_in_q;
  end

  assign phy_in_valid = &(~recv_fifo_empty);
  assign recv_fifo_pop = phy_in_valid & phy_in_ready;
  assign inc_credit_to_send = recv_fifo_pop;
  assign recv_fifo_data_flat_out = recv_fifo_data_out;

  // extract tag and unaligned data
  assign phy_in_payload.data = recv_fifo_data_flat_out[PhyDataBits-1:0];
  assign phy_in_payload.tag  = tag_e'(recv_fifo_data_flat_out[DataBytes*8+7:DataBytes*8]);

  always_ff @(posedge ddr_clk_i or negedge ddr_rst_n) begin
    if (!ddr_rst_n) begin
      phy_out_index_q <= '0;
      phy_in_index_q <= '0;
      delay_mask_q <= '0;
      phy_out_state_q <= PHYTrain;
      phy_in_state_q <= PHYTrain;
      phy_out_credit_q <= 3;
      credit_to_send_q <= 0;
      delay_line_state_q <= '0;
      delay_line_value_q <= '0;
      sane_count_q <= '0;
      phy_in_keep_idle_q <= '0;
      phy_out_keep_idle_q <= '0;
    end else begin
      phy_out_index_q <= phy_out_index_d;
      phy_in_index_q <= phy_in_index_d;
      delay_mask_q <= delay_mask_d;
      phy_out_state_q <= phy_out_state_d;
      phy_in_state_q <= phy_in_state_d;
      phy_out_credit_q <= phy_out_credit_d;
      credit_to_send_q <= credit_to_send_d;
      delay_line_state_q <= delay_line_state_d;
      delay_line_value_q <= delay_line_value_d;
      sane_count_q <= sane_count_d;
      phy_in_keep_idle_q <= phy_in_keep_idle_d;
      phy_out_keep_idle_q <= phy_out_keep_idle_d;
    end
  end


  ////////////////
  //   DDR IN   //
  ////////////////

  // functional clock gate
  tc_clk_gating i_tc_clk_gating (
    .clk_i     ( ddr_clk_i         ),
    .en_i      ( delay_line_enable ),
    .test_en_i ( testmode_i        ),
    .clk_o     ( ddr_clk_gated     )
  );

  // Sampling clocks.
  serial_link_delay i_delay (
    .clk_i    ( ddr_clk_gated      ),
    .enable_i ( 1'b1               ),
    .delay_i  ( delay_line_value_q ),
    .clk_o    ( sample_clk         )
  );

  // Schedule for the delay line control FSM:
  //   0: idle, if valid goto 1
  //   1: disable ckg
  //   2: delay_line_value_d = delay_set_value
  //   3: enable ckg
  //   4: nop
  //   5: nop
  //   6: nop
  //   7: nop, ready = 1, goto idle
  always_comb begin
    delay_line_state_d = delay_line_state_q;
    delay_line_value_d = delay_line_value_q;
    delay_set_ready = 0;
    delay_line_enable = 1;
    if (delay_set_valid) delay_line_state_d++;
    unique case (delay_line_state_q)
      1: begin
        delay_line_enable = 0;
        delay_line_value_d = delay_set_value;
      end
      2: delay_line_enable = 0;
      7: delay_set_ready = 1;
      default:;
    endcase
  end

  // DDR In
  always_ff @(posedge sample_clk[0], negedge ddr_rst_n) ddr_q[3:0] <= !ddr_rst_n ? '0 : ddr_i;
  always_ff @(negedge sample_clk[0], negedge ddr_rst_n) ddr_q[7:4] <= !ddr_rst_n ? '0 : ddr_i;
  always_ff @(posedge sample_clk[0], negedge ddr_rst_n) ddr_q2 <= !ddr_rst_n ? '0 : ddr_q;
  always_ff @(posedge sample_clk[1], negedge ddr_rst_n) ddr_q3 <= !ddr_rst_n ? '0 : ddr_q2;
  always_ff @(posedge ddr_clk_i, negedge ddr_rst_n) data_in_q <= !ddr_rst_n ? '0 : ddr_q3;


  /////////////////
  //   DDR OUT   //
  /////////////////

  // DDR Out
  always_ff @(posedge ddr_clk_i, negedge ddr_rst_n) data_out_q <= !ddr_rst_n ? '0 : data_out_d;
  assign ddr_o = ddr_clk_i ? data_out_q[3:0] : data_out_q[7:4];


endmodule : serial_link
