import cache_def::*;

module dm_cache_tag (
    input  bit            clk,
    input  cache_req_type tag_req,
    input  cache_tag_type tag_write,
    output cache_tag_type tag_read
);
    timeunit 1ns;
    timeprecision 1ps;

    cache_tag_type tag_mem [0:1023];

    initial begin
        for (int i = 0; i < 1024; i++)
            tag_mem[i] = '0;
    end

    assign tag_read = tag_mem[tag_req.index];

    always_ff @(posedge clk) begin
        if (tag_req.we)
            tag_mem[tag_req.index] <= tag_write;
    end
endmodule
