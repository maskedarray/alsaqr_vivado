// Copyright 2020 ETH Zurich
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
// Florian Zaruba <zarubaf@iis.ee.ethz.ch>

module serial_link_delay (
  input  logic       clk_i,
  input  logic       enable_i,
  input  logic [3:0] delay_i,
  output logic [1:0] clk_o
);

  `ifndef TARGET_ASIC
    generic_delay_D4_O2_3P750_1P875_CG1 i_generic_delay_D4_O2_3P750_1P875_CG1 (
      .clk_i   (clk_i   ),
      .enable_i(enable_i),
      .delay_i (delay_i ),
      .clk_o   (clk_o   )
    );
  `else
   
   logic               in_i;
   logic               s_clk;
   
    tc_clk_gating serial_link_cg (
          .clk_i     (clk_i),
          .en_i      (enable_i),
          .test_en_i (1'b0),
          .clk_o     (in_i)
    );
   
    generic_delay_D4_O1_1P875_CG0 i_delay0(
        .clk_i      ( in_i      ),
        .delay_i    ( delay_i   ),
        .clk_o      ( s_clk     )
    );

    assign clk_o[1] = s_clk;
   
    generic_delay_D4_O1_1P875_CG0 i_delay1(
        .clk_i      ( s_clk     ),
        .delay_i    ( delay_i   ),
        .clk_o      ( clk_o[0]  )
    );

  `endif 
   
endmodule
