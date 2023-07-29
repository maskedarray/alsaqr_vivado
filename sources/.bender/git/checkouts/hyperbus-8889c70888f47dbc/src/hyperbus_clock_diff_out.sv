// Copyright (C) 2017 ETH Zurich, University of Bologna
// All rights reserved.
//
// This code is under development and not yet released to the public.
// Until it is released, the code is under the copyright of ETH Zurich and
// the University of Bologna, and may contain confidential and/or unpublished
// work. Any reuse/redistribution is strictly forbidden without written
// permission from ETH Zurich.

// Description: A Hyperbus differential clock output generator.

// Author: Armin Berger <bergerar@ethz.ch>
// Author: Stephan Keck <kecks@ethz.ch>

module hyperbus_clock_diff_out
(
    input  logic in_i,
    input  logic en_i, //high enable
    output logic out_o,
    output logic out_no
);

   `ifdef FPGA_EMUL

       logic en_sync;
    
       always_latch
       begin
         if (in_i == 1'b0)
           en_sync <= en_i;
       end

       assign out_o = in_i & en_sync;
       assign out_no = ~out_o;

   `else

    tc_clk_gating i_hyper_ck_gating (
        .clk_i     ( in_i  ),
        .en_i      ( en_i  ),
        .test_en_i ( 1'b0  ),
        .clk_o     ( out_o )
    );

    tc_clk_inverter i_hyper_ck_no_inv (
        .clk_i ( out_o  ),
        .clk_o ( out_no )
    );

   `endif // !`ifdef FPGA_EMUL
   
endmodule
