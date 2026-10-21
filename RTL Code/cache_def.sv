package cache_def;

    parameter int TAGMSB = 31;
    parameter int TAGLSB = 14;

    typedef struct packed {
        bit                 valid;
        bit                 dirty;
        bit [TAGMSB:TAGLSB] tag;
    } cache_tag_type;

    typedef struct {
        bit [9:0] index;
        bit       we;
    } cache_req_type;

    typedef bit [127:0] cache_data_type;

    // cpu -> cache, rw: 0 = read, 1 = write
    typedef struct {
        bit [31:0] addr;
        bit [31:0] data;
        bit        rw;
        bit        valid;
    } cpu_req_type;

    typedef struct {
        bit [31:0] data;
        bit        ready;
    } cpu_result_type;

    // cache -> memory, rw: 0 = read, 1 = write
    typedef struct {
        bit [31:0]  addr;
        bit [127:0] data;
        bit         rw;
        bit         valid;
    } mem_req_type;

    typedef struct {
        cache_data_type data;
        bit             ready;
    } mem_data_type;

endpackage
