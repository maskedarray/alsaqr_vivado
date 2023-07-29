// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Date: 19.04.2017
// Description: Load Store Unit, handles address calculation and memory interface signals


module load_store_unit import ariane_pkg::*; #(
    parameter int unsigned ASID_WIDTH = 1,
    parameter int unsigned VMID_WIDTH = 1,
    parameter ariane_pkg::ariane_cfg_t ArianeCfg = ariane_pkg::ArianeDefaultConfig
)(
    input  logic                     clk_i,
    input  logic                     rst_ni,
    input  logic                     flush_i,
    output logic                     no_st_pending_o,
    input  logic                     amo_valid_commit_i,
    input  riscv::xlen_t             tinst_i,

    input  fu_data_t                 fu_data_i,
    output logic                     lsu_ready_o,              // FU is ready e.g. not busy
    input  logic                     lsu_valid_i,              // Input is valid

    output logic [TRANS_ID_BITS-1:0] load_trans_id_o,          // ID of scoreboard entry at which to write back
    output riscv::xlen_t             load_result_o,
    output logic                     load_valid_o,
    output exception_t               load_exception_o,         // to WB, signal exception status LD exception

    output logic [TRANS_ID_BITS-1:0] store_trans_id_o,         // ID of scoreboard entry at which to write back
    output riscv::xlen_t             store_result_o,
    output logic                     store_valid_o,
    output exception_t               store_exception_o,        // to WB, signal exception status ST exception

    input  logic                     commit_i,                 // commit the pending store
    output logic                     commit_ready_o,           // commit queue is ready to accept another commit request
    input  logic [TRANS_ID_BITS-1:0] commit_tran_id_i,

    input  logic                     enable_translation_i,     // enable virtual memory translation
    input  logic                     enable_g_translation_i,   // enable G-Stage translation
    input  logic                     en_ld_st_translation_i,   // enable virtual memory translation for load/stores
    input  logic                     en_ld_st_g_translation_i, // enable G-stage translation for load/stores

    // icache translation requests
    input  icache_areq_o_t           icache_areq_i,
    output icache_areq_i_t           icache_areq_o,

    input  riscv::priv_lvl_t         priv_lvl_i,               // From CSR register file
    input logic                      v_i,                      // From CSR register file
    input  riscv::priv_lvl_t         ld_st_priv_lvl_i,         // From CSR register file
    input  logic                     ld_st_v_i,                // From CSR register file
    output logic                     csr_hs_ld_st_inst_o,
    input  logic                     sum_i,                    // From CSR register file
    input  logic                     vs_sum_i,                    // From CSR register file
    input  logic                     mxr_i,                    // From CSR register file
    input  logic                     vmxr_i,                   // From CSR register file
    input  logic [riscv::PPNW-1:0]   satp_ppn_i,               // From CSR register file
    input  logic [ASID_WIDTH-1:0]    asid_i,                   // From CSR register file
    input  logic [riscv::PPNW-1:0]   vsatp_ppn_i,              // From CSR register file
    input  logic [ASID_WIDTH-1:0]    vs_asid_i,                // From CSR register file
    input  logic [ASID_WIDTH-1:0]    asid_to_be_flushed_i,
    input  logic [riscv::PPNW-1:0]   hgatp_ppn_i,              // From CSR register file
    input  logic [VMID_WIDTH-1:0]    vmid_i,                   // From CSR register file
    input  logic [VMID_WIDTH-1:0]    vmid_to_be_flushed_i,
    input  logic [riscv::VLEN-1:0]   vaddr_to_be_flushed_i,
    input  logic [riscv::GPLEN-1:0]  gpaddr_to_be_flushed_i,
    input  logic                     flush_tlb_i,
    input  logic                     flush_tlb_vvma_i,
    input  logic                     flush_tlb_gvma_i,
    // Performance counters
    output logic                     itlb_miss_o,
    output logic                     dtlb_miss_o,

    // interface to dcache
    input  dcache_req_o_t [2:0]      dcache_req_ports_i,
    output dcache_req_i_t [2:0]      dcache_req_ports_o,
    input  logic                     dcache_wbuffer_empty_i,
    input  logic                     dcache_wbuffer_not_ni_i,
    // AMO interface
    output amo_req_t                 amo_req_o,
    input  amo_resp_t                amo_resp_i,
    // PMP
    input  riscv::pmpcfg_t [15:0]    pmpcfg_i,
    input  logic [15:0][riscv::PLEN-3:0] pmpaddr_i
);
    // data is misaligned
    logic data_misaligned;
    // --------------------------------------
    // 1st register stage - (stall registers)
    // --------------------------------------
    // those are the signals which are always correct
    // e.g.: they keep the value in the stall case
    lsu_ctrl_t lsu_ctrl;

    logic      pop_st;
    logic      pop_ld;

    // ------------------------------
    // Address Generation Unit (AGU)
    // ------------------------------
    // virtual address as calculated by the AGU in the first cycle
    logic [riscv::VLEN-1:0]   vaddr_i;
    riscv::xlen_t             vaddr_xlen;
    logic                     overflow, g_overflow;
    logic [7:0]               be_i;

    assign vaddr_xlen = $unsigned($signed(fu_data_i.imm) + $signed(fu_data_i.operand_a));
    assign vaddr_i = vaddr_xlen[riscv::VLEN-1:0];
    // we work with SV39 or SV32, so if VM is enabled, check that all bits [XLEN-1:38] or [XLEN-1:31] are equal
    assign overflow = !((&vaddr_xlen[riscv::XLEN-1:riscv::SV-1]) == 1'b1 || (|vaddr_xlen[riscv::XLEN-1:riscv::SV-1]) == 1'b0);
    assign g_overflow = !((|vaddr_xlen[riscv::XLEN-1:riscv::SVX]) == 1'b0);

    logic                     st_valid_i;
    logic                     ld_valid_i;
    logic                     ld_translation_req;
    logic                     st_translation_req;
    logic [riscv::VLEN-1:0]   ld_vaddr;
    logic [riscv::XLEN-1:0]   ld_tinst;
    logic                     ld_hs_ld_st_inst;
    logic                     ld_hlvx_inst;
    logic [riscv::VLEN-1:0]   st_vaddr;
    logic [riscv::XLEN-1:0]   st_tinst;
    logic                     st_hs_ld_st_inst;
    logic                     st_hlvx_inst;
    logic                     translation_req;
    logic                     translation_valid;
    logic [riscv::VLEN-1:0]   mmu_vaddr;
    logic [riscv::XLEN-1:0]   mmu_tinst;
    logic [riscv::PLEN-1:0]   mmu_paddr;
    logic                     mmu_hs_ld_st_inst;
    logic                     mmu_hlvx_inst;
    exception_t               mmu_exception;
    logic                     dtlb_hit;
    logic [riscv::PPNW-1:0]   dtlb_ppn;

    logic                     ld_valid;
    logic [TRANS_ID_BITS-1:0] ld_trans_id;
    riscv::xlen_t             ld_result;
    logic                     st_valid;
    logic [TRANS_ID_BITS-1:0] st_trans_id;
    riscv::xlen_t             st_result;

    logic [11:0]              page_offset;
    logic                     page_offset_matches;

    exception_t               misaligned_exception;
    exception_t               ld_ex;
    exception_t               st_ex;

    logic                     hs_ld_st_inst;
    logic                     hlvx_inst;
    // -------------------
    // MMU e.g.: TLBs/PTW
    // -------------------
    if (MMU_PRESENT && (riscv::XLEN == 64)) begin : gen_mmu_sv39
        mmu #(
            .INSTR_TLB_ENTRIES      ( 16                     ),
            .DATA_TLB_ENTRIES       ( 16                     ),
            .ASID_WIDTH             ( ASID_WIDTH             ),
            .VMID_WIDTH             ( VMID_WIDTH             ),
            .ArianeCfg              ( ArianeCfg              )
        ) i_cva6_mmu (
            // misaligned bypass
            .misaligned_ex_i        ( misaligned_exception   ),
            .lsu_is_store_i         ( st_translation_req     ),
            .lsu_req_i              ( translation_req        ),
            .lsu_vaddr_i            ( mmu_vaddr              ),
            .lsu_tinst_i            ( mmu_tinst              ),
            .lsu_valid_o            ( translation_valid      ),
            .lsu_paddr_o            ( mmu_paddr              ),
            .lsu_exception_o        ( mmu_exception          ),
            .lsu_dtlb_hit_o         ( dtlb_hit               ), // send in the same cycle as the request
            .lsu_dtlb_ppn_o         ( dtlb_ppn               ), // send in the same cycle as the request
            // connecting PTW to D$ IF
            .req_port_i             ( dcache_req_ports_i [0] ),
            .req_port_o             ( dcache_req_ports_o [0] ),
            // icache address translation requests
            .icache_areq_i          ( icache_areq_i          ),
            .asid_to_be_flushed_i,
            .vmid_to_be_flushed_i,
            .vaddr_to_be_flushed_i,
            .gpaddr_to_be_flushed_i,
            .icache_areq_o          ( icache_areq_o          ),
            .pmpcfg_i,
            .pmpaddr_i,
            // Hypervisor load/store signals
            .hlvx_inst_i            ( mmu_hlvx_inst          ),
            .hs_ld_st_inst_i        ( mmu_hs_ld_st_inst      ),
            .*
        );
    end else if (MMU_PRESENT && (riscv::XLEN == 32)) begin : gen_mmu_sv32
        cva6_mmu_sv32 #(
            .INSTR_TLB_ENTRIES      ( 16                     ),
            .DATA_TLB_ENTRIES       ( 16                     ),
            .ASID_WIDTH             ( ASID_WIDTH             ),
            .ArianeCfg              ( ArianeCfg              )
        ) i_cva6_mmu (
            // misaligned bypass
            .misaligned_ex_i        ( misaligned_exception   ),
            .lsu_is_store_i         ( st_translation_req     ),
            .lsu_req_i              ( translation_req        ),
            .lsu_vaddr_i            ( mmu_vaddr              ),
            .lsu_valid_o            ( translation_valid      ),
            .lsu_paddr_o            ( mmu_paddr              ),
            .lsu_exception_o        ( mmu_exception          ),
            .lsu_dtlb_hit_o         ( dtlb_hit               ), // send in the same cycle as the request
            .lsu_dtlb_ppn_o         ( dtlb_ppn               ), // send in the same cycle as the request
            // connecting PTW to D$ IF
            .req_port_i             ( dcache_req_ports_i [0] ),
            .req_port_o             ( dcache_req_ports_o [0] ),
            // icache address translation requests
            .icache_areq_i          ( icache_areq_i          ),
            .asid_to_be_flushed_i,
            .vaddr_to_be_flushed_i,
            .icache_areq_o          ( icache_areq_o          ),
            .pmpcfg_i,
            .pmpaddr_i,
            .*
        );
    end else begin : gen_no_mmu
        assign  icache_areq_o.fetch_valid  = icache_areq_i.fetch_req;
        assign  icache_areq_o.fetch_paddr  = icache_areq_i.fetch_vaddr[riscv::PLEN-1:0];
        assign  icache_areq_o.fetch_exception      = '0;

        assign dcache_req_ports_o[0].address_index = '0;
        assign dcache_req_ports_o[0].address_tag   = '0;
        assign dcache_req_ports_o[0].data_wdata    = 64'b0;
        assign dcache_req_ports_o[0].data_req      = 1'b0;
        assign dcache_req_ports_o[0].data_be       = 8'hFF;
        assign dcache_req_ports_o[0].data_size     = 2'b11;
        assign dcache_req_ports_o[0].data_we       = 1'b0;
        assign dcache_req_ports_o[0].kill_req      = '0;
        assign dcache_req_ports_o[0].tag_valid     = 1'b0;

        assign itlb_miss_o = 1'b0;
        assign dtlb_miss_o = 1'b0;
        assign dtlb_ppn    = mmu_vaddr[riscv::PLEN-1:12];
        assign dtlb_hit    = 1'b1;

        assign mmu_exception = '0;

        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (~rst_ni) begin
                mmu_paddr         <= '0;
                translation_valid <= '0;
            end else begin
                mmu_paddr         <=  mmu_vaddr[riscv::PLEN-1:0];
                translation_valid <= translation_req;
            end
        end
    end


    logic store_buffer_empty;
    // ------------------
    // Store Unit
    // ------------------
    store_unit i_store_unit (
        .clk_i,
        .rst_ni,
        .flush_i,
        .no_st_pending_o,
        .store_buffer_empty_o  ( store_buffer_empty   ),

        .valid_i               ( st_valid_i           ),
        .lsu_ctrl_i            ( lsu_ctrl             ),
        .pop_st_o              ( pop_st               ),
        .commit_i,
        .commit_ready_o,
        .amo_valid_commit_i,

        .valid_o               ( st_valid             ),
        .trans_id_o            ( st_trans_id          ),
        .result_o              ( st_result            ),
        .ex_o                  ( st_ex                ),
        // MMU port
        .translation_req_o     ( st_translation_req   ),
        .vaddr_o               ( st_vaddr             ),
        .tinst_o               ( st_tinst             ),
        .hs_ld_st_inst_o       ( st_hs_ld_st_inst     ),
        .hlvx_inst_o           ( st_hlvx_inst         ),
        .paddr_i               ( mmu_paddr            ),
        .ex_i                  ( mmu_exception        ),
        .dtlb_hit_i            ( dtlb_hit             ),
        // Load Unit
        .page_offset_i         ( page_offset          ),
        .page_offset_matches_o ( page_offset_matches  ),
        // AMOs
        .amo_req_o,
        .amo_resp_i,
        // to memory arbiter
        .req_port_i             ( dcache_req_ports_i [2] ),
        .req_port_o             ( dcache_req_ports_o [2] )
    );

    // ------------------
    // Load Unit
    // ------------------
    load_unit #(
        .ArianeCfg ( ArianeCfg )
    ) i_load_unit (
        .valid_i               ( ld_valid_i           ),
        .lsu_ctrl_i            ( lsu_ctrl             ),
        .pop_ld_o              ( pop_ld               ),

        .valid_o               ( ld_valid             ),
        .trans_id_o            ( ld_trans_id          ),
        .result_o              ( ld_result            ),
        .ex_o                  ( ld_ex                ),
        // MMU port
        .translation_req_o     ( ld_translation_req   ),
        .vaddr_o               ( ld_vaddr             ),
        .tinst_o               ( ld_tinst             ),
        .hs_ld_st_inst_o       ( ld_hs_ld_st_inst     ),
        .hlvx_inst_o           ( ld_hlvx_inst         ),
        .paddr_i               ( mmu_paddr            ),
        .ex_i                  ( mmu_exception        ),
        .dtlb_hit_i            ( dtlb_hit             ),
        .dtlb_ppn_i            ( dtlb_ppn             ),
        // to store unit
        .page_offset_o         ( page_offset          ),
        .page_offset_matches_i ( page_offset_matches  ),
        .store_buffer_empty_i  ( store_buffer_empty   ),
        // to memory arbiter
        .req_port_i            ( dcache_req_ports_i [1] ),
        .req_port_o            ( dcache_req_ports_o [1] ),
        .dcache_wbuffer_not_ni_i,
        .commit_tran_id_i,
        .*
    );

    // ----------------------------
    // Output Pipeline Register
    // ----------------------------
    shift_reg #(
        .dtype ( logic[$bits(ld_valid) + $bits(ld_trans_id) + $bits(ld_result) + $bits(ld_ex) - 1: 0]),
        .Depth ( NR_LOAD_PIPE_REGS )
    ) i_pipe_reg_load (
        .clk_i,
        .rst_ni,
        .d_i ( {ld_valid, ld_trans_id, ld_result, ld_ex} ),
        .d_o ( {load_valid_o, load_trans_id_o, load_result_o, load_exception_o} )
    );

    shift_reg #(
        .dtype ( logic[$bits(st_valid) + $bits(st_trans_id) + $bits(st_result) + $bits(st_ex) - 1: 0]),
        .Depth ( NR_STORE_PIPE_REGS )
    ) i_pipe_reg_store (
        .clk_i,
        .rst_ni,
        .d_i ( {st_valid, st_trans_id, st_result, st_ex} ),
        .d_o ( {store_valid_o, store_trans_id_o, store_result_o, store_exception_o} )
    );

    // determine whether this is a load or store
    always_comb begin : which_op

        ld_valid_i = 1'b0;
        st_valid_i = 1'b0;

        translation_req      = 1'b0;
        mmu_vaddr            = {riscv::VLEN{1'b0}};
        mmu_tinst            = {riscv::XLEN{1'b0}};
        mmu_hs_ld_st_inst    = 1'b0;
        mmu_hlvx_inst        = 1'b0;

        // check the operator to activate the right functional unit accordingly
        unique case (lsu_ctrl.fu)
            // all loads go here
            LOAD:  begin
                ld_valid_i           = lsu_ctrl.valid;
                translation_req      = ld_translation_req;
                mmu_vaddr            = ld_vaddr;
                mmu_tinst            = ld_tinst;
                mmu_hs_ld_st_inst    = ld_hs_ld_st_inst;
                mmu_hlvx_inst        = ld_hlvx_inst;
            end
            // all stores go here
            STORE: begin
                st_valid_i           = lsu_ctrl.valid;
                translation_req      = st_translation_req;
                mmu_vaddr            = st_vaddr;
                mmu_tinst            = st_tinst;
                mmu_hs_ld_st_inst    = st_hs_ld_st_inst;
                mmu_hlvx_inst        = st_hlvx_inst;
            end
            // not relevant for the LSU
            default: ;
        endcase
    end

    // ------------------------
    // Hypervisor Load/Store
    // ------------------------
    // determine whether this is a hypervisor load or store
    always_comb begin : hyp_ld_st
        // check the operator to activate the right functional unit accordingly
        hs_ld_st_inst = 1'b0;
        hlvx_inst     = 1'b0;
        case (lsu_ctrl.operator)
            // all loads go here
            HLV_B, HLV_BU, HLV_H, HLV_HU,
            HLV_W, HSV_B, HSV_H, HSV_W,
            HLV_WU, HLV_D, HSV_D: begin
                    hs_ld_st_inst = 1'b1;
            end
            HLVX_WU, HLVX_HU: begin
                    hs_ld_st_inst = 1'b1;
                    hlvx_inst     = 1'b1;
            end
            default:;
        endcase
    end

    // ---------------
    // Byte Enable
    // ---------------
    // we can generate the byte enable from the virtual address since the last
    // 12 bit are the same anyway
    // and we can always generate the byte enable from the address at hand
    assign be_i = be_gen(vaddr_i[2:0], extract_transfer_size(fu_data_i.operator));

    // ------------------------
    // Misaligned Exception
    // ------------------------
    // we can detect a misaligned exception immediately
    // the misaligned exception is passed to the functional unit via the MMU, which in case
    // can augment the exception if other memory related exceptions like a page fault or access errors
    always_comb begin : data_misaligned_detection
        misaligned_exception = {
            {riscv::XLEN{1'b0}},
            {riscv::XLEN{1'b0}},
            {riscv::XLEN{1'b0}},
            {riscv::XLEN{1'b0}},
            1'b0,
            1'b0
        };
        data_misaligned = 1'b0;

        if (lsu_ctrl.valid) begin
            case (lsu_ctrl.operator)
                // double word
                LD, SD, FLD, FSD,
                AMO_LRD, AMO_SCD,
                AMO_SWAPD, AMO_ADDD, AMO_ANDD, AMO_ORD,
                AMO_XORD, AMO_MAXD, AMO_MAXDU, AMO_MIND,
                AMO_MINDU, HLV_D, HSV_D: begin
                    if (lsu_ctrl.vaddr[2:0] != 3'b000) begin
                        data_misaligned = 1'b1;
                    end
                end
                // word
                LW, LWU, SW, FLW, FSW,
                AMO_LRW, AMO_SCW,
                AMO_SWAPW, AMO_ADDW, AMO_ANDW, AMO_ORW,
                AMO_XORW, AMO_MAXW, AMO_MAXWU, AMO_MINW,
                AMO_MINWU, HLV_W, HLV_WU, HLVX_WU, HSV_W: begin
                    if (lsu_ctrl.vaddr[1:0] != 2'b00) begin
                        data_misaligned = 1'b1;
                    end
                end
                // half word
                LH, LHU, SH, FLH, FSH, HLV_H, HLV_HU, HLVX_HU, HSV_H: begin
                    if (lsu_ctrl.vaddr[0] != 1'b0) begin
                        data_misaligned = 1'b1;
                    end
                end
                // byte -> is always aligned
                default:;
            endcase
        end

        if (data_misaligned) begin

            if (lsu_ctrl.fu == LOAD) begin
                misaligned_exception = {
                    riscv::LD_ADDR_MISALIGNED,
                    {{riscv::XLEN-riscv::VLEN{1'b0}},lsu_ctrl.vaddr},
                    {riscv::XLEN{1'b0}},
                    lsu_ctrl.tinst,
                    1'b0,
                    1'b1
                };

            end else if (lsu_ctrl.fu == STORE) begin
                misaligned_exception = {
                    riscv::ST_ADDR_MISALIGNED,
                    {{riscv::XLEN-riscv::VLEN{1'b0}},lsu_ctrl.vaddr},
                    {riscv::XLEN{1'b0}},
                    lsu_ctrl.tinst,
                    1'b0,
                    1'b1
                };
            end
        end

        if (en_ld_st_translation_i && lsu_ctrl.overflow) begin

            if (lsu_ctrl.fu == LOAD) begin
                misaligned_exception = {
                    riscv::LD_ACCESS_FAULT,
                    {{riscv::XLEN-riscv::VLEN{1'b0}},lsu_ctrl.vaddr},
                    {riscv::XLEN{1'b0}},
                    lsu_ctrl.tinst,
                    ld_st_v_i,
                    1'b1
                };

            end else if (lsu_ctrl.fu == STORE) begin
                misaligned_exception = {
                    riscv::ST_ACCESS_FAULT,
                    {{riscv::XLEN-riscv::VLEN{1'b0}},lsu_ctrl.vaddr},
                    {riscv::XLEN{1'b0}},
                    lsu_ctrl.tinst,
                    ld_st_v_i,
                    1'b1
                };
            end
        end

        if (en_ld_st_g_translation_i && !en_ld_st_translation_i && lsu_ctrl.g_overflow) begin

            if (lsu_ctrl.fu == LOAD) begin
                misaligned_exception = {
                    riscv::LOAD_GUEST_PAGE_FAULT,
                    {{riscv::XLEN-riscv::VLEN{1'b0}},lsu_ctrl.vaddr},
                    {riscv::XLEN{1'b0}},
                    lsu_ctrl.tinst,
                    ld_st_v_i,
                    1'b1
                };

            end else if (lsu_ctrl.fu == STORE) begin
                misaligned_exception = {
                    riscv::STORE_GUEST_PAGE_FAULT,
                    {{riscv::XLEN-riscv::VLEN{1'b0}},lsu_ctrl.vaddr},
                    {riscv::XLEN{1'b0}},
                    lsu_ctrl.tinst,
                    ld_st_v_i,
                    1'b1
                };
            end
        end
    end

    // ------------------
    // LSU Control
    // ------------------
    // new data arrives here
    lsu_ctrl_t lsu_req_i;

    assign lsu_req_i = {lsu_valid_i, vaddr_i, tinst_i, hs_ld_st_inst, hlvx_inst, overflow, g_overflow, {{64-riscv::XLEN{1'b0}}, fu_data_i.operand_b}, be_i, fu_data_i.fu, fu_data_i.operator, fu_data_i.trans_id};

    lsu_bypass lsu_bypass_i (
        .lsu_req_i          ( lsu_req_i   ),
        .lsu_req_valid_i    ( lsu_valid_i ),
        .pop_ld_i           ( pop_ld      ),
        .pop_st_i           ( pop_st      ),

        .lsu_ctrl_o         ( lsu_ctrl    ),
        .ready_o            ( lsu_ready_o ),
        .*
    );

endmodule

// ------------------
// LSU Control
// ------------------
// The LSU consists of two independent block which share a common address translation block.
// The one block is the load unit, the other one is the store unit. They will signal their readiness
// with separate signals. If they are not ready the LSU control should keep the last applied signals stable.
// Furthermore it can be the case that another request for one of the two store units arrives in which case
// the LSU control should sample it and store it for later application to the units. It does so, by storing it in a
// two element FIFO. This is necessary as we only know very late in the cycle whether the load/store will succeed (address check,
// TLB hit mainly). So we better unconditionally allow another request to arrive and store this request in case we need to.
module lsu_bypass import ariane_pkg::*; (
    input  logic      clk_i,
    input  logic      rst_ni,
    input  logic      flush_i,

    input  lsu_ctrl_t lsu_req_i,
    input  logic      lsu_req_valid_i,
    input  logic      pop_ld_i,
    input  logic      pop_st_i,

    output lsu_ctrl_t lsu_ctrl_o,
    output logic      ready_o
    );

    lsu_ctrl_t [1:0] mem_n, mem_q;
    logic read_pointer_n, read_pointer_q;
    logic write_pointer_n, write_pointer_q;
    logic [1:0] status_cnt_n, status_cnt_q;

    logic  empty;
    assign empty = (status_cnt_q == 0);
    assign ready_o = empty;

    always_comb begin
        automatic logic [1:0] status_cnt;
        automatic logic write_pointer;
        automatic logic read_pointer;

        status_cnt = status_cnt_q;
        write_pointer = write_pointer_q;
        read_pointer = read_pointer_q;

        mem_n = mem_q;
        // we've got a valid LSU request
        if (lsu_req_valid_i) begin
            mem_n[write_pointer_q] = lsu_req_i;
            write_pointer++;
            status_cnt++;
        end

        if (pop_ld_i) begin
            // invalidate the result
            mem_n[read_pointer_q].valid = 1'b0;
            read_pointer++;
            status_cnt--;
        end

        if (pop_st_i) begin
            // invalidate the result
            mem_n[read_pointer_q].valid = 1'b0;
            read_pointer++;
            status_cnt--;
        end

        if (pop_st_i && pop_ld_i)
            mem_n = '0;

        if (flush_i) begin
            status_cnt = '0;
            write_pointer = '0;
            read_pointer = '0;
            mem_n = '0;
        end
        // default assignments
        read_pointer_n  = read_pointer;
        write_pointer_n = write_pointer;
        status_cnt_n    = status_cnt;
    end

    // output assignment
    always_comb begin : output_assignments
        if (empty) begin
            lsu_ctrl_o = lsu_req_i;
        end else begin
            lsu_ctrl_o = mem_q[read_pointer_q];
        end
    end

    // registers
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            mem_q           <= '0;
            status_cnt_q    <= '0;
            write_pointer_q <= '0;
            read_pointer_q  <= '0;
        end else begin
            mem_q           <= mem_n;
            status_cnt_q    <= status_cnt_n;
            write_pointer_q <= write_pointer_n;
            read_pointer_q  <= read_pointer_n;
        end
    end
endmodule