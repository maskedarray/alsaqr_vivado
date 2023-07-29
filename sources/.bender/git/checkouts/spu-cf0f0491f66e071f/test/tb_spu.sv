`include "typedef.svh"
`include "assign.svh"

module tb_spu #(
    /// Number of AXI masters connected to the xbar. (Number of slave ports)
    parameter int unsigned TbNumMasters        = 32'd1,
    /// Number of AXI slaves connected to the xbar. (Number of master ports)
    parameter int unsigned TbNumSlaves         = 32'd1,
    /// Number of write transactions per master.
    parameter int unsigned TbNumWrites         = 32'd5,
    /// Number of read transactions per master.
    parameter int unsigned TbNumReads          = 32'd5,
    /// AXI4+ATOP ID width of the masters connected to the slave ports of the DUT.
    /// The ID width of the slaves is calculated depending on the xbar configuration.
    parameter int unsigned TbAxiIdWidthMasters = 32'd5,
    /// The used ID width of the DUT.
    /// Has to be `TbAxiIdWidthMasters >= TbAxiIdUsed`.
    parameter int unsigned TbAxiIdUsed         = 32'd3,
    /// Data width of the AXI channels.
    parameter int unsigned TbAxiDataWidth      = 32'd64,
    /// Pipeline stages in the xbar itself (between demux and mux).
    parameter int unsigned TbPipeline          = 32'd1,
    /// Enable ATOP generation
    parameter bit          TbEnAtop            = 1'b0,
    /// Enable exclusive accesses
    parameter bit TbEnExcl                     = 1'b0,   
    /// Restrict to only unique IDs         
    parameter bit TbUniqueIds                  = 1'b0       
);

    SPU_INTF #(
        .NUM_EVENT(5),
        .EVENT_INFO_BITS(0),
        .NUM_SOURCE(1)
    ) 
    spu_out ();

    // TB timing parameters
    localparam time CyclTime = 10ns;
    localparam time ApplTime =  2ns;
    localparam time TestTime =  8ns;

    // AXI configuration which is automatically derived.
    localparam int unsigned TbAxiIdWidthSlaves =  TbAxiIdWidthMasters + $clog2(TbNumMasters);
    localparam int unsigned TbAxiAddrWidth     =  32'd32;
    localparam int unsigned TbAxiStrbWidth     =  TbAxiDataWidth / 8;
    localparam int unsigned TbAxiUserWidth     =  5;

    localparam int unsigned NoAddrRules        =  TbNumSlaves;    

    typedef logic [TbAxiIdWidthMasters-1:0] id_mst_t;
    typedef logic [TbAxiIdWidthSlaves-1:0]  id_slv_t;
    typedef logic [TbAxiAddrWidth-1:0]      addr_t;
    typedef spu_pkg::xbar_rule_32_t         rule_t; // Has to be the same width as axi addr
    typedef logic [TbAxiDataWidth-1:0]      data_t;
    typedef logic [TbAxiStrbWidth-1:0]      strb_t;
    typedef logic [TbAxiUserWidth-1:0]      user_t;

    `AXI_TYPEDEF_AW_CHAN_T(aw_chan_mst_t, addr_t, id_mst_t, user_t)
    `AXI_TYPEDEF_AW_CHAN_T(aw_chan_slv_t, addr_t, id_slv_t, user_t)
    `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
    `AXI_TYPEDEF_B_CHAN_T(b_chan_mst_t, id_mst_t, user_t)
    `AXI_TYPEDEF_B_CHAN_T(b_chan_slv_t, id_slv_t, user_t)

    `AXI_TYPEDEF_AR_CHAN_T(ar_chan_mst_t, addr_t, id_mst_t, user_t)
    `AXI_TYPEDEF_AR_CHAN_T(ar_chan_slv_t, addr_t, id_slv_t, user_t)
    `AXI_TYPEDEF_R_CHAN_T(r_chan_mst_t, data_t, id_mst_t, user_t)
    `AXI_TYPEDEF_R_CHAN_T(r_chan_slv_t, data_t, id_slv_t, user_t)

    `AXI_TYPEDEF_REQ_T(mst_req_t, aw_chan_mst_t, w_chan_t, ar_chan_mst_t)
    `AXI_TYPEDEF_RESP_T(mst_resp_t, b_chan_mst_t, r_chan_mst_t)
    `AXI_TYPEDEF_REQ_T(slv_req_t, aw_chan_slv_t, w_chan_t, ar_chan_slv_t)
    `AXI_TYPEDEF_RESP_T(slv_resp_t, b_chan_slv_t, r_chan_slv_t)    

    // Each slave has its own address range:
    localparam rule_t [NoAddrRules-1:0] AddrMap = addr_map_gen();

    function rule_t [NoAddrRules-1:0] addr_map_gen ();
    for (int unsigned i = 0; i < NoAddrRules; i++) begin
        addr_map_gen[i] = rule_t'{
        idx:        unsigned'(i),
        start_addr:  i    * 32'h0000_2000,
        end_addr:   (i+1) * 32'h0000_2000,
        default:    '0
        };
    end
    endfunction

    typedef spu_test::axi_rand_master #(
        // AXI interface parameters
        .AW ( TbAxiAddrWidth          ),
        .DW ( TbAxiDataWidth          ),
        .IW ( TbAxiIdWidthMasters     ),
        .UW ( TbAxiUserWidth          ),
        // Stimuli application and test time
        .TA ( ApplTime                ),
        .TT ( TestTime                ),
        // Maximum number of read and write transactions in flight
        .MAX_READ_TXNS  ( 20          ),
        .MAX_WRITE_TXNS ( 20          ),
        .AXI_EXCLS      ( TbEnExcl    ),
        .AXI_ATOPS      ( TbEnAtop    ),
        .UNIQUE_IDS     ( TbUniqueIds )
    ) axi_rand_master_t;
    typedef spu_test::axi_rand_slave #(
        // AXI interface parameters
        .AW ( TbAxiAddrWidth     ),
        .DW ( TbAxiDataWidth     ),
        .IW ( TbAxiIdWidthSlaves ),
        .UW ( TbAxiUserWidth     ),
        // Stimuli application and test time
        .TA ( ApplTime           ),
        .TT ( TestTime           )
    ) axi_rand_slave_t;

    // -------------
    // DUT signals
    // -------------
    logic clk;
    // DUT signals
    logic rst_n;
    logic [TbNumMasters-1:0] end_of_sim;

    // master structs
    mst_req_t  [TbNumMasters-1:0] masters_req;
    mst_resp_t [TbNumMasters-1:0] masters_resp;

    // slave structs
    slv_req_t  [TbNumSlaves-1:0]  slaves_req;
    slv_resp_t [TbNumSlaves-1:0]  slaves_resp;

    // -------------------------------
    // AXI Interfaces
    // -------------------------------
    AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
    ) master [TbNumMasters-1:0] ();
    AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
    ) master_dv [TbNumMasters-1:0] (clk);
    for (genvar i = 0; i < TbNumMasters; i++) begin : gen_conn_dv_masters
    `AXI_ASSIGN (master[i], master_dv[i])
    `AXI_ASSIGN_TO_REQ(masters_req[i], master[i])
    `AXI_ASSIGN_TO_RESP(masters_resp[i], master[i])
    end

    AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth     ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth     ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthSlaves ),
    .AXI_USER_WIDTH ( TbAxiUserWidth     )
    ) slave [TbNumSlaves-1:0] ();
    AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth     ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth     ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthSlaves ),
    .AXI_USER_WIDTH ( TbAxiUserWidth     )
    ) slave_dv [TbNumSlaves-1:0](clk);
    for (genvar i = 0; i < TbNumSlaves; i++) begin : gen_conn_dv_slaves
    `AXI_ASSIGN(slave_dv[i], slave[i])
    `AXI_ASSIGN_TO_REQ(slaves_req[i], slave[i])
    `AXI_ASSIGN_TO_RESP(slaves_resp[i], slave[i])
    end
    // -------------------------------
    // AXI Rand Masters and Slaves
    // -------------------------------
    // Masters control simulation run time
    axi_rand_master_t axi_rand_master [TbNumMasters];
    for (genvar i = 0; i < TbNumMasters; i++) begin : gen_rand_master
    initial begin
        axi_rand_master[i] = new( master_dv[i] );
        end_of_sim[i] <= 1'b0;
        axi_rand_master[i].add_memory_region(AddrMap[0].start_addr,
                                        AddrMap[NoAddrRules-1].end_addr,
                                        spu_pkg::DEVICE_NONBUFFERABLE);
        axi_rand_master[i].reset();
        @(posedge rst_n);
        axi_rand_master[i].run(TbNumReads, TbNumWrites);
        end_of_sim[i] <= 1'b1;
    end
    end

    axi_rand_slave_t axi_rand_slave [TbNumSlaves];
    for (genvar i = 0; i < TbNumSlaves; i++) begin : gen_rand_slave
    initial begin
        axi_rand_slave[i] = new( slave_dv[i] );
        axi_rand_slave[i].reset();
        @(posedge rst_n);
        axi_rand_slave[i].run();
    end
    end

    //-----------------------------------
    // Clock generator
    //-----------------------------------
    clk_rst_gen #(
        .ClkPeriod    ( CyclTime ),
        .RstClkCycles ( 5        )
    ) i_clk_gen (
        .clk_o (clk),
        .rst_no(rst_n)
    );

    snooping_unit # (
        .AXI_ADDR_WIDTH ( TbAxiAddrWidth           ),
        .AXI_DATA_WIDTH ( TbAxiDataWidth           ),
        .AXI_ID_WIDTH   ( TbAxiIdWidthSlaves       ),
        .AXI_USER_WIDTH ( TbAxiUserWidth           )
    ) dut_spu (
        .clk_i               ( clk                  ),
        .rst_ni              ( rst_n                ),
        .spu_slv             ( master[0]            ),
        .spu_mst             ( slave[0]             ),
        .e_out               ( spu_out              )
    );

    // logger for master modules
    for (genvar i = 0; i < TbNumMasters; i++) begin : gen_master_logger
    axi_chan_logger #(
        .TestTime  ( TestTime      ), // Time after clock, where sampling happens
        .LoggerName( $sformatf("axi_logger_master_%0d", i)),
        .aw_chan_t ( aw_chan_mst_t ), // axi AW type
        .w_chan_t  (  w_chan_t     ), // axi  W type
        .b_chan_t  (  b_chan_mst_t ), // axi  B type
        .ar_chan_t ( ar_chan_mst_t ), // axi AR type
        .r_chan_t  (  r_chan_mst_t )  // axi  R type
    ) i_mst_channel_logger (
        .clk_i      ( clk         ),    // Clock
        .rst_ni     ( rst_n       ),    // Asynchronous reset active low, when `1'b0` no sampling
        .end_sim_i  ( &end_of_sim ),
        // AW channel
        .aw_chan_i  ( masters_req[i].aw        ),
        .aw_valid_i ( masters_req[i].aw_valid  ),
        .aw_ready_i ( masters_resp[i].aw_ready ),
        //  W channel
        .w_chan_i   ( masters_req[i].w         ),
        .w_valid_i  ( masters_req[i].w_valid   ),
        .w_ready_i  ( masters_resp[i].w_ready  ),
        //  B channel
        .b_chan_i   ( masters_resp[i].b        ),
        .b_valid_i  ( masters_resp[i].b_valid  ),
        .b_ready_i  ( masters_req[i].b_ready   ),
        // AR channel
        .ar_chan_i  ( masters_req[i].ar        ),
        .ar_valid_i ( masters_req[i].ar_valid  ),
        .ar_ready_i ( masters_resp[i].ar_ready ),
        //  R channel
        .r_chan_i   ( masters_resp[i].r        ),
        .r_valid_i  ( masters_resp[i].r_valid  ),
        .r_ready_i  ( masters_req[i].r_ready   )
    );
    end
    // logger for slave modules
    for (genvar i = 0; i < TbNumSlaves; i++) begin : gen_slave_logger
    axi_chan_logger #(
        .TestTime  ( TestTime      ), // Time after clock, where sampling happens
        .LoggerName( $sformatf("axi_logger_slave_%0d",i)),
        .aw_chan_t ( aw_chan_slv_t ), // axi AW type
        .w_chan_t  (  w_chan_t     ), // axi  W type
        .b_chan_t  (  b_chan_slv_t ), // axi  B type
        .ar_chan_t ( ar_chan_slv_t ), // axi AR type
        .r_chan_t  (  r_chan_slv_t )  // axi  R type
    ) i_slv_channel_logger (
        .clk_i      ( clk         ),    // Clock
        .rst_ni     ( rst_n       ),    // Asynchronous reset active low, when `1'b0` no sampling
        .end_sim_i  ( &end_of_sim ),
        // AW channel
        .aw_chan_i  ( slaves_req[i].aw        ),
        .aw_valid_i ( slaves_req[i].aw_valid  ),
        .aw_ready_i ( slaves_resp[i].aw_ready ),
        //  W channel
        .w_chan_i   ( slaves_req[i].w         ),
        .w_valid_i  ( slaves_req[i].w_valid   ),
        .w_ready_i  ( slaves_resp[i].w_ready  ),
        //  B channel
        .b_chan_i   ( slaves_resp[i].b        ),
        .b_valid_i  ( slaves_resp[i].b_valid  ),
        .b_ready_i  ( slaves_req[i].b_ready   ),
        // AR channel
        .ar_chan_i  ( slaves_req[i].ar        ),
        .ar_valid_i ( slaves_req[i].ar_valid  ),
        .ar_ready_i ( slaves_resp[i].ar_ready ),
        //  R channel
        .r_chan_i   ( slaves_resp[i].r        ),
        .r_valid_i  ( slaves_resp[i].r_valid  ),
        .r_ready_i  ( slaves_req[i].r_ready   )
    );
    end

endmodule : tb_spu