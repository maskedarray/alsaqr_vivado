module pmu_top #(
    parameter int unsigned NUM_COUNTER = 0,
    parameter int unsigned NUM_EVU = 0,
    parameter int unsigned COUNTER_WIDTH = 64,
    parameter int unsigned AxiLiteAddrWidth = 32'd0,
    parameter int unsigned AxiLiteDataWidth = 32'd0,
    parameter type lite_req_t     = logic,
    parameter type lite_resp_t    = logic
) (
    input logic                         clk_i,
    input logic                         rst_ni,
    // Port ID 1
    SPU_INTF.Output                     spu_in,

    // AXI4-Lite slave port response, configuration
    input lite_req_t                    conf_req_i,
    // AXI4-Lite master port response, configuration
    output lite_resp_t                  conf_resp_o,
    output logic [NUM_COUNTER-1:0]      intr_o
);
    `include "axi/typedef.svh"
    import pmu_pkg::*;    
    
    // Memory Map - Local Parameters and TypeDefs
    localparam int unsigned TIMER_WIDTH = 64;
    
    localparam int unsigned TimerAlignToBytes               = TIMER_WIDTH / 8;
    localparam int unsigned TimerNumCfgRegs                 = 1;
    localparam int unsigned TimerNumBytesCfgRegs            = TimerNumCfgRegs *
                                                              TimerAlignToBytes;

    localparam int unsigned InitBudget_AlignToBytes         = COUNTER_WIDTH / 8;
    localparam int unsigned InitBudget_NumCfgRegs           = NUM_COUNTER;
    localparam int unsigned InitBudget_NumBytesCfgRegs      = InitBudget_NumCfgRegs *
                                                              InitBudget_AlignToBytes;

    localparam int unsigned Counter_AlignToBytes            = COUNTER_WIDTH / 8;
    localparam int unsigned Counter_NumCfgRegs              = NUM_COUNTER;
    localparam int unsigned Counter_NumBytesCfgRegs         = Counter_NumCfgRegs *
                                                              Counter_AlignToBytes;

    localparam int unsigned EventSelCfg_AlignToBytes        = EVENT_SEL_CONIFG_WIDTH / 8;
    localparam int unsigned EventSelCfg_NumCfgRegs          = NUM_COUNTER;
    localparam int unsigned EventSelCfg_NumBytesCfgRegs     = EventSelCfg_NumCfgRegs *
                                                              EventSelCfg_AlignToBytes;

    localparam int unsigned EventInfoCfg_AlignToBytes       = EVENT_INFO_CONFIG_WIDTH / 8;
    localparam int unsigned EventInfoCfg_NumCfgRegs         = NUM_COUNTER;
    localparam int unsigned EventInfoCfg_NumBytesCfgRegs    = EventInfoCfg_NumCfgRegs *
                                                              EventInfoCfg_AlignToBytes;

    localparam int unsigned NumBytesCfgRegs =  2*TimerNumBytesCfgRegs +
                                               InitBudget_NumBytesCfgRegs +
                                               Counter_NumBytesCfgRegs + 
                                               EventSelCfg_NumBytesCfgRegs + 
                                               EventInfoCfg_NumBytesCfgRegs;

    typedef logic [7:0] byte_t;

    typedef logic [TIMER_WIDTH-1:0]                     timer_t;
    typedef logic [NUM_COUNTER-1:0][COUNTER_WIDTH-1:0]  counter_t;
    typedef logic [NUM_COUNTER-1:0][COUNTER_WIDTH-1:0]  init_budget_t;

    typedef logic [TimerNumBytesCfgRegs-1:0]            strb_timer_t;
    typedef logic [Counter_NumBytesCfgRegs-1:0]         strb_counter_t;
    typedef logic [InitBudget_NumBytesCfgRegs-1:0]      strb_init_budget_t;
    typedef logic [EventSelCfg_NumBytesCfgRegs-1:0]     strb_event_sel_cfg_t;
    typedef logic [EventInfoCfg_NumBytesCfgRegs-1:0]    strb_event_info_cfg_t;

    timer_t timer;

    typedef struct packed {
        timer_t                                     timer;
        timer_t                                     periodReg;
        init_budget_t                               initBudgetReg;
        event_info_config_t [NUM_COUNTER-1:0]       eventInfoCfg;
        event_sel_config_t  [NUM_COUNTER-1:0]       eventSelCfg;
        counter_t                                   counter;
    } reg_map_t;

    typedef struct packed {
        strb_timer_t            timer;        
        strb_timer_t            periodReg;
        strb_init_budget_t      initBudgetReg;
        strb_event_info_cfg_t   eventInfoCfg;
        strb_event_sel_cfg_t    eventSelCfg;
        strb_counter_t          counter;
    } strb_map_t;                                               

    typedef union packed {
        byte_t              [NumBytesCfgRegs-1:0]   ByteMap;
        reg_map_t                                   StructMap;
    } union_reg_data_t;

    typedef union packed {
        logic               [NumBytesCfgRegs-1:0]   LogicMap;
        strb_map_t                                  StrbMap;
    } union_strb_data_t;

    // ************************************************************************
    // AXI4-Lite Registers
    // ************************************************************************
    union_reg_data_t    reg_d, reg_q;
    union_strb_data_t   reg_wr_o;
    union_strb_data_t   reg_load_i;

    counter_t           counter_q;

    // wr_active_o is asserted on the clock cycle at 
    // which the AXI4 write take places. 
    // Need to register it, to update the counter after the write. 
    strb_map_t   reg_wr_r;

    always_ff @ (posedge clk_i) begin
        if (!rst_ni) begin
            reg_wr_r <= 0;
        end else begin
            reg_wr_r <= reg_wr_o.StrbMap;
        end
    end
    
    localparam strb_map_t strb_ReadOnly = strb_map_t'{
        timer: {TimerNumBytesCfgRegs{1'b1}},
        default: '0
    };

    localparam union_strb_data_t ReadOnly = strb_ReadOnly;
    localparam strb_map_t RstVal = 0;

    // reg_load_i must be intialized. 
    // It allows non-AX4-Lite writes to the registers.
    // These non-AXI4-Lite writes take precedence over AXI4-Lite writes.
    // If the reg_load_i signal is True for any register than any AXI4-Lite 
    // to that register in that clock cycle is stalled.
    always_comb begin
        reg_load_i.StrbMap.timer            = {TimerAlignToBytes{1'b1}};
        reg_load_i.StrbMap.periodReg        = 0;
        reg_load_i.StrbMap.eventSelCfg      = 0;
        reg_load_i.StrbMap.eventInfoCfg     = 0;
        reg_load_i.StrbMap.initBudgetReg    = 0;

        reg_d.StructMap.timer           = timer;
        reg_d.StructMap.periodReg       = reg_q.StructMap.periodReg;
        reg_d.StructMap.counter         = counter_q;
        reg_d.StructMap.eventSelCfg     = reg_q.StructMap.eventSelCfg;
        reg_d.StructMap.eventInfoCfg    = reg_q.StructMap.eventInfoCfg;
        reg_d.StructMap.initBudgetReg   = reg_q.StructMap.initBudgetReg;
    end

    axi_lite_regs#(
        .RegNumBytes  ( NumBytesCfgRegs     ),
        .AxiAddrWidth ( AxiLiteAddrWidth    ),
        .AxiDataWidth ( AxiLiteDataWidth    ),
        .PrivProtOnly ( 1'b0                ),
        .SecuProtOnly ( 1'b0                ),
        .AxiReadOnly  ( ReadOnly.StrbMap    ), 
        .RegRstVal    ( RstVal              ),
        .req_lite_t   ( lite_req_t          ),
        .resp_lite_t  ( lite_resp_t         )
        ) i_axi_lite_regs (
        .clk_i,
        .rst_ni,
        .axi_req_i   ( conf_req_i           ),
        .axi_resp_o  ( conf_resp_o          ),
        .wr_active_o ( reg_wr_o.LogicMap    ),
        .rd_active_o ( /*Not used*/         ),
        .reg_d_i     ( reg_d.ByteMap        ),
        .reg_load_i  ( reg_load_i.LogicMap  ),
        .reg_q_o     ( reg_q.ByteMap        )
    );

    // ************************************************************************
    // Counters
    // ************************************************************************
    logic [NUM_COUNTER-1:0] event_en;
    logic [NUM_COUNTER-1:0] source_en;
    logic [NUM_COUNTER-1:0] port_en;

    logic [NUM_COUNTER-1:0] count_en;

    event_sel_config_t [NUM_COUNTER-1:0] event_sel_config; 
    assign event_sel_config = reg_d.StructMap.eventSelCfg;

    timer_t period_reg;
    assign period_reg = reg_d.StructMap.periodReg;

    generate
        genvar i;
        
        // always_ff block to generate enable signals for counters.
        for(i=0; i<NUM_COUNTER; i=i+1) begin
            always_ff @ (posedge clk_i) begin
                if (!rst_ni) begin
                    event_en[i]  <= 0;
                    source_en[i] <= 1;
                    port_en[i]   <= 1;
                end else if ((spu_in.e_id != 0) && 
                             (event_sel_config[i].event_id_val != 0) &&    // verify this, i am doing this to test the design
                             (event_sel_config[i].event_id_mask != 0) 
                ) begin
                    if ( 
                        (event_sel_config[i].event_id_mask & spu_in.e_id) 
                        == event_sel_config[i].event_id_val 
                    ) begin
                        event_en[i]  <= 1;
                    end else begin
                        event_en[i]  <= 0;
                    end
                end
            end
        end

        for(i=0; i<NUM_COUNTER; i=i+1) begin
            always_comb begin
                if (event_en[i] && source_en[i] && port_en[i]) begin
                    count_en[i] = 1;
                end else begin
                    count_en[i] = 0;
                end
            end
        end        

        // always_ff block for counters.
        // counter_q, and reg_load_i.StrbMap.counter are updated here.
        for(i=0; i<NUM_COUNTER; i=i+1) begin
            always_ff @ (posedge clk_i) begin
                if (!rst_ni) begin
                    counter_q[i] <= 0;
                end 
                // Check if AXI4-Lite write to the counter happened in the last clock cycle.
                // Update counter_q to new AXI4-Lite value.
                else if (
                    |(reg_wr_r.counter[i*Counter_AlignToBytes +: Counter_AlignToBytes])
                ) begin
                    counter_q[i] <= reg_q.StructMap.counter[i];                 /// this might create some timing violations later ?? 
                end 
                // Check if a new MemGuard round has started.
                // Update counter_q to initBudgetReg.
                // Update reg_load_i.StrbMap.counter to indicate a non-AXI write to counter.
                else if (timer == period_reg-2) begin
                    counter_q[i] <= reg_q.StructMap.initBudgetReg[i];
                    reg_load_i.StrbMap.counter[i*Counter_AlignToBytes +: Counter_AlignToBytes] <= {Counter_AlignToBytes{1'b1}};
                end 
                // Check if a new selected event was transmitted.
                // Increment counter_q.
                // Update reg_load_i.StrbMap.counter to indicate a non-AXI write to counter.
                else if (count_en[i]) begin
                    counter_q[i] <= counter_q[i] + 1;
                    reg_load_i.StrbMap.counter[i*Counter_AlignToBytes +: Counter_AlignToBytes] <= {Counter_AlignToBytes{1'b1}};
                end 
                // Update reg_load_i.StrbMap.counter to indicate no non-AXI write to counter.
                else begin
                    reg_load_i.StrbMap.counter[i*Counter_AlignToBytes +: Counter_AlignToBytes] <= 0;
                end
            end
        end
    endgenerate

    // ************************************************************************
    // Overflow Interrupt Signaling
    // ************************************************************************
    logic [NUM_COUNTER-1:0] overflow_intr;
    
    generate 
        for (i=0; i<NUM_COUNTER; i=i+1) begin
            always_comb begin
                if ((counter_q[i] == {COUNTER_WIDTH{1'b1}}) &&
                    (count_en[i] == 1)
                ) begin
                    overflow_intr[i] =  1;
                end else begin
                    overflow_intr[i] =  0;
                end
            end
        end

        for (i=0; i<NUM_COUNTER; i=i+1) begin
            always_ff @ (posedge clk_i) begin
                if (!rst_ni) begin
                    intr_o[i] <= 0;
                end else begin
                    intr_o[i] <= overflow_intr[i];
                end
            end
        end
    endgenerate

    // ************************************************************************
    // PMU Timer
    // ************************************************************************
    always_ff @ (posedge clk_i) begin
        if (!rst_ni) begin
            timer <= 0;
        end else if (period_reg != 0) begin
            if (timer < period_reg-1) begin
                timer <= timer + 1;
            end else begin
                timer <= 0;
            end
        end
    end

endmodule

