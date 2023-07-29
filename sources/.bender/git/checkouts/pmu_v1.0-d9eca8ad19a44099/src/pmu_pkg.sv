package pmu_pkg;

    // Event Selection Config Register
    localparam EVENT_MASK_BITS      = 4;
    localparam SOURCE_MASK_BITS     = 4;
    localparam PORT_MASK_BITS       = 4; 
    localparam EVENT_SEL_PAD_BITS   = 8;

    typedef struct packed {
        logic [EVENT_SEL_PAD_BITS-1:0]  pad_field;
        logic [PORT_MASK_BITS-1:0]      port_id_val;
        logic [PORT_MASK_BITS-1:0]      port_id_mask;
        logic [SOURCE_MASK_BITS-1:0]    source_id_val;
        logic [SOURCE_MASK_BITS-1:0]    source_id_mask;
        logic [EVENT_MASK_BITS-1:0]     event_id_val;
        logic [EVENT_MASK_BITS-1:0]     event_id_mask;
    } event_sel_config_t;

    // Must be a multiple of 8!
    // For AXI-lite interface to work!
    localparam EVENT_SEL_CONIFG_WIDTH = (
                                    EVENT_MASK_BITS + 
                                    SOURCE_MASK_BITS + 
                                    PORT_MASK_BITS
                                 )*2 + EVENT_SEL_PAD_BITS;

    // Event Info Config Register
    localparam EISF_START_BITS      = 1;
    localparam EISF_END_BITS        = 1;
    localparam OPCODE_BITS          = 5;
    localparam VAL_UPPER_BITS       = 4;
    localparam VAL_LOWER_BITS       = 4;
    localparam EVENT_INFO_EN        = 1;
    localparam OVERFLOW_INTR_EN     = 1;
    localparam EVENT_INFO_PAD_BITS  = 15;

    typedef enum logic [OPCODE_BITS-1:0] {
        ADD                 =  0,
        KEEP_MAX            =  1,
        KEEP_MIN            =  2,
        INCR_CMP_EQ         =  3,
        INCR_CMP_NEQ        =  4,
        INCR_CMP_LT         =  5,
        INCR_CMP_GT         =  6,
        INCR_CMP_LTE        =  7,
        INCR_CMP_GTE        =  8,
        INCR_IN_RANGE       =  9,
        INCR_NOT_IN_RANGE   = 10,
        ADD_CMP_EQ          = 11,
        ADD_CMP_NEQ         = 12,
        ADD_CMP_LT          = 13,
        ADD_CMP_GT          = 14,
        ADD_CMP_LTE         = 15,
        ADD_CMP_GTE         = 16,
        ADD_IN_RANGE        = 17,
        ADD_NOT_IN_RANGE    = 18
    } opcode_e;

    typedef struct packed {
        logic [EVENT_INFO_PAD_BITS-1:0] pad_field;
        logic [EISF_START_BITS-1:0]     eisf_start;
        logic [EISF_END_BITS-1:0]       eisf_end;
        opcode_e                        opcode;
        logic [VAL_LOWER_BITS-1:0]      val_l;
        logic [VAL_UPPER_BITS-1:0]      val_u;
        logic [EVENT_INFO_EN-1:0]       event_info_en;
        logic [OVERFLOW_INTR_EN-1:0]    overflow_intr_en;                  
    } event_info_config_t;  

    localparam EVENT_INFO_CONFIG_WIDTH = EISF_START_BITS + 
                                         EISF_END_BITS + 
                                         OPCODE_BITS + 
                                         VAL_UPPER_BITS + 
                                         VAL_LOWER_BITS +
                                         EVENT_INFO_EN + 
                                         OVERFLOW_INTR_EN +
                                         EVENT_INFO_PAD_BITS;
                                         
    typedef struct packed {
        /// AXI4+ATOP address width of the config AXI LITE port, in bits
        int unsigned LitePortAddrWidth;
        /// AXI4+ATOP Data width of the config AXI LITE port Has to be 32 bit
        int unsigned LitePortDataWidth;
    } pmu_axi_cfg_t;                                                 

endpackage

