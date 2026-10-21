import cache_def::*;

module cache_controller_tb;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int MEM_LATENCY  = 3;
    localparam int RANDOM_TESTS = 1000;

    bit clk;
    bit rst;

    cpu_req_type    cpu_req;
    cpu_result_type cpu_res;
    mem_req_type    mem_req;
    mem_data_type   mem_data;

    dm_cache_fsm dut (.*);

    always #5 clk = ~clk;

    // ------------------------------------------------------------
    // main memory model
    // takes a request when mem_req.valid is high, waits MEM_LATENCY
    // cycles and then pulses mem_data.ready for one cycle
    // ------------------------------------------------------------

    bit [127:0] mem [bit [27:0]];      // line address -> line data

    int         mem_reads;
    int         mem_writes;
    bit [31:0]  last_wb_addr;
    bit [127:0] last_wb_data;

    bit         busy;
    int         wait_cnt;
    bit         pend_rw;
    bit [27:0]  pend_line;

    // what memory holds at an address that was never written
    function automatic bit [31:0] init_word(bit [31:0] addr);
        return {addr[31:2], 2'b00} ^ 32'hC0DE_0000;
    endfunction

    function automatic bit [127:0] read_line(bit [27:0] line);
        bit [127:0] d;
        if (mem.exists(line))
            return mem[line];
        for (int w = 0; w < 4; w++)
            d[w*32 +: 32] = init_word({line, w[1:0], 2'b00});
        return d;
    endfunction

    always @(posedge clk) begin
        mem_data.ready <= 1'b0;

        if (rst) begin
            busy <= 1'b0;
        end
        else if (busy) begin
            if (wait_cnt == 0) begin
                busy           <= 1'b0;
                mem_data.ready <= 1'b1;
                if (!pend_rw)
                    mem_data.data <= read_line(pend_line);
            end
            else
                wait_cnt <= wait_cnt - 1;
        end
        else if (mem_req.valid) begin
            busy      <= 1'b1;
            wait_cnt  <= MEM_LATENCY - 1;
            pend_rw   <= mem_req.rw;
            pend_line <= mem_req.addr[31:4];

            if (mem_req.rw) begin
                mem[mem_req.addr[31:4]] = mem_req.data;
                last_wb_addr = mem_req.addr;
                last_wb_data = mem_req.data;
                mem_writes++;
            end
            else
                mem_reads++;
        end
    end

    // ------------------------------------------------------------
    // reference model of what the cpu should read back
    // ------------------------------------------------------------

    bit [31:0] ref_mem [bit [31:0]];   // word address -> last written value

    function automatic bit [31:0] expected(bit [31:0] addr);
        bit [31:0] a = {addr[31:2], 2'b00};
        return ref_mem.exists(a) ? ref_mem[a] : init_word(a);
    endfunction

    // ------------------------------------------------------------
    // cpu side tasks
    // the request is held until ready is seen, then dropped
    // ------------------------------------------------------------

    task automatic cpu_access(input bit rw, input bit [31:0] addr,
                              input bit [31:0] wdata, output bit [31:0] rdata);
        int cycles = 0;

        @(negedge clk);
        cpu_req.addr  = addr;
        cpu_req.data  = wdata;
        cpu_req.rw    = rw;
        cpu_req.valid = 1'b1;

        do begin
            @(negedge clk);
            cycles++;
            if (cycles > 100) begin
                $display("ERROR: timeout waiting for ready, addr %h", addr);
                $finish;
            end
        end while (!cpu_res.ready);

        rdata = cpu_res.data;
        @(posedge clk);
        #1 cpu_req.valid = 1'b0;
    endtask

    task automatic cpu_write(input bit [31:0] addr, input bit [31:0] data);
        bit [31:0] unused;
        cpu_access(1'b1, addr, data, unused);
        ref_mem[{addr[31:2], 2'b00}] = data;
    endtask

    task automatic cpu_read(input bit [31:0] addr, output bit ok);
        bit [31:0] got;
        bit [31:0] exp;
        cpu_access(1'b0, addr, 32'h0, got);
        exp = expected(addr);
        ok  = (got == exp);
        if (!ok)
            $display("  read %h: got %h, expected %h", addr, got, exp);
    endtask

    // ------------------------------------------------------------
    // checking
    // ------------------------------------------------------------

    int checks;
    int errors;
    int r0, w0;

    task automatic check(input bit cond, input string msg);
        checks++;
        if (cond)
            $display("PASS  %s", msg);
        else begin
            errors++;
            $display("FAIL  %s", msg);
        end
    endtask

    function automatic void mark();
        r0 = mem_reads;
        w0 = mem_writes;
    endfunction

    function automatic bit traffic(int reads, int writes);
        return (mem_reads - r0 == reads) && (mem_writes - w0 == writes);
    endfunction

    // A and B map to the same cache line (index 1) with different tags,
    // C maps to index 2
    localparam bit [31:0] A = 32'h0000_0010;
    localparam bit [31:0] B = 32'h0000_4010;
    localparam bit [31:0] C = 32'h0000_0020;

    initial begin
        bit ok;
        bit ok2;
        bit [31:0] addr;
        int rand_errors;

        cpu_req = '{default: 0};
        rst = 1'b1;
        repeat (3) @(posedge clk);
        #1 rst = 1'b0;

        $display("");
        $display("---- directed tests ----");

        mark(); cpu_read(A, ok);
        check(ok && traffic(1, 0), "read miss on empty cache fetches the line");

        mark(); cpu_read(A + 4, ok);
        check(ok && traffic(0, 0), "read hit, no memory access");

        mark(); cpu_write(A + 8, 32'h1111_2222);
        check(traffic(0, 0), "write hit stays in the cache");

        mark(); cpu_read(A + 8, ok);
        check(ok && traffic(0, 0), "read back the word written on a hit");

        mark(); cpu_write(C + 4, 32'h3333_4444);
        check(traffic(1, 0), "write miss on empty line fetches the line");

        mark(); cpu_read(C + 4, ok); cpu_read(C, ok2);
        check(ok && ok2 && traffic(0, 0), "write miss merged the word into the fetched line");

        mark(); cpu_read(B, ok);
        check(ok && traffic(1, 1), "miss on a dirty line writes it back, then fetches");
        check(last_wb_addr[31:4] == A[31:4] && last_wb_data[95:64] == 32'h1111_2222,
              "write-back has the right address and data");

        mark(); cpu_read(A + 8, ok);
        check(ok && traffic(1, 0), "miss on a clean line, written data comes back from memory");

        mark(); cpu_write(B + 12, 32'h5555_6666);
        check(traffic(1, 0), "write miss with a clean victim, no write-back");

        mark(); cpu_read(A, ok);
        check(ok && traffic(1, 1), "write-miss line is dirty and gets written back");
        check(last_wb_addr[31:4] == B[31:4] && last_wb_data[127:96] == 32'h5555_6666,
              "write-back has the right address and data");

        mark(); cpu_read(B + 12, ok);
        check(ok && traffic(1, 0), "evicted write is read back from memory");

        $display("");
        $display("---- random tests (%0d accesses) ----", RANDOM_TESTS);

        // 4 tags x 4 indexes x 4 words, so plenty of hits, misses and evictions
        rand_errors = 0;
        mark();
        for (int i = 0; i < RANDOM_TESTS; i++) begin
            addr = '0;
            addr[15:14] = $urandom_range(0, 3);
            addr[5:4]   = $urandom_range(0, 3);
            addr[3:2]   = $urandom_range(0, 3);

            if ($urandom_range(0, 1))
                cpu_write(addr, $urandom);
            else begin
                cpu_read(addr, ok);
                if (!ok) rand_errors++;
            end
        end
        $display("      memory reads: %0d, write-backs: %0d", mem_reads - r0, mem_writes - w0);
        check(rand_errors == 0, "random reads all match the reference model");

        $display("");
        $display("==========================================");
        $display("  checks: %0d   passed: %0d   failed: %0d", checks, checks - errors, errors);
        if (errors == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED");
        $display("==========================================");
        $finish;
    end

    initial begin
        #10ms;
        $display("ERROR: simulation timeout");
        $finish;
    end

endmodule
