module axi_channel_compare #(
    parameter type aw_chan_t = logic,
    parameter type w_chan_t  = logic,
    parameter type b_chan_t  = logic,
    parameter type ar_chan_t = logic,
    parameter type r_chan_t  = logic,
    parameter type req_t     = logic,
    parameter type resp_t    = logic
)(
    input logic  clk_i,
    input req_t  axi_a_req,
    input resp_t axi_a_res,
    input req_t  axi_b_req,
    input resp_t axi_b_res
);

    function void print_aw (
        input aw_chan_t aw_expected,
        input aw_chan_t aw_received
    );
        $display("AW      | expected                                                         | received                                                         ");
        $display("--------|------------------------------------------------------------------|-----------------------------------------------------------------");
        $display("id:     | %64d | %64d", aw_expected.id, aw_received.id);
        $display("addr:   | %64x | %64x", aw_expected.addr, aw_received.addr);
        $display("len:    | %64d | %64d", aw_expected.len, aw_received.len);
        $display("size:   | %64d | %64d", aw_expected.size, aw_received.size);
        $display("burst:  | %64d | %64d", aw_expected.burst, aw_received.burst);
        $display("lock:   | %64d | %64d", aw_expected.lock, aw_received.lock);
        $display("cache:  | %64d | %64d", aw_expected.cache, aw_received.cache);
        $display("prot:   | %64d | %64d", aw_expected.prot, aw_received.prot);
        $display("qos:    | %64d | %64d", aw_expected.qos, aw_received.qos);
        $display("region: | %64d | %64d", aw_expected.region, aw_received.region);
        $display("user:   | %64d | %64d", aw_expected.user, aw_received.user);
        $display("atop:   | %64d | %64d", aw_expected.atop, aw_received.atop);
        $display("--------|------------------------------------------------------------------|-----------------------------------------------------------------");
    endfunction

    function void print_ar (
        input ar_chan_t ar_expected,
        input ar_chan_t ar_received
    );
        $display("AR      | expected                                                         | received                                                         ");
        $display("--------|------------------------------------------------------------------|-----------------------------------------------------------------");
        $display("id:     | %64d | %64d", ar_expected.id, ar_received.id);
        $display("addr:   | %64x | %64x", ar_expected.addr, ar_received.addr);
        $display("len:    | %64d | %64d", ar_expected.len, ar_received.len);
        $display("size:   | %64d | %64d", ar_expected.size, ar_received.size);
        $display("burst:  | %64d | %64d", ar_expected.burst, ar_received.burst);
        $display("lock:   | %64d | %64d", ar_expected.lock, ar_received.lock);
        $display("cache:  | %64d | %64d", ar_expected.cache, ar_received.cache);
        $display("prot:   | %64d | %64d", ar_expected.prot, ar_received.prot);
        $display("qos:    | %64d | %64d", ar_expected.qos, ar_received.qos);
        $display("region: | %64d | %64d", ar_expected.region, ar_received.region);
        $display("user:   | %64d | %64d", ar_expected.user, ar_received.user);
        $display("--------|------------------------------------------------------------------|-----------------------------------------------------------------");
    endfunction

    function void print_w (
        input w_chan_t w_expected,
        input w_chan_t w_received
    );
        $display("W       | expected                                                         | received                                                         ");
        $display("--------|------------------------------------------------------------------|-----------------------------------------------------------------");
        $display("data:   | %64x | %64x", w_expected.data, w_received.data);
        $display("strb:   | %64d | %64d", w_expected.strb, w_received.strb);
        $display("last:   | %64d | %64d", w_expected.last, w_received.last);
        $display("user:   | %64d | %64d", w_expected.user, w_received.user);
        $display("--------|------------------------------------------------------------------|-----------------------------------------------------------------");
    endfunction

    function void print_b (
        input b_chan_t b_expected,
        input b_chan_t b_received
    );
        $display("B       | expected                                                         | received                                                         ");
        $display("--------|------------------------------------------------------------------|-----------------------------------------------------------------");
        $display("id:     | %64d | %64d", b_expected.id, b_received.id);
        $display("resp:   | %64d | %64d", b_expected.resp, b_received.resp);
        $display("user:   | %64d | %64d", b_expected.user, b_received.user);
        $display("--------|------------------------------------------------------------------|-----------------------------------------------------------------");
    endfunction

    function void print_r (
        input r_chan_t r_expected,
        input r_chan_t r_received
    );
        $display("R       | expected                                                         | received                                                         ");
        $display("--------|------------------------------------------------------------------|-----------------------------------------------------------------");
        $display("id:     | %64d | %64d", r_expected.id, r_received.id);
        $display("data:   | %64x | %64x", r_expected.data, r_received.data);
        $display("resp:   | %64d | %64d", r_expected.resp, r_received.resp);
        $display("last:   | %64d | %64d", r_expected.last, r_received.last);
        $display("user:   | %64d | %64d", r_expected.user, r_received.user);
        $display("--------|------------------------------------------------------------------|-----------------------------------------------------------------");
    endfunction
    
    // queues
    aw_chan_t aw_queue [$];
    w_chan_t  w_queue  [$];
    b_chan_t  b_queue  [$];
    ar_chan_t ar_queue [$];
    r_chan_t  r_queue  [$];

    // on arrival over axi A: enqueue elements
    always_ff @(posedge clk_i) begin : proc_enqueue
        // aw
        if (axi_a_req.aw_valid & axi_a_res.aw_ready)
            aw_queue.push_back(axi_a_req.aw);
        // w
        if (axi_a_req.w_valid & axi_a_res.w_ready)
            w_queue.push_back(axi_a_req.w);
        // b
        if (axi_b_res.b_valid & axi_b_req.b_ready)
            b_queue.push_back(axi_b_res.b);
        // ar
        if (axi_a_req.ar_valid & axi_a_res.ar_ready)
            ar_queue.push_back(axi_a_req.ar);
        // r
        if (axi_b_res.r_valid & axi_b_req.r_ready)
            r_queue.push_back(axi_b_res.r);
    end

    // on arrival over axi B: dequeue elements and check
    always_ff @(posedge clk_i) begin : proc_dequeue_and_check
        // aw
        if (axi_b_req.aw_valid & axi_b_res.aw_ready) begin
            automatic aw_chan_t aw = aw_queue.pop_front();
            if (axi_b_req.aw !== aw) begin
                $warning("AW mismatch!");
                print_aw(aw, axi_b_req.aw);
            end
        end
        // w
        if (axi_b_req.w_valid & axi_b_res.w_ready) begin
            automatic w_chan_t w = w_queue.pop_front();
            if (axi_b_req.w !== w) begin
                $warning("W mismatch!");
                print_w(w, axi_b_req.w);
            end
        end
        // b
        if (axi_a_res.b_valid & axi_a_req.b_ready) begin
            automatic b_chan_t b = b_queue.pop_front();
            if (axi_a_res.b !== b) begin
                $warning("B mismatch!");
                print_b(b, axi_a_res.b);
            end
        end
        // ar
        if (axi_b_req.ar_valid & axi_b_res.ar_ready) begin
            automatic ar_chan_t ar = ar_queue.pop_front();
            if (axi_b_req.ar !== ar) begin
                $warning("AR mismatch!");
                print_ar(ar, axi_b_req.ar);
            end
        end
        // r
        if (axi_a_res.r_valid & axi_a_req.r_ready) begin
            automatic r_chan_t r = r_queue.pop_front();
            if (axi_a_res.r !== r) begin
                $warning("R mismatch!");
                print_r(r, axi_a_res.r);
            end
        end
    end

endmodule : axi_channel_compare
