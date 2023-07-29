// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Wolfgang Roenninger <wroennin@iis.ee..ethz.ch>
// Date:   12.06.2019

/// This module counts if there are any descriptors of a given transaction ID
/// in the miss pipeline, and combinationally counts up of down the respective ID
/// of the cnt_t struct matches. There is a counter for all id's and one for writes
/// as all writes have to be transferred in order.
module axi_llc_miss_counters #(
  /// Static LLC parameter configuration.
  parameter axi_llc_pkg::llc_cfg_t Cfg = axi_llc_pkg::llc_cfg_t'{default: '0},
  /// Counter request type.
  ///
  /// typedef struct packed {
  ///   axi_slv_id_t id;        // AXI ID of the descriptor operating the counter
  ///   logic        rw;        // 0:read, 1:write
  ///   logic        valid;     // valid, equals enable of the counter
  /// } cnt_t;
  parameter type cnt_t  = logic
) (
  /// Clock, positive edge triggered.
  input  logic clk_i,
  /// Asynchronous reset, active low.
  input  logic rst_ni,
  /// The descriptor gets transferred into the miss pipeline.
  input  cnt_t cnt_up_i,
  /// The descriptor gets transferred out of the miss pipeline.
  input  cnt_t cnt_down_i,
  /// Tells that a descriptor should go to the miss pipeline.
  output logic to_miss_o,
  /// One of the counters is overflowing, stall descriptor!
  output logic stall_o
);
  localparam int unsigned NoCounters = 2**axi_llc_pkg::UseIdBits;
  // stall signal for each counter (no minus 1, because the write counter is extra )
  logic [NoCounters:0]   stall;
  logic [NoCounters-1:0] en;
  logic                  en_w;
  logic [NoCounters-1:0] down;
  logic                  down_w;
  // outputs of the counters
  logic [NoCounters-1:0][axi_llc_pkg::MissCntWidth-1:0] q_miss;
  logic [axi_llc_pkg::MissCntMaxWWidth-1:0]             q_write;

  // the or reduction of the overflow gives us the stall signal
  assign stall_o = |stall;

  always_comb begin : proc_control
    to_miss_o = 1'b0;
    for (int unsigned i = 0; i < NoCounters; i++) begin
      // default assignments
      en[i]     = 1'b0;
      down[i]   = 1'b0;
      // we should count up
      if ((cnt_up_i.id[0+:axi_llc_pkg::UseIdBits] == i) && cnt_up_i.valid) begin
        en[i]   = 1'b1;
      end

      // we should count down, or do nothing, if we are already counting up
      if ((cnt_down_i.id[0+:axi_llc_pkg::UseIdBits] == i) && cnt_down_i.valid) begin
        if (en[i] == 1'b1) begin
          en[i]   = 1'b0;
        end else begin
          en[i]   = 1'b1;
          down[i] = 1'b1;
        end
      end
      // do we have to send the descriptor to the miss pipeline?
      if (cnt_up_i.id[0+:axi_llc_pkg::UseIdBits] == i) begin
        // first check the counter mapped to the id
        to_miss_o = |q_miss[i];
        // if it is a write also check if there are other writes in the miss pipeline
        if (cnt_up_i.rw) begin
          to_miss_o = to_miss_o || (|q_write);
        end
      end
    end
  end
  // assignment of the inputs to the write counter
  // this assignment was calculated using a karnot diagramm
  assign en_w = ( ~cnt_up_i.rw     & cnt_down_i.rw  &   cnt_down_i.valid ) |
                ( ~cnt_up_i.valid  & cnt_down_i.rw  &   cnt_down_i.valid ) |
                (  cnt_up_i.rw     & cnt_up_i.valid &  ~cnt_down_i.rw    ) |
                (  cnt_up_i.rw     & cnt_up_i.valid &  ~cnt_down_i.valid ) ;

  assign down_w = ~cnt_up_i.rw | ~cnt_up_i.valid;

  for (genvar j = 0; unsigned'(j) < NoCounters; j++) begin : gen_cmiss_counters
    counter #(
      .WIDTH      ( axi_llc_pkg::MissCntWidth )
    ) i_miss_cnt (
      .clk_i      (     clk_i ),
      .rst_ni     (    rst_ni ),
      .clear_i    (        '0 ),
      .en_i       (     en[j] ),
      .load_i     (        '0 ),
      .down_i     (   down[j] ),
      .d_i        (        '0 ),
      .q_o        ( q_miss[j] ),
      .overflow_o (  stall[j] )
    );
  end

  counter #(
    .WIDTH      ( axi_llc_pkg::MissCntMaxWWidth )
  ) i_miss_w_cnt (
    .clk_i      ( clk_i             ),
    .rst_ni     ( rst_ni            ),
    .clear_i    ( '0                ),
    .en_i       ( en_w              ),
    .load_i     ( '0                ),
    .down_i     ( down_w            ),
    .d_i        ( '0                ),
    .q_o        ( q_write           ),
    .overflow_o ( stall[NoCounters] )
  );
endmodule
