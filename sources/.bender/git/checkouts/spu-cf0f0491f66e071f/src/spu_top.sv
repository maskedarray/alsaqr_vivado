interface SPU_INTF #(    
    parameter int unsigned NUM_EVENT = 0,
    parameter int unsigned EVENT_INFO_BITS = 0,
    parameter int unsigned NUM_SOURCE   = 0
);
    localparam EVENT_ID_BITS = $clog2(NUM_EVENT+1);
    localparam SOURCE_ID_BITS = $clog2(NUM_SOURCE);

    typedef logic [EVENT_ID_BITS-1:0]       event_id_t;
    typedef logic [EVENT_INFO_BITS-1:0]     event_info_t;
    typedef logic [SOURCE_ID_BITS-1:0]      source_id_t;

    event_id_t      e_id;
    event_info_t    e_info;
    source_id_t     s_id;

    modport Output (
        output e_id, e_info, s_id
    );
endinterface

module spu_top #(
    // Static configuration parameters of the cache.
    parameter spu_pkg::cache_cfg_t CacheCfg = spu_pkg::cache_cfg_t'{default: 0},
    parameter int unsigned AXI_ADDR_WIDTH   = 0,
    parameter int unsigned AXI_DATA_WIDTH   = 0,
    parameter int unsigned AXI_ID_WIDTH     = 0,
    parameter int unsigned AXI_USER_WIDTH   = 0
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    AXI_BUS.Slave                   spu_slv,
    AXI_BUS.Master                  spu_mst,
    SPU_INTF.Output                 e_out
);
    import spu_pkg::*;
    localparam N_BUF = 1;

    typedef logic [AXI_ID_WIDTH-1:0]        id_t;
    typedef logic [AXI_ADDR_WIDTH-1:0]      addr_t;
    typedef logic [AXI_DATA_WIDTH-1:0]      data_t;
    typedef logic [AXI_DATA_WIDTH/8-1:0]    strb_t;

    // Ax Buffer
    typedef struct {
        id_t        id;
        addr_t      addr;
        burst_t     burst;
        len_t       len;
        size_t      size;
        logic       valid;
    } ax_chan_t;

    // W Buffer
    typedef struct {
        data_t      data;
        logic       last;
        strb_t      strb;
        logic       valid;
    } w_chan_t;

    // R Buffer
    typedef struct {
        id_t        id;
        data_t      data;
        logic       last;
        resp_t      resp;
        logic       valid;
    } r_chan_t;

    // B Buffer
    typedef struct {
        id_t        id;
        resp_t      resp;
        logic       valid;
    } b_chan_t;

    ax_chan_t   aw_chan;
    ax_chan_t   ar_chan;
    w_chan_t    w_chan;
    r_chan_t    r_chan;
    b_chan_t    b_chan;

    // line offset is the index where we are interested in, or where the line index starts
    localparam int unsigned IndexLength      = unsigned'($clog2(CacheCfg.NumLines));
    localparam int unsigned BlockOffsetLength = unsigned'($clog2(CacheCfg.NumBlocks));
    localparam int unsigned ByteOffsetLength = unsigned'($clog2(AXI_DATA_WIDTH / 32'd8));
    localparam int unsigned LineOffset     = ByteOffsetLength + BlockOffsetLength;
    // localparam int unsigned RuleIndexWidth = cf_math_pkg::idx_width(SetAssociativity + 32'd1);

    // signals for number of cachelines accessed
    addr_t              this_line_address; // address of this line (tag included)
    addr_t              next_line_address; // address of the next line (tag included)
    addr_t              bytes_on_line;     // how many bytes are on this cache line
    axi_pkg::len_t      beats_on_line;     // how many beats are on this cache line
        
    // External-Master <==> [[ Slv ]  SPU  [ Mst ]] <==> External-Slave 
    // OP of E-Mst => IP of I-Slv => OP of I-Mst => IP of E-Slv
    // IP of E-Mst <= OP of I-Slv <= IP of I-Mst <= OP of E-Slv
    // AW Channel
    // IP of E-Slv <= OP of E-Mst
    assign spu_mst.aw_id = spu_slv.aw_id;
    assign spu_mst.aw_addr = spu_slv.aw_addr;
    assign spu_mst.aw_len = spu_slv.aw_len;
    assign spu_mst.aw_size = spu_slv.aw_size;
    assign spu_mst.aw_burst = spu_slv.aw_burst;
    assign spu_mst.aw_lock = spu_slv.aw_lock;
    assign spu_mst.aw_cache = spu_slv.aw_cache;
    assign spu_mst.aw_prot = spu_slv.aw_prot;
    assign spu_mst.aw_qos = spu_slv.aw_qos;
    assign spu_mst.aw_region = spu_slv.aw_region;
    assign spu_mst.aw_atop = spu_slv.aw_atop;
    assign spu_mst.aw_user = spu_slv.aw_user;
    assign spu_mst.aw_valid = spu_slv.aw_valid;
    // IP of E-Mst <= OP of E-Slv
    assign spu_slv.aw_ready = spu_mst.aw_ready;

    // W Channel
    // IP of E-Slv <= OP of E-Mst
    assign spu_mst.w_data = spu_slv.w_data;
    assign spu_mst.w_strb = spu_slv.w_strb;
    assign spu_mst.w_last = spu_slv.w_last;
    assign spu_mst.w_user = spu_slv.w_user;
    assign spu_mst.w_valid = spu_slv.w_valid;
    // IP of E-Mst <= OP of E-Slv
    assign spu_slv.w_ready = spu_mst.w_ready;

    // B Channel
    // IP of E-Mst <= OP of E-Slv
    assign spu_slv.b_id = spu_mst.b_id;
    assign spu_slv.b_resp = spu_mst.b_resp;
    assign spu_slv.b_user = spu_mst.b_user;
    assign spu_slv.b_valid = spu_mst.b_valid;
    // IP of E-Slv <= OP of E-Mst
    assign spu_mst.b_ready = spu_slv.b_ready;

    // AR Channel
    // IP of E-Slv <= OP of E-Mst
    assign spu_mst.ar_id = spu_slv.ar_id;
    assign spu_mst.ar_addr = spu_slv.ar_addr;
    assign spu_mst.ar_len = spu_slv.ar_len;
    assign spu_mst.ar_size = spu_slv.ar_size;
    assign spu_mst.ar_burst = spu_slv.ar_burst;
    assign spu_mst.ar_lock = spu_slv.ar_lock;
    assign spu_mst.ar_cache = spu_slv.ar_cache;
    assign spu_mst.ar_prot = spu_slv.ar_prot;
    assign spu_mst.ar_qos = spu_slv.ar_qos;
    assign spu_mst.ar_region = spu_slv.ar_region;
    assign spu_mst.ar_user = spu_slv.ar_user;
    assign spu_mst.ar_valid = spu_slv.ar_valid;
    // IP of E-Mst <= OP of E-Slv
    assign spu_slv.ar_ready = spu_mst.ar_ready;

    // R CHannel
    // IP of E-Mst <= OP of E-Slv
    assign spu_slv.r_id = spu_mst.r_id;
    assign spu_slv.r_data = spu_mst.r_data;
    assign spu_slv.r_resp = spu_mst.r_resp;
    assign spu_slv.r_last = spu_mst.r_last;
    assign spu_slv.r_user = spu_mst.r_user;
    assign spu_slv.r_valid = spu_mst.r_valid;
    // IP of E-Slv <= OP of E-Mst
    assign spu_mst.r_ready = spu_slv.r_ready;

    // Write Address channel
    always_ff @ (posedge clk_i) begin
        if (!rst_ni) begin
            aw_chan.id <= 0;
            aw_chan.addr <= 0;
            aw_chan.len <= 0;
            aw_chan.size <= 0; 
            aw_chan.burst <= 0;
            aw_chan.valid <= 0;
        end else if ((spu_slv.aw_valid==1)&&(spu_mst.aw_ready==1)) begin
            aw_chan.id <= spu_slv.aw_id;
            aw_chan.addr <= spu_slv.aw_addr;
            aw_chan.len <= spu_slv.aw_len;
            aw_chan.size <= spu_slv.aw_size;
            aw_chan.burst <= spu_slv.aw_burst;
            aw_chan.valid <= 1;
        end else begin
            aw_chan.valid <= 0;
        end
    end

    // Write Data channel
    always_ff @ (posedge clk_i) begin
        if (!rst_ni) begin
            w_chan.data <= 0;
            w_chan.strb <= 0;
            w_chan.last <= 0;
            w_chan.valid <= 0;
        end else if ((spu_slv.w_valid==1)&&(spu_mst.w_ready==1)) begin
            w_chan.data <= spu_slv.w_data;
            w_chan.strb <= spu_slv.w_strb;
            w_chan.last <= spu_slv.w_last;
            w_chan.valid <= 1;
        end else begin
            w_chan.valid <= 0;
        end
    end

    // Write Response channel
    always_ff @ (posedge clk_i) begin
        if (!rst_ni) begin
            b_chan.id <= 0;
            b_chan.resp <= 0;
            b_chan.valid <= 0;
        end else if ((spu_mst.b_valid==1)&&(spu_slv.b_ready==1)) begin
            b_chan.id <= spu_mst.b_id;
            b_chan.resp <= spu_mst.b_resp;
            b_chan.valid <= 1;
        end else begin
            b_chan.valid <= 0;
        end
    end

    // Read Address channel
    always_ff @ (posedge clk_i) begin
        if (!rst_ni) begin
            ar_chan.id <= 0;
            ar_chan.addr <= 0;
            ar_chan.len <= 0;
            ar_chan.size <= 0; 
            ar_chan.burst <= 0;
            ar_chan.valid <= 0;
        end else if ((spu_slv.ar_valid==1)&&(spu_mst.ar_ready==1)) begin
            ar_chan.id <= spu_slv.ar_id;
            ar_chan.addr <= spu_slv.ar_addr;
            ar_chan.len <= spu_slv.ar_len;
            ar_chan.size <= spu_slv.ar_size;
            ar_chan.valid <= 1;
        end else begin
            ar_chan.valid <= 0;
        end
    end

    // Read Data channel
    always_ff @ (posedge clk_i) begin
        if (!rst_ni) begin
            r_chan.id <= 0;
            r_chan.data <= 0;
            r_chan.last <= 0;
            r_chan.resp <= 0;
            r_chan.valid <= 0;
        end else if ((spu_mst.r_valid==1)&&(spu_slv.r_ready==1)) begin
            r_chan.id <= spu_mst.r_id;
            r_chan.data <= spu_mst.r_data;
            r_chan.last <= spu_mst.r_last;
            r_chan.resp <= spu_mst.r_resp;
            r_chan.valid <= 1;
        end else begin
            r_chan.valid <= 0;
        end
    end

    always_comb begin
        e_out.e_id = 0;
        e_out.s_id = 0;
        e_out.e_info = 0;

        if (ar_chan.valid) begin
            e_out.e_id = 1;
            e_out.e_info = 10;
        end else if (aw_chan.valid) begin
            e_out.e_id = 2;
            e_out.e_info = 20;
        end else if (r_chan.valid) begin
            e_out.e_id = 3;
            e_out.e_info = 30;
        end else if (w_chan.valid) begin
            e_out.e_id = 4;
            e_out.e_info = 40;
        end else if (b_chan.valid) begin
            e_out.e_id = 5;
            e_out.e_info = 50;
        end
    end

    // always_ff @ (posedge clk_i) begin 
    //     // calculate the line address (tag included)
    //     this_line_address   = addr_t'(aw_addr_reg[LineOffset+:(AXI_ADDRESS_WIDTH-LineOffset)]
    //                                 << LineOffset);
    //     // calculate the next line address (tag included)
    //     next_line_address   = this_line_address + (addr_t'(1) << LineOffset);
    //     // how many bytes are on the line from curr addr to the end
    //     bytes_on_line       = next_line_address - aw_addr_reg;
    //     // how many transaction beats map onto the current line
    //     beats_on_line       = axi_pkg::len_t'((bytes_on_line - 1) >> aw_size_reg) + 1;
    //     if !(rst_ni) begin
    //         e_ou.e_info <= 0;
    //     end
    //     if (aw_valid_reg) begin
    //         // Do we have beats left on the next line?
    //         if(((beats_on_line - 1) < aw_len_reg) &&
    //             !(aw_burst_reg == axi_pkg::BURST_FIXED)) begin
    //         // in this case we have at least one beat on the next cache line.
    //         next_chan_o.addr  = next_line_address;
    //         next_chan_o.len   = curr_chan_i.len - beats_on_line;
    //         desc_o.a_x_len    = beats_on_line - 1;
    //         desc_o.x_last     = 1'b0;
    //         end else begin // all remaining beats are on the current cacheline.
    //         next_chan_o.addr  = addr_t'(0);
    //         next_chan_o.len   = axi_pkg::len_t'(0);
    //         desc_o.a_x_len    = curr_chan_i.len;
    //         desc_o.x_last     = 1'b1;
    //         end
    //     end
    // end
endmodule





