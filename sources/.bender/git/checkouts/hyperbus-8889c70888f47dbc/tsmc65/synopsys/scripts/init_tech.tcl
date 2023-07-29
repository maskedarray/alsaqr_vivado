# Copyright (c) 2021 ETH Zurich.
# Thomas Benz <tbenz@iis.ee.ethz.ch>
# Paul Scheffler <paulsc@iis.ee.ethz.ch>

# Based on scripts from:
# Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
# Florian Zaruba <zarubaf@iis.ee.ethz.ch>
# Stefan Mach <smach@iis.ee.ethz.ch>
# Andreas Kurth <andkurt@iis.ee.ethz.ch>

# Prepare libraries for HyperBus in TSMC65

set PDK_BASE /usr/pack/tsmc-65-kgf/arm/tsmc/cln65lp

# worst case
if { ${corner} == "SS" } {

    set link_library [list \
        "*" \
        sc8_cln65lp_base_lvt_ss_typical_max_1p08v_125c.db \
        sc8_cln65lp_base_rvt_ss_typical_max_1p08v_125c.db \
        sc8_cln65lp_base_hvt_ss_typical_max_1p08v_125c.db \
        tpdn65lpnv2od3tc1.db \
        ]

    set target_library [list \
        sc8_cln65lp_base_hvt_ss_typical_max_1p08v_125c.db \
        sc8_cln65lp_base_lvt_ss_typical_max_1p08v_125c.db \
        sc8_cln65lp_base_rvt_ss_typical_max_1p08v_125c.db \
        ]

# typical case
} elseif { ${corner} == "TT" } {

    set link_library [list \
        "*" \
        sc8_cln65lp_base_lvt_tt_typical_max_1p20v_25c.db \
        sc8_cln65lp_base_rvt_tt_typical_max_1p20v_25c.db \
        sc8_cln65lp_base_hvt_tt_typical_max_1p20v_25c.db \
        tpdn65lpnv2od3tc1.db \
        ]

    set target_library [list \
        sc8_cln65lp_base_hvt_tt_typical_max_1p20v_25c.db \
        sc8_cln65lp_base_lvt_tt_typical_max_1p20v_25c.db \
        sc8_cln65lp_base_rvt_tt_typical_max_1p20v_25c.db \
        ]

# best case
} elseif { ${corner} == "FF" } {

    set link_library [list \
        "*" \
        sc8_cln65lp_base_lvt_ff_typical_min_1p32v_m40c.db \
        sc8_cln65lp_base_rvt_ff_typical_min_1p32v_m40c.db \
        sc8_cln65lp_base_hvt_ff_typical_min_1p32v_m40c.db \
        tpdn65lpnv2od3tc1.db \
        ]

    set target_library [list \
        sc8_cln65lp_base_hvt_ff_typical_min_1p32v_m40c.db \
        sc8_cln65lp_base_lvt_ff_typical_min_1p32v_m40c.db \
        sc8_cln65lp_base_rvt_ff_typical_min_1p32v_m40c.db \
        ]

# error
} else {
    exit -7
}

# prime time has no synthetic library
if {$synopsys_program_name == "pt_shell"} {
    set search_path       [concat ../technology/db $search_path]
    set link_library      [concat  $link_library      dw_foundation.sldb]
} else {
    set synthetic_library [concat  $synthetic_library dw_foundation.sldb]
    set link_library      [concat  $link_library      dw_foundation.sldb]
}
