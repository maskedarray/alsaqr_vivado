# Copyright (c) 2021 ETH Zurich.
# Thomas Benz <tbenz@iis.ee.ethz.ch>
# Paul Scheffler <paulsc@iis.ee.ethz.ch>

# Based on scripts from:
# Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
# Florian Zaruba <zarubaf@iis.ee.ethz.ch>
# Stefan Mach <smach@iis.ee.ethz.ch>
# Andreas Kurth <andkurt@iis.ee.ethz.ch>

# Synthesis constraints for common_cells in Zest in TSMC65
# Dependencies: CDCs assuming distinct clock groups with -asynchronous -allow_paths


################
##   Config   ##
################

# CAREFUL: you may set this to false for debugging, but NOT for signoff!
set cc_cdc_missing_clk_fatal false
set cc_cdc_missing_clk_delay 2.0


#################
##   Helpers   ##
#################

# TODO: check somehow if src and dst clocks in asynchrounous groups?
proc find_cc_cdc_max_delay {cel cel_type} {
    global cc_cdc_missing_clk_fatal
    global cc_cdc_missing_clk_delay
    set src_clk_obj  [get_attribute [get_timing_paths -to ${cel}/src_clk_i] startpoint_clock]
    set src_clk_name [get_attribute [get_clocks ${src_clk_obj}] name]
    set src_clk_tck  [get_attribute [get_clocks ${src_clk_obj}] period]
    set dst_clk_obj  [get_attribute [get_timing_paths -to ${cel}/dst_clk_i] startpoint_clock]
    set dst_clk_name [get_attribute [get_clocks ${dst_clk_obj}] name]
    set dst_clk_tck  [get_attribute [get_clocks ${dst_clk_obj}] period]
    if {$src_clk_tck ne "" && $dst_clk_tck ne ""} {
            puts "\[common_cells\] Information: ${cel_type} with src ${src_clk_name} (${src_clk_tck}) and dst ${dst_clk_name} (${dst_clk_tck}) at ${cel}"
    } else {
        if {${cc_cdc_missing_clk_fatal}} {
            puts "\[common_cells\] Error: ${cel_type} with undefined src or dst clock at ${cel}"
            exit 67
        } else {
            puts "\[common_cells\] Warning: ${cel_type} with undefined src or dst clock at ${cel}; defaulting on maximum delay ${cc_cdc_missing_clk_delay}"
            return ${cc_cdc_missing_clk_delay}
        }
    }
    return [expr min(${src_clk_tck}, ${dst_clk_tck})]
}


#####################
##   Constraints   ##
#####################

# cdc_2phase
foreach_in_collection cel_ref [get_cells -hierarchical -filter "hdl_template==cdc_2phase"] {
    set cel [get_object_name $cel_ref]
    set mdel [find_cc_cdc_max_delay $cel {cdc_2phase}]
    set_ungroup                 [get_cells "$cel $cel/*"]   false
    set_boundary_optimization   [get_cells "$cel $cel/*"]   false
    set_dont_touch              [get_cells $cel/*/*_reg]    true
    set_dont_touch              [get_nets $cel/async*]      true
    set async_pins [get_ports $cel/*/async_*]
    set_max_delay ${mdel} -through ${async_pins} -through ${async_pins}
    set_false_path -hold -through ${async_pins} -through ${async_pins}
}

# cdc_fifo_2phase (only constraints in addition to contained cdc_2phase instances)
foreach_in_collection cel_ref [get_cells -hierarchical -filter "hdl_template==cdc_fifo_2phase"] {
    set cel [get_object_name $cel_ref]
    set mdel [find_cc_cdc_max_delay $cel {cdc_fifo_2phase}]
    set_max_delay ${mdel} -through ${async_pins} -through ${async_pins}
    set_false_path -hold -through ${async_pins} -through ${async_pins}
}

# cdc_fifo_gray
foreach_in_collection cel_ref [get_cells -hierarchical -filter "hdl_template==cdc_fifo_gray"] {
    set cel [get_object_name $cel_ref]
    set mdel [find_cc_cdc_max_delay $cel {cdc_fifo_gray}]
    set_ungroup                 [get_cells "$cel $cel/*"]   false
    set_boundary_optimization   [get_cells "$cel $cel/*"]   false
    set_dont_touch              [get_nets $cel/async*]      true
    set async_pins [get_pins -of_objects [get_cells "$cel $cel/*"] -filter async]
    set_max_delay ${mdel} -through ${async_pins} -through ${async_pins}
    set_false_path -hold -through ${async_pins} -through ${async_pins}
}
