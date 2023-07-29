// Copyright (C) 2017-2018 ETH Zurich, University of Bologna
// All rights reserved.
//
// This code is under development and not yet released to the public.
// Until it is released, the code is under the copyright of ETH Zurich and
// the University of Bologna, and may contain confidential and/or unpublished
// work. Any reuse/redistribution is strictly forbidden without written
// permission from ETH Zurich.

// Description: : A single to double data rate converter.

// Author: Armin Berger <bergerar@ethz.ch>
// Author: Stephan Keck <kecks@ethz.ch>

module hyperbus_ddr_out #(
    parameter logic Init = 1'b0
)(
    input  logic clk_i,
    input  logic rst_ni,
    input  logic d0_i,
    input  logic d1_i,
    output logic q_o
);
    logic q0;
    logic q1;

`ifdef FPGA_EMUL
       always_comb
      begin
        if(clk_i == 1'b0)
           q_o = q1;
        else
           q_o = q0;
      end
`else
    tc_clk_mux2 i_ddrmux (
        .clk_o     ( q_o   ),
        .clk0_i    ( q1    ),
        .clk1_i    ( q0    ),
        .clk_sel_i ( clk_i )
    );
`endif // !`ifdef FPGA_EMUL
   
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            q0 <= Init;
            q1 <= Init;
        end else begin
            q0 <= d0_i;
            q1 <= d1_i;
        end
    end

endmodule
