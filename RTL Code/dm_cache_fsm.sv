import cache_def::*;

module dm_cache_fsm (
    input  bit             clk,
    input  bit             rst,
    input  cpu_req_type    cpu_req,
    input  mem_data_type   mem_data,
    output mem_req_type    mem_req,
    output cpu_result_type cpu_res
);
    timeunit 1ns;
    timeprecision 1ps;

    typedef enum {idle, compare_tag, allocate, write_back} cache_state_type;

    cache_state_type vstate, rstate;

    cache_tag_type  tag_read, tag_write;
    cache_req_type  tag_req;

    cache_data_type data_read, data_write;
    cache_req_type  data_req;

    cpu_result_type v_cpu_res;
    mem_req_type    v_mem_req;

    assign mem_req = v_mem_req;
    assign cpu_res = v_cpu_res;

    always_comb begin
        vstate    = rstate;
        v_cpu_res = '{0, 0};
        tag_write = '{0, 0, 0};

        tag_req.we     = '0;
        tag_req.index  = cpu_req.addr[13:4];
        data_req.we    = '0;
        data_req.index = cpu_req.addr[13:4];

        // write the cpu word into the selected position of the line
        data_write = data_read;
        case (cpu_req.addr[3:2])
            2'b00: data_write[31:0]   = cpu_req.data;
            2'b01: data_write[63:32]  = cpu_req.data;
            2'b10: data_write[95:64]  = cpu_req.data;
            2'b11: data_write[127:96] = cpu_req.data;
        endcase

        case (cpu_req.addr[3:2])
            2'b00: v_cpu_res.data = data_read[31:0];
            2'b01: v_cpu_res.data = data_read[63:32];
            2'b10: v_cpu_res.data = data_read[95:64];
            2'b11: v_cpu_res.data = data_read[127:96];
        endcase

        v_mem_req.addr  = cpu_req.addr;
        v_mem_req.data  = data_read;
        v_mem_req.rw    = '0;
        v_mem_req.valid = '0;

        case (rstate)
            idle: begin
                if (cpu_req.valid)
                    vstate = compare_tag;
            end

            compare_tag: begin
                if (cpu_req.addr[TAGMSB:TAGLSB] == tag_read.tag && tag_read.valid) begin
                    v_cpu_res.ready = '1;
                    if (cpu_req.rw) begin
                        tag_req.we      = '1;
                        data_req.we     = '1;
                        tag_write.tag   = tag_read.tag;
                        tag_write.valid = '1;
                        tag_write.dirty = '1;
                    end
                    vstate = idle;
                end
                else begin
                    // miss: install the new tag and ask memory for the line
                    tag_req.we      = '1;
                    tag_write.valid = '1;
                    tag_write.tag   = cpu_req.addr[TAGMSB:TAGLSB];
                    tag_write.dirty = cpu_req.rw;
                    v_mem_req.valid = '1;

                    if (tag_read.valid == 1'b0 || tag_read.dirty == 1'b0)
                        vstate = allocate;
                    else begin
                        // old line is dirty, write it back first
                        v_mem_req.addr = {tag_read.tag, cpu_req.addr[TAGLSB-1:0]};
                        v_mem_req.rw   = '1;
                        vstate = write_back;
                    end
                end
            end

            allocate: begin
                if (mem_data.ready) begin
                    vstate      = compare_tag;
                    data_write  = mem_data.data;
                    data_req.we = '1;
                end
            end

            write_back: begin
                if (mem_data.ready) begin
                    v_mem_req.valid = '1;
                    v_mem_req.rw    = '0;
                    vstate = allocate;
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst)
            rstate <= idle;
        else
            rstate <= vstate;
    end

    dm_cache_tag  ctag  (.*);
    dm_cache_data cdata (.*);
endmodule
