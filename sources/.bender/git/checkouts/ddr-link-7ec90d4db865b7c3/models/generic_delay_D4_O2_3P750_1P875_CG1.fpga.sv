// Copyright (c) 2021 ETH Zurich.
// Thomas Benz <tbenz@iis.ee.ethz.ch>
// Paul Scheffler <paulsc@iis.ee.ethz.ch>

// Based on work of:
// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
// Florian Zaruba <zarubaf@iis.ee.ethz.ch>

// Automatically generated
`timescale 1ps/1ps

(* no_ungroup *)
(* no_boundary_optimization *)
module generic_delay_D4_O2_3P750_1P875_CG1 (
  input  logic       clk_i,
  input  logic       enable_i,
  input  logic [4-1:0] delay_i,
  output logic [2-1:0] clk_o
);

  logic enable_latched;
  logic clk;
  
  IBUF #
    (
     .IBUF_LOW_PWR ("FALSE")
     ) u_ibufg_0
      (
       .I  (clk_i),
       .O  (clk_o[1])
       );  

  IBUF #
    (
     .IBUF_LOW_PWR ("FALSE")
     ) u_ibufg_1
      (
       .I  (clk_o[1]),
       .O  (clk_o[0])
       );  

endmodule

