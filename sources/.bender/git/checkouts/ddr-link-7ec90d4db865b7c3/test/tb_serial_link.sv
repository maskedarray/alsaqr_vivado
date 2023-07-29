`timescale 1ps / 1ps
module tb_serial_link();

    fixture_serial_link fix();

    logic [63:0] rdata [$];
    logic [63:0] wdata [$] = {128'h8899aabbccddeeff_12345678facefeed};

    initial begin
        fix.wait_for_reset();
        fix.wait_for_link_1_train_complete();
        fix.wait_for_link_2_train_complete();
        fix.ddr_1_write_size(32'h0000_0005, 4'h1, wdata);
        fix.ddr_2_write_size(32'h0000_0005, 4'h1, wdata);
        fix.ddr_2_write_size(32'h0000_0007, 4'h1, wdata);
        fix.ddr_2_write_size(32'h0000_000a, 4'h1, wdata);
        fix.ddr_2_write_size(32'h0000_000d, 4'h1, wdata);
        fix.ddr_1_read_size_compare(32'h0000_0000, 4'h3, 0, rdata);
        fix.display_read(0, rdata);
        fix.ddr_2_read_size_compare(32'h0000_0000, 4'h3, 7, rdata);
        fix.display_read(7, rdata);
        fix.stop_sim();
    end

    initial begin
        #100000ns;
        $stop();
    end

endmodule : tb_serial_link
