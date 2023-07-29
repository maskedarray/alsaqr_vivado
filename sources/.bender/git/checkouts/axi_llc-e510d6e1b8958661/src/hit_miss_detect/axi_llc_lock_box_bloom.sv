// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>
// Date:   21.08.2019

/// This module implements the locking with a bloom filter
/// Seeding Parameters are at the default of the `cb_filter` module for
/// number of hashes and respective seeds
/// unlock happens from anoter unit and is registered in a FIFO
/// the `rr_arb_tree` then merges the unlock requests onto the bloom decrement
module axi_llc_lock_box_bloom #(
  /// Static LLC parameter configuration struct.
  parameter axi_llc_pkg::llc_cfg_t Cfg = axi_llc_pkg::llc_cfg_t'{default: '0},
  /// Struct for bundling the signals defining the locking.
  /// Required fields:
  /// typedef struct packed {
  ///    logic [Cfg.IndexLength-1:0]      index;        // index of lock (cacheline)
  ///    logic [Cfg.SetAssociativity-1:0] way_ind;      // way which is locked
  /// } lock_t;
  parameter type lock_t = logic
) (
  /// Clock, positive edge triggered
  input  logic  clk_i,
  /// Asynchronous reset, active low
  input  logic  rst_ni,
  /// Testmode enable, active high
  input  logic  test_i,
  /// Lock request payload. Performs the lookup and the lock of the line.
  input  lock_t lock_i,
  /// Lock the line defined by `lock_i`, ie increment the bloom filter.
  input  logic  lock_req_i,
  /// This signal indicates that the lookup performed from `lock_i` Found a locked cache line.
  /// This means that another descriptor is currently using the cacheline.
  /// Wait with asserting `lock_req_i` untill this is `'0`;
  output logic  locked_o,
  /// Unlock payload from the write unit.
  input  lock_t w_unlock_i,
  /// Unlock request from the write unit is valid.
  input  logic  w_unlock_req_i,
  /// We are ready to accept an unlock from the write unit.
  output logic  w_unlock_gnt_o,
  /// Unlock payload from the read unit.
  input  lock_t r_unlock_i,
  /// Unlock request from the read unit is valid.
  input  logic  r_unlock_req_i,
  /// We are ready to accept an unlock from the read unit.
  output logic  r_unlock_gnt_o
);
  localparam int unsigned DataWidth = Cfg.SetAssociativity + Cfg.IndexLength;

  // signals to the bloom filter
  logic [DataWidth-1:0] look_data,  incr_data,  decr_data;
  logic                 look_valid,             decr_valid;
  logic                 full,       error;
  // decrement FIFOs signals
  logic [DataWidth-1:0] w_decr_inp, r_decr_inp;
  logic                 w_full,     r_full;
  logic                 w_push,     r_push;
  logic [DataWidth-1:0] w_decr,     r_decr;
  logic                 w_empty,    r_empty;
  logic                 w_pop,      r_pop;
  logic                 w_gnt,      r_gnt;      // grant signals from arbitration tree

  // bloom input connections
  assign look_data  = {lock_i.index,     lock_i.way_ind};
  assign incr_data  = {lock_i.index,     lock_i.way_ind};
  assign w_decr_inp = {w_unlock_i.index, w_unlock_i.way_ind};
  assign r_decr_inp = {r_unlock_i.index, r_unlock_i.way_ind};

  assign w_unlock_gnt_o = ~w_full;
  assign w_push         = ~w_full & w_unlock_req_i;
  fifo_v3 #(
    .FALL_THROUGH ( 1'b1      ),
    .DATA_WIDTH   ( DataWidth ),
    .DEPTH        ( 32'd2     ) // fixed, because not often happening
  ) i_w_unlock_fifo (
    .clk_i,
    .rst_ni,
    .flush_i    ( 1'b0         ),
    .testmode_i ( test_i       ),
    .full_o     ( w_full       ),
    .empty_o    ( w_empty      ),
    .usage_o    ( /*not used*/ ),
    .data_i     ( w_decr_inp   ),
    .push_i     ( w_push       ),
    .data_o     ( w_decr       ),
    .pop_i      ( w_pop        )
  );
  assign w_pop = ~w_empty & w_gnt;

  assign r_unlock_gnt_o = ~r_full;
  assign r_push         = ~r_full & r_unlock_req_i;
  fifo_v3 #(
    .FALL_THROUGH ( 1'b1      ),
    .DATA_WIDTH   ( DataWidth ),
    .DEPTH        ( 32'd2     ) // fixed, because not often happening
  ) i_r_unlock_fifo (
    .clk_i,
    .rst_ni,
    .flush_i    ( 1'b0         ),
    .testmode_i ( test_i       ),
    .full_o     ( r_full       ),
    .empty_o    ( r_empty      ),
    .usage_o    ( /*not used*/ ),
    .data_i     ( r_decr_inp   ),
    .push_i     ( r_push       ),
    .data_o     ( r_decr       ),
    .pop_i      ( r_pop        )
  );
  assign r_pop = ~r_empty & r_gnt;

  rr_arb_tree #(
    .NumIn     ( 32'd2     ),
    .DataWidth ( DataWidth ),
    .AxiVldRdy ( 1'b1      ),
    .LockIn    ( 1'b1      )
  ) i_unlock_tree (
    .clk_i,
    .rst_ni,
    .flush_i ( 1'b0         ),
    .rr_i    ( '0           ),
    .req_i   ({~w_empty, ~r_empty}),
    .gnt_o   ({w_gnt,    r_gnt   }),
    .data_i  ({w_decr,   r_decr  }),
    .gnt_i   ( 1'b1               ), // the bloom filter can take a decrement every cycle
    .req_o   ( decr_valid         ),
    .data_o  ( decr_data          ),
    .idx_o   ( /*not used*/       )
  );

  // Change the parameters of the bloom filter in `llc_pkg` if you want to optimize the filter.
  // Safety for if for some reason the data width is not bigger than the hash width in `llc_pkg`.
  localparam int unsigned HashWidth = (DataWidth > axi_llc_pkg::BloomHashWidth) ?
                                      axi_llc_pkg::BloomHashWidth : (DataWidth - 1);
  cb_filter #(
    .KHashes     ( axi_llc_pkg::BloomKHashes     ),
    .HashWidth   ( HashWidth                     ),
    .HashRounds  ( axi_llc_pkg::BloomHashRounds  ),
    .InpWidth    ( DataWidth                     ),
    .BucketWidth ( axi_llc_pkg::BloomBucketWidth ),
    .Seeds       ( axi_llc_pkg::BloomSeeds       )
  ) i_cb_filter(
    .clk_i,   // Clock
    .rst_ni,  // Active low reset
    // data lookup
    .look_data_i    ( look_data  ),
    .look_valid_o   ( look_valid ),
    // data increment
    .incr_data_i    ( incr_data  ),
    .incr_valid_i   ( lock_req_i ),
    // data decrement
    .decr_data_i    ( decr_data  ),
    .decr_valid_i   ( decr_valid ),
    // status signals
    .filter_clear_i  ( 1'b0  ),
    .filter_usage_o  (       ),
    .filter_full_o   ( full  ),
    .filter_empty_o  (       ),
    .filter_error_o  ( error )
  );
  // output assignment
  assign locked_o = look_valid | full;

  // pragma translate_off
  `ifndef VERILATOR
  check_blomm_error: assert property (@(posedge clk_i) disable iff (~rst_ni) (!error)) else
      $fatal(1, "Bloom Filter is in Error state!");
  `endif
  // pragma translate_on
endmodule
