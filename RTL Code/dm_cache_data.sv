import cache_def::*;

module dm_cache_data (
    input  bit             clk,
    input  cache_req_type  data_req,
    input  cache_data_type data_write,
    output cache_data_type data_read
);

    timeunit 1ns;
    timeprecision 1ps;

    // 1024 cache lines
    // Each line = 128 bits
    cache_data_type data_mem [0:1023];


    // Initialize memory
    initial begin
        for (int i = 0; i < 1024; i++) begin
            data_mem[i] = '0;
        end
    end


    // Asynchronous read
    assign data_read = data_mem[data_req.index];


    // Synchronous write
    always_ff @(posedge clk) begin
        if (data_req.we) begin
            data_mem[data_req.index] <= data_write;
        end
    end

endmodule
