`timescale 1 ns/1 ps

`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"

module dut_if 
#(
  parameter int  AxiDataWidth    = -1,
  parameter int  AxiAddrWidth    = -1,
  parameter int  AxiIdWidth      = -1,
  parameter int  AxiUserWidth    = -1,
                                  
  parameter int  RegAw           = -1,
  parameter int  RegDw           = -1,
                 
  parameter int  NumChips        = -1,
  parameter int  NumPhys         = -1,
  parameter int  IsClockODelayed = -1,
  parameter int  NB_CH           = -1,
  parameter type axi_rule_t      = logic
)(
 input logic clk_i,
 input logic rst_ni,

 AXI_BUS_DV.Slave axi_slv_if,
 REG_BUS.in       reg_slv_if
);
  localparam int unsigned DRAM_DB_WIDTH = 16;
   
  typedef logic [AxiIdWidth-1:0] axi_id_t;
  typedef logic [AxiAddrWidth-1:0] axi_addr_t;
  typedef logic [AxiDataWidth-1:0] axi_data_t;
  typedef logic [AxiDataWidth/8-1:0] axi_strb_t;
  typedef logic [AxiUserWidth-1:0] axi_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(axi_aw_chan_t, axi_addr_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T(axi_w_chan_t, axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(axi_b_chan_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(axi_ar_chan_t, axi_addr_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(axi_r_chan_t, axi_data_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_REQ_T(axi_req_t, axi_aw_chan_t, axi_w_chan_t, axi_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_resp_t, axi_b_chan_t, axi_r_chan_t)

   axi_req_t axi_req;
   axi_resp_t axi_resp;
     
  `AXI_ASSIGN_TO_REQ(axi_req, axi_slv_if)
  `AXI_ASSIGN_FROM_RESP(axi_slv_if, axi_resp)
   
  typedef logic [RegAw-1:0]   reg_addr_t;
  typedef logic [RegDw-1:0]   reg_data_t;
  typedef logic [RegDw/8-1:0] reg_strb_t;

  `REG_BUS_TYPEDEF_REQ(reg_req_t, reg_addr_t, reg_data_t, reg_strb_t)
  `REG_BUS_TYPEDEF_RSP(reg_rsp_t, reg_data_t)

  reg_req_t reg_req;
  reg_rsp_t reg_resp;

  `REG_BUS_ASSIGN_TO_REQ(reg_req,reg_slv_if)
  `REG_BUS_ASSIGN_FROM_RSP(reg_slv_if,reg_resp)   
   

    wire  [NumPhys-1:0][1:0] hyper_cs_n_wire;
    wire  [NumPhys-1:0]      hyper_ck_wire;
    wire  [NumPhys-1:0]      hyper_ck_n_wire;
    wire  [NumPhys-1:0]      hyper_rwds_o;
    wire  [NumPhys-1:0]      s_hyper_rwds_i;
    wire  [NumPhys-1:0]      hyper_rwds_i;
    wire  [NumPhys-1:0]      hyper_rwds_oe;
    wire  [NumPhys-1:0]      hyper_rwds_wire;
    wire  [NumPhys-1:0]      s_hyper_rwds_wire;
    wire  [NumPhys-1:0][7:0] hyper_dq_i;
    wire  [NumPhys-1:0][7:0] hyper_dq_o;
    wire  [NumPhys-1:0]      hyper_dq_oe;
    wire  [NumPhys-1:0][7:0] hyper_dq_wire;
    wire  [NumPhys-1:0]      hyper_reset_n_wire;
             
    // DUT
    hyperbus #(
        .NumChips       ( NumChips      ),
        .NumPhys        ( NumPhys       ),
        .AxiAddrWidth   ( AxiAddrWidth  ),
        .AxiDataWidth   ( AxiDataWidth  ),
        .AxiIdWidth     ( AxiIdWidth    ),
        .AxiUserWidth   ( AxiUserWidth  ),
        .axi_req_t      ( axi_req_t     ),
        .axi_rsp_t      ( axi_resp_t    ),
        .axi_aw_chan_t  ( axi_aw_chan_t ),
        .axi_w_chan_t   ( axi_w_chan_t  ),
        .axi_b_chan_t   ( axi_b_chan_t  ),
        .axi_ar_chan_t  ( axi_ar_chan_t ),
        .axi_r_chan_t   ( axi_r_chan_t  ),
        .RegAddrWidth   ( RegAw         ),
        .RegDataWidth   ( RegDw         ),
        .reg_req_t      ( reg_req_t     ),
        .reg_rsp_t      ( reg_rsp_t     ),
        .IsClockODelayed( 0             ),
        .NB_CH          ( NB_CH         ),
        .axi_rule_t     ( axi_rule_t    )
    ) i_dut (
        .clk_phy_i              ( clk_i              ),
        .rst_phy_ni             ( rst_ni             ),
        .clk_sys_i              ( clk_i              ),
        .rst_sys_ni             ( rst_ni             ),
        .test_mode_i            ( 1'b0               ),
        .axi_req_i              ( axi_req            ),
        .axi_rsp_o              ( axi_resp           ),
        .reg_req_i              ( reg_req            ),
        .reg_rsp_o              ( reg_resp           ),

        .data_rx_o              (                    ),
        .data_rx_valid_o        (                    ),
        .data_rx_ready_i        ( 1'b1               ),
        
        .data_tx_i              ( '0                 ),
        .data_tx_valid_i        ( '0                 ),
        .data_tx_ready_o        (                    ),
        .data_tx_gnt_i          ( '0                 ),
        .data_tx_req_o          (                    ),
        
        .cfg_data_i             ( '0                 ),
        .cfg_addr_i             ( '0                 ),
        .cfg_valid_i            ( '0                 ),
        .cfg_rwn_i              ( '0                 ),
        .cfg_data_o             (                    ),
        .cfg_ready_o            (                    ),
        
        .cfg_rx_startaddr_o     (                    ),
        .cfg_rx_size_o          (                    ),
        .data_rx_datasize_o     (                    ),
        .cfg_rx_continuous_o    (                    ),
        .cfg_rx_en_o            (                    ),
        .cfg_rx_clr_o           (                    ),
        .cfg_rx_en_i            ( '0                 ),
        .cfg_rx_pending_i       ( '0                 ),
        .cfg_rx_curr_addr_i     ( '0                 ),
        .cfg_rx_bytes_left_i    ( '0                 ),
        
        .cfg_tx_startaddr_o     (                    ),
        .cfg_tx_size_o          (                    ),
        .data_tx_datasize_o     (                    ),
        .cfg_tx_continuous_o    (                    ),
        .cfg_tx_en_o            (                    ),
        .cfg_tx_clr_o           (                    ),
        .cfg_tx_en_i            ( '0                 ),
        .cfg_tx_pending_i       ( '0                 ),
        .cfg_tx_curr_addr_i     ( '0                 ),
        .cfg_tx_bytes_left_i    ( '0                 ),

        .evt_eot_hyper_o        (                    ),
             
        .pad_hyper_csn          ( hyper_cs_n_wire    ),
        .pad_hyper_ck           ( hyper_ck_wire      ),
        .pad_hyper_ckn          ( hyper_ck_n_wire    ),
        .pad_hyper_rwds         ( hyper_rwds_wire    ),
        .pad_hyper_reset        ( hyper_reset_n_wire ),
        .pad_hyper_dq           ( hyper_dq_wire      )

    );

    
    generate
       for (genvar i=0; i<NumPhys; i++) begin : hyperrams

          s27ks0641 #(
            /*.mem_file_name ( "s27ks0641.mem"    ),*/
            .TimingModel   ( "S27KS0641DPBHI020"    )
          ) i_s27ks0641 (
            .DQ7           ( hyper_dq_wire[i][7]      ),
            .DQ6           ( hyper_dq_wire[i][6]      ),
            .DQ5           ( hyper_dq_wire[i][5]      ),
            .DQ4           ( hyper_dq_wire[i][4]      ),
            .DQ3           ( hyper_dq_wire[i][3]      ),
            .DQ2           ( hyper_dq_wire[i][2]      ),
            .DQ1           ( hyper_dq_wire[i][1]      ),
            .DQ0           ( hyper_dq_wire[i][0]      ),
            .RWDS          ( hyper_rwds_wire[i]       ),
            .CSNeg         ( hyper_cs_n_wire[i][0]    ),
            .CK            ( hyper_ck_wire[i]         ),
            .CKNeg         ( hyper_ck_n_wire[i]       ),
            .RESETNeg      ( hyper_reset_n_wire[i]    )
          );

       end // block: hyperrams
    endgenerate
   
    generate
       for (genvar p=0; p<NumPhys; p++) begin : sdf_annotation
         initial begin
             `ifndef TARGET_POST_SYNTH_SIM
             automatic string sdf_file_path = "./models/s27ks0641/s27ks0641.sdf";
             `else
             automatic string sdf_file_path = "../../models/s27ks0641/s27ks0641.sdf";
             `endif 
             $sdf_annotate(sdf_file_path, hyperrams[p].i_s27ks0641);
             $display("NumPhys:%d",NumPhys);
         end
       end
    endgenerate

endmodule
