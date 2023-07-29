module tc_clk_and2 (
  input  logic clk0_i,
  input  logic clk1_i,
  output logic clk_o
);

  CLKAND2_X2_A8TR i_CLKAND2_X2_A8TR (
    .A ( clk0_i ),
    .B ( clk1_i ),
    .Y ( clk_o  )
  );

endmodule


module tc_clk_buffer (
  input  logic clk_i,
  output logic clk_o
);

  CLKBUF_X1_A8TR i_CLKBUF_X1_A8TR (
    .A ( clk_i ),
    .Y ( clk_o )
  );

endmodule


module tc_clk_gating (
   input  logic clk_i,
   input  logic en_i,
   input  logic test_en_i,
   output logic clk_o
);

  TLATNTSCA_X2_A8TR i_TLATNTSCA_X2_A8TR (
    .CK   ( clk_i     ),
    .E    ( en_i      ),
    .SE   ( test_en_i ),
    .ECK  ( clk_o     )
  );

endmodule


module tc_clk_inverter (
  input  logic clk_i,
  output logic clk_o
);

  CLKINV_X1_A8TR i_CLKINV_X1_A8TR (
    .A ( clk_i ),
    .Y ( clk_o )
  );

endmodule


module tc_clk_mux2 (
  input  logic clk0_i,
  input  logic clk1_i,
  input  logic clk_sel_i,
  output logic clk_o
);

  CLKMX2_X2_A8TR i_CLKMX2_X2_A8TR (
    .A  ( clk0_i    ),
    .B  ( clk1_i    ),
    .S0 ( clk_sel_i ),
    .Y  ( clk_o     )
  );

endmodule


module tc_clk_xor2 (
  input  logic clk0_i,
  input  logic clk1_i,
  output logic clk_o
);

  CLKXOR2_X2_A8TR i_CLKXOR2_X2_A8TR (
    .A ( clk0_i ),
    .B ( clk1_i ),
    .Y ( clk_o  )
  );

endmodule
