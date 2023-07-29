# Copyright (c) 2021 ETH Zurich.
# Thomas Benz <tbenz@iis.ee.ethz.ch>
# Paul Scheffler <paulsc@iis.ee.ethz.ch>

# Based on scripts from:
# Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
# Florian Zaruba <zarubaf@iis.ee.ethz.ch>
# Stefan Mach <smach@iis.ee.ethz.ch>
# Andreas Kurth <andkurt@iis.ee.ethz.ch>

# Synthesis Sweep varying Data width in TSMC65 for HyperBus

# clean up
sh rm -rf reports save out

# Keep TCK fixed at 3.5ns, sweep DW
set tck_sys 3.5
foreach param_dw {16 32 64 128 256 512 1024} {
    source scripts/synth.tcl
}

# Keep DW fixed at 128, sweep TCK
set param_dw 128
foreach tck_sys {5 4.5 4 3.5 3.25 3.125 3 2.875 2.75 2.5 2.375 2.25 2.125 2.0 1.875 1.75 1.625 1.5} {
    source scripts/synth.tcl
}