package cache_def;

    // Address organization
    //
    // 31:14 = TAG    = 18 bits
    // 13:4  = INDEX  = 10 bits
    // 3:2   = WORD   = 2 bits
    // 1:0   = BYTE   = 2 bits
    //
    // Cache:
    //   1024 lines
    //   16 bytes/line
    //   128 bits/line

    parameter int TAGMSB   = 31;
    parameter int TAGLSB   = 14;

    parameter int INDEXMSB = 13;
    parameter int INDEXLSB = 4;

    // Cache tag

    typedef struct packed {
        bit                  valid;
        bit                  dirty;
        bit [TAGMSB:TAGLSB]  tag;
    } cache_tag_type;

    // Cache RAM request

    typedef struct packed {
        bit [9:0] index;
        bit       we;
    } cache_req_type;

    // Cache line data

    typedef bit [127:0] cache_data_type;

    // CPU request

    typedef struct packed {
        bit [31:0] addr;
        bit [31:0] data;
        bit        rw;
        bit        valid;
    } cpu_req_type;

    // CPU response

    typedef struct packed {
        bit [31:0] data;
        bit        ready;
    } cpu_result_type;

    // Memory request

    typedef struct packed {
        bit [31:0]  addr;
        bit [127:0] data;
        bit         rw;
        bit         valid;
    } mem_req_type;

    // Memory response

    typedef struct packed {
        bit [127:0] data;
        bit         ready;
    } mem_data_type;

endpackage
