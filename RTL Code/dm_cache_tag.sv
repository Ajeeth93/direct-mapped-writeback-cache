import cache_def::*;

module dm_cache_tag (
    input  bit            clk,
    input  cache_req_type tag_req,
    input  cache_tag_type tag_write,
    output cache_tag_type tag_read
);

    timeunit 1ns;
    timeprecision 1ps;

    // 1024 cache entries
    cache_tag_type tag_mem [0:1023];


    // Initialize tag memory
    // valid = 0
    // dirty = 0
    // tag   = 0
    initial begin
        for (int i = 0; i < 1024; i++) begin
            tag_mem[i] = '0;
        end
    end


    // Asynchronous read
    assign tag_read = tag_mem[tag_req.index];


    // Synchronous write
    always_ff @(posedge clk) begin
        if (tag_req.we) begin
            tag_mem[tag_req.index] <= tag_write;
        end
    end

endmodule
