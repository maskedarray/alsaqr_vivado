module serial_link_synth_wrapper #(

    `include "axi/assign.svh"
    `include "axi/typedef.svh"
    `include "register_interface/typedef.svh"
    // Axi Parameters
    parameter int unsigned AxiAddrWidth  = -1,
    parameter int unsigned AxiDataWidth  = -1,
    parameter int unsigned AxiIdInWidth  = -1,
    parameter int unsigned AxiIdOutWidth = -1,
    parameter int unsigned AxiUserWidth  = -1,
    // Regbus parameters
    parameter int unsigned RegAddrWidth  = -1,
    parameter int unsigned RegDataWidth  = -1,
    // Dependent parameters; do not override!
    parameter type axi_addr_t   = logic [  AxiAddrWidth-1:0],
    parameter type axi_data_t   = logic [  AxiDataWidth-1:0],
    parameter type axi_strb_t   = logic [AxiDataWidth/8-1:0],
    parameter type axi_id_in_t  = logic [  AxiIdInWidth-1:0],
    parameter type axi_id_out_t = logic [ AxiIdOutWidth-1:0],
    parameter type axi_user_t   = logic [  AxiUserWidth-1:0],
    parameter type reg_addr_t   = logic [  RegAddrWidth-1:0],
    parameter type reg_data_t   = logic [  RegDataWidth-1:0],
    parameter type reg_strb_t   = logic [RegDataWidth/8-1:0]
) (
    // SoC
    input  logic               clk_i,
    input  logic               rst_ni,
    input  logic               testmode_i,
    // DDR
    input  logic               ddr_clk_i,
    input  logic [3:0]         ddr_i,
    output logic [3:0]         ddr_o,
    // AXI In Bus
    input  axi_id_in_t         axi_in_aw_id_i,
    input  axi_addr_t          axi_in_aw_addr_i,
    input  axi_pkg::len_t      axi_in_aw_len_i,
    input  axi_pkg::size_t     axi_in_aw_size_i,
    input  axi_pkg::burst_t    axi_in_aw_burst_i,
    input  logic               axi_in_aw_lock_i,
    input  axi_pkg::cache_t    axi_in_aw_cache_i,
    input  axi_pkg::prot_t     axi_in_aw_prot_i,
    input  axi_pkg::qos_t      axi_in_aw_qos_i,
    input  axi_pkg::region_t   axi_in_aw_region_i,
    input  axi_pkg::atop_t     axi_in_aw_atop_i,
    input  axi_user_t          axi_in_aw_user_i,
    input  logic               axi_in_aw_valid_i,
    output logic               axi_in_aw_ready_o,
    input  axi_data_t          axi_in_w_data_i,
    input  axi_strb_t          axi_in_w_strb_i,
    input  logic               axi_in_w_last_i,
    input  axi_user_t          axi_in_w_user_i,
    input  logic               axi_in_w_valid_i,
    output logic               axi_in_w_ready_o,
    output axi_id_in_t         axi_in_b_id_o,
    output axi_pkg::resp_t     axi_in_b_resp_o,
    output axi_user_t          axi_in_b_user_o,
    output logic               axi_in_b_valid_o,
    input  logic               axi_in_b_ready_i,
    input  axi_id_in_t         axi_in_ar_id_i,
    input  axi_addr_t          axi_in_ar_addr_i,
    input  axi_pkg::len_t      axi_in_ar_len_i,
    input  axi_pkg::size_t     axi_in_ar_size_i,
    input  axi_pkg::burst_t    axi_in_ar_burst_i,
    input  logic               axi_in_ar_lock_i,
    input  axi_pkg::cache_t    axi_in_ar_cache_i,
    input  axi_pkg::prot_t     axi_in_ar_prot_i,
    input  axi_pkg::qos_t      axi_in_ar_qos_i,
    input  axi_pkg::region_t   axi_in_ar_region_i,
    input  axi_user_t          axi_in_ar_user_i,
    input  logic               axi_in_ar_valid_i,
    output logic               axi_in_ar_ready_o,
    output axi_id_in_t         axi_in_r_id_o,
    output axi_data_t          axi_in_r_data_o,
    output axi_pkg::resp_t     axi_in_r_resp_o,
    output logic               axi_in_r_last_o,
    output axi_user_t          axi_in_r_user_o,
    output logic               axi_in_r_valid_o,
    input  logic               axi_in_r_ready_i,
    // AXI Out Bus
    output axi_id_out_t        axi_out_aw_id_o,
    output axi_addr_t          axi_out_aw_addr_o,
    output axi_pkg::len_t      axi_out_aw_len_o,
    output axi_pkg::size_t     axi_out_aw_size_o,
    output axi_pkg::burst_t    axi_out_aw_burst_o,
    output logic               axi_out_aw_lock_o,
    output axi_pkg::cache_t    axi_out_aw_cache_o,
    output axi_pkg::prot_t     axi_out_aw_prot_o,
    output axi_pkg::qos_t      axi_out_aw_qos_o,
    output axi_pkg::region_t   axi_out_aw_region_o,
    output axi_pkg::atop_t     axi_out_aw_atop_o,
    output axi_user_t          axi_out_aw_user_o,
    output logic               axi_out_aw_valid_o,
    input  logic               axi_out_aw_ready_i,
    output axi_data_t          axi_out_w_data_o,
    output axi_strb_t          axi_out_w_strb_o,
    output logic               axi_out_w_last_o,
    output axi_user_t          axi_out_w_user_o,
    output logic               axi_out_w_valid_o,
    input  logic               axi_out_w_ready_i,
    input  axi_id_out_t        axi_out_b_id_i,
    input  axi_pkg::resp_t     axi_out_b_resp_i,
    input  axi_user_t          axi_out_b_user_i,
    input  logic               axi_out_b_valid_i,
    output logic               axi_out_b_ready_o,
    output axi_id_out_t        axi_out_ar_id_o,
    output axi_addr_t          axi_out_ar_addr_o,
    output axi_pkg::len_t      axi_out_ar_len_o,
    output axi_pkg::size_t     axi_out_ar_size_o,
    output axi_pkg::burst_t    axi_out_ar_burst_o,
    output logic               axi_out_ar_lock_o,
    output axi_pkg::cache_t    axi_out_ar_cache_o,
    output axi_pkg::prot_t     axi_out_ar_prot_o,
    output axi_pkg::qos_t      axi_out_ar_qos_o,
    output axi_pkg::region_t   axi_out_ar_region_o,
    output axi_user_t          axi_out_ar_user_o,
    output logic               axi_out_ar_valid_o,
    input  logic               axi_out_ar_ready_i,
    input  axi_id_out_t        axi_out_r_id_i,
    input  axi_data_t          axi_out_r_data_i,
    input  axi_pkg::resp_t     axi_out_r_resp_i,
    input  logic               axi_out_r_last_i,
    input  axi_user_t          axi_out_r_user_i,
    input  logic               axi_out_r_valid_i,
    output logic               axi_out_r_ready_o,
    // Reg bus
    input  reg_addr_t          rbus_req_addr_i,
    input  logic               rbus_req_write_i,
    input  reg_data_t          rbus_req_wdata_i,
    input  reg_strb_t          rbus_req_wstrb_i,
    input  logic               rbus_req_valid_i,
    output reg_data_t          rbus_rsp_rdata_o,
    output logic               rbus_rsp_ready_o,
    output logic               rbus_rsp_error_o
);

    // AXI IN Types
    `AXI_TYPEDEF_AW_CHAN_T(aw_chan_in_t, axi_addr_t, axi_id_in_t, axi_user_t)
    `AXI_TYPEDEF_W_CHAN_T(w_chan_in_t, axi_data_t, axi_strb_t, axi_user_t)
    `AXI_TYPEDEF_B_CHAN_T(b_chan_in_t, axi_id_in_t, axi_user_t)
    `AXI_TYPEDEF_AR_CHAN_T(ar_chan_in_t, axi_addr_t, axi_id_in_t, axi_user_t)
    `AXI_TYPEDEF_R_CHAN_T(r_chan_in_t, axi_data_t, axi_id_in_t, axi_user_t)
    `AXI_TYPEDEF_REQ_T(axi_req_in_t, aw_chan_in_t, w_chan_in_t, ar_chan_in_t)
    `AXI_TYPEDEF_RESP_T(axi_rsp_in_t, b_chan_in_t, r_chan_in_t)

    // AXI IN Types
    `AXI_TYPEDEF_AW_CHAN_T(aw_chan_out_t, axi_addr_t, axi_id_out_t, axi_user_t)
    `AXI_TYPEDEF_W_CHAN_T(w_chan_out_t, axi_data_t, axi_strb_t, axi_user_t)
    `AXI_TYPEDEF_B_CHAN_T(b_chan_out_t, axi_id_out_t, axi_user_t)
    `AXI_TYPEDEF_AR_CHAN_T(ar_chan_out_t, axi_addr_t, axi_id_out_t, axi_user_t)
    `AXI_TYPEDEF_R_CHAN_T(r_chan_out_t, axi_data_t, axi_id_out_t, axi_user_t)
    `AXI_TYPEDEF_REQ_T(axi_req_out_t, aw_chan_out_t, w_chan_out_t, ar_chan_out_t)
    `AXI_TYPEDEF_RESP_T(axi_rsp_out_t, b_chan_out_t, r_chan_out_t)

    axi_req_in_t   axi_req_in;
    axi_rsp_in_t   axi_rsp_in;
    axi_req_out_t  axi_req_out;
    axi_rsp_out_t  axi_rsp_out;

    // Regbus Types
    `REG_BUS_TYPEDEF_REQ(reg_req_t, reg_addr_t, reg_data_t, reg_strb_t)
    `REG_BUS_TYPEDEF_RSP(reg_rsp_t, reg_data_t)

    reg_req_t reg_req;
    reg_rsp_t reg_rsp;

    // dut
    serial_link #(
        .axi_in_req_t   ( axi_req_in_t   ),
        .axi_in_rsp_t   ( axi_rsp_in_t   ),
        .axi_out_req_t  ( axi_req_out_t  ),
        .axi_out_rsp_t  ( axi_rsp_out_t  ),
        .cfg_req_t      ( reg_req_t      ),
        .cfg_rsp_t      ( reg_rsp_t      )
    ) i_serial_link (
        .clk_i          ( clk_i          ),
        .rst_ni         ( rst_ni         ),
        .testmode_i     ( testmode_i     ),
        .axi_in_req_i   ( axi_req_in     ),
        .axi_in_rsp_o   ( axi_rsp_in     ),
        .axi_out_req_o  ( axi_req_out    ),
        .axi_out_rsp_i  ( axi_rsp_out    ),
        .cfg_req_i      ( reg_req        ),
        .cfg_rsp_o      ( reg_rsp        ),
        .ddr_clk_i      ( ddr_clk_i      ),
        .ddr_i          ( ddr_i          ),
        .ddr_o          ( ddr_o          )
    );


    // AXI IN
    assign axi_req_in.aw.id        = axi_in_aw_id_i;
    assign axi_req_in.aw.addr      = axi_in_aw_addr_i;
    assign axi_req_in.aw.len       = axi_in_aw_len_i;
    assign axi_req_in.aw.size      = axi_in_aw_size_i;
    assign axi_req_in.aw.burst     = axi_in_aw_burst_i;
    assign axi_req_in.aw.lock      = axi_in_aw_lock_i;
    assign axi_req_in.aw.cache     = axi_in_aw_cache_i;
    assign axi_req_in.aw.prot      = axi_in_aw_prot_i;
    assign axi_req_in.aw.qos       = axi_in_aw_qos_i;
    assign axi_req_in.aw.region    = axi_in_aw_region_i;
    assign axi_req_in.aw.atop      = axi_in_aw_atop_i;
    assign axi_req_in.aw.user      = axi_in_aw_user_i;
    assign axi_req_in.aw_valid     = axi_in_aw_valid_i;
    assign axi_aw_ready_o          = axi_rsp_in.aw_ready;
    assign axi_req_in.w.data       = axi_in_w_data_i;
    assign axi_req_in.w.strb       = axi_in_w_strb_i;
    assign axi_req_in.w.last       = axi_in_w_last_i;
    assign axi_req_in.w.user       = axi_in_w_user_i;
    assign axi_req_in.w_valid      = axi_in_w_valid_i;
    assign axi_w_ready_o           = axi_rsp_in.w_ready;
    assign axi_b_id_o              = axi_rsp_in.b.id;
    assign axi_b_resp_o            = axi_rsp_in.b.resp;
    assign axi_b_user_o            = axi_rsp_in.b.user;
    assign axi_b_valid_o           = axi_rsp_in.b_valid;
    assign axi_req_in.b_ready      = axi_in_b_ready_i;
    assign axi_req_in.ar.id        = axi_in_ar_id_i;
    assign axi_req_in.ar.addr      = axi_in_ar_addr_i;
    assign axi_req_in.ar.len       = axi_in_ar_len_i;
    assign axi_req_in.ar.size      = axi_in_ar_size_i;
    assign axi_req_in.ar.burst     = axi_in_ar_burst_i;
    assign axi_req_in.ar.lock      = axi_in_ar_lock_i;
    assign axi_req_in.ar.cache     = axi_in_ar_cache_i;
    assign axi_req_in.ar.prot      = axi_in_ar_prot_i;
    assign axi_req_in.ar.qos       = axi_in_ar_qos_i;
    assign axi_req_in.ar.region    = axi_in_ar_region_i;
    assign axi_req_in.ar.user      = axi_in_ar_user_i;
    assign axi_req_in.ar_valid     = axi_in_ar_valid_i;
    assign axi_ar_ready_o          = axi_rsp_in.ar_ready;
    assign axi_r_id_o              = axi_rsp_in.r.id;
    assign axi_r_data_o            = axi_rsp_in.r.data;
    assign axi_r_resp_o            = axi_rsp_in.r.resp;
    assign axi_r_last_o            = axi_rsp_in.r.last;
    assign axi_r_user_o            = axi_rsp_in.r.user;
    assign axi_r_valid_o           = axi_rsp_in.r_valid;
    assign axi_req_in.r_ready      = axi_in_r_ready_i;

    // AXI Out
    assign axi_out_aw_id_o         =   axi_req_out.aw.id;
    assign axi_out_aw_addr_o       =   axi_req_out.aw.addr;
    assign axi_out_aw_len_o        =   axi_req_out.aw.len;
    assign axi_out_aw_size_o       =   axi_req_out.aw.size;
    assign axi_out_aw_burst_o      =   axi_req_out.aw.burst;
    assign axi_out_aw_lock_o       =   axi_req_out.aw.lock;
    assign axi_out_aw_cache_o      =   axi_req_out.aw.cache;
    assign axi_out_aw_prot_o       =   axi_req_out.aw.prot;
    assign axi_out_aw_qos_o        =   axi_req_out.aw.qos;
    assign axi_out_aw_region_o     =   axi_req_out.aw.region;
    assign axi_out_aw_atop_o       =   axi_req_out.aw.atop;
    assign axi_out_aw_user_o       =   axi_req_out.aw.user;
    assign axi_out_aw_valid_o      =   axi_req_out.aw_valid;
    assign axi_rsp_out.aw_ready    =   axi_out_aw_ready_i;
    assign axi_out_w_data_o        =   axi_req_out.w.data;
    assign axi_out_w_strb_o        =   axi_req_out.w.strb;
    assign axi_out_w_last_o        =   axi_req_out.w.last;
    assign axi_out_w_user_o        =   axi_req_out.w.user;
    assign axi_out_w_valid_o       =   axi_req_out.w_valid;
    assign axi_rsp_out.w_ready     =   axi_out_w_ready_i;
    assign axi_rsp_out.b.id        =   axi_out_b_id_i;
    assign axi_rsp_out.b.resp      =   axi_out_b_resp_i;
    assign axi_rsp_out.b.user      =   axi_out_b_user_i;
    assign axi_rsp_out.b_valid     =   axi_out_b_valid_i;
    assign axi_out_b_ready_o       =   axi_req_out.b_ready;
    assign axi_out_ar_id_o         =   axi_req_out.ar.id;
    assign axi_out_ar_addr_o       =   axi_req_out.ar.addr;
    assign axi_out_ar_len_o        =   axi_req_out.ar.len;
    assign axi_out_ar_size_o       =   axi_req_out.ar.size;
    assign axi_out_ar_burst_o      =   axi_req_out.ar.burst;
    assign axi_out_ar_lock_o       =   axi_req_out.ar.lock;
    assign axi_out_ar_cache_o      =   axi_req_out.ar.cache;
    assign axi_out_ar_prot_o       =   axi_req_out.ar.prot;
    assign axi_out_ar_qos_o        =   axi_req_out.ar.qos;
    assign axi_out_ar_region_o     =   axi_req_out.ar.region;
    assign axi_out_ar_user_o       =   axi_req_out.ar.user;
    assign axi_out_ar_valid_o      =   axi_req_out.ar_valid;
    assign axi_rsp_out.ar_ready    =   axi_out_ar_ready_i;
    assign axi_rsp_out.r.id        =   axi_out_r_id_i;
    assign axi_rsp_out.r.data      =   axi_out_r_data_i;
    assign axi_rsp_out.r.resp      =   axi_out_r_resp_i;
    assign axi_rsp_out.r.last      =   axi_out_r_last_i;
    assign axi_rsp_out.r.user      =   axi_out_r_user_i;
    assign axi_rsp_out.r_valid     =   axi_out_r_valid_i;
    assign axi_out_r_ready_o       =   axi_req_out.r_ready;

    // Regbus in
    assign reg_req.addr         = rbus_req_addr_i;
    assign reg_req.write        = rbus_req_write_i;
    assign reg_req.wdata        = rbus_req_wdata_i;
    assign reg_req.wstrb        = rbus_req_wstrb_i;
    assign reg_req.valid        = rbus_req_valid_i;
    assign rbus_rsp_rdata_o     = reg_rsp.rdata;
    assign rbus_rsp_ready_o     = reg_rsp.ready;
    assign rbus_rsp_error_o     = reg_rsp.error;

endmodule : serial_link_synth_wrapper

