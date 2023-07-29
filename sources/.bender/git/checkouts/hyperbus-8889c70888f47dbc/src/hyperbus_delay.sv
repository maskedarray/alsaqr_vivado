// Hyperbus delay

// this code is unstable and most likely buggy
// it should not be used by anyone

// Author: Thomas Benz <paulsc@iis.ee.ethz.ch>
// Author: Paul Scheffler <paulsc@iis.ee.ethz.ch>

module hyperbus_delay (
    input  logic        in_i,
    input  logic [3:0]  delay_i,
    output logic        out_o
);

    generic_delay_D4_O1_3P750_CG0 i_delay (
        .clk_i      ( in_i      ),
        `ifndef TARGET_ASIC
        .enable_i   ( 1'b1      ),
        `endif
        .delay_i    ( delay_i   ),
        .clk_o      ( out_o     )
    );

endmodule : hyperbus_delay
