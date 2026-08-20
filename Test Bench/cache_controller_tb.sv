import cache_def::*;

module cache_controller_tb;

    // Clock and reset

    logic clk;
    logic rst;

    // CPU -> Cache

    cpu_req_type cpu_req;

    // Cache -> CPU

    cpu_result_type cpu_res;

    // Cache -> Memory

    mem_req_type mem_req;

    // Memory -> Cache

    mem_data_type mem_data;

    // Testbench bookkeeping

    integer test_count;
    integer pass_count;
    integer fail_count;

    // Memory model storage
    //
    // This is a simple behavioral memory model.
    //
    // It remembers the last write-back so that we can verify
    // that the cache actually wrote the dirty cache line back.

    logic [31:0]  last_writeback_addr;
    logic [127:0] last_writeback_data;

    integer writeback_count;
    integer read_request_count;

    // Clock generation
    // 10 ns period

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Device Under Test

    dm_cache_fsm dut (

        .clk      (clk),
        .rst      (rst),

        .cpu_req  (cpu_req),
        .cpu_res  (cpu_res),

        .mem_req  (mem_req),
        .mem_data (mem_data)

    );

    // Simple memory model
    //
    // The cache requests an entire 128-bit cache line.
    //
    // For READ:
    //     memory waits one clock cycle
    //     then returns a 128-bit cache line.
    //
    // For WRITE:
    //     memory records the write-back
    //     then asserts ready for one cycle.

    always_ff @(posedge clk) begin

        // Default:
        // ready is normally LOW.
        mem_data.ready <= 1'b0;


        if (mem_req.valid) begin

            // ====================================================
            // MEMORY WRITE
            // ====================================================

            if (mem_req.rw) begin

                $display(
                    "[MEM] WRITE-BACK request: addr = %08h, data = %032h, time = %0t",
                    mem_req.addr,
                    mem_req.data,
                    $time
                );

                last_writeback_addr <= mem_req.addr;
                last_writeback_data <= mem_req.data;

                writeback_count <= writeback_count + 1;

                // Acknowledge write-back
                mem_data.ready <= 1'b1;
                mem_data.data  <= 128'b0;

            end


            // ====================================================
            // MEMORY READ
            // ====================================================

            else begin

                $display(
                    "[MEM] READ request: addr = %08h, time = %0t",
                    mem_req.addr,
                    $time
                );

                read_request_count <= read_request_count + 1;

                // ------------------------------------------------
                // Return a deterministic cache line based on
                // requested line address.
                // ------------------------------------------------

                case (mem_req.addr)

                    // ------------------------------------------------
                    // Line at address 0x00000000
                    //
                    // word 0 = AAAAAAAA
                    // word 1 = BBBBBBBB
                    // word 2 = CCCCCCCC
                    // word 3 = DDDDDDDD
                    // ------------------------------------------------

                    32'h0000_0000: begin

                        mem_data.data <= {
                            32'hDDDD_DDDD,
                            32'hCCCC_CCCC,
                            32'hBBBB_BBBB,
                            32'hAAAA_AAAA
                        };

                    end


                    // ------------------------------------------------
                    // Line at address 0x00001000
                    // ------------------------------------------------

                    32'h0000_1000: begin

                        mem_data.data <= {
                            32'h4444_4444,
                            32'h3333_3333,
                            32'h2222_2222,
                            32'h1111_1111
                        };

                    end


                    // ------------------------------------------------
                    // Line at address 0x00004000
                    // ------------------------------------------------

                    32'h0000_4000: begin

                        mem_data.data <= {
                            32'h8888_8888,
                            32'h7777_7777,
                            32'h6666_6666,
                            32'h5555_5555
                        };

                    end


                    // ------------------------------------------------
                    // Any other memory address
                    // ------------------------------------------------

                    default: begin

                        mem_data.data <= {
                            mem_req.addr,
                            mem_req.addr,
                            mem_req.addr,
                            mem_req.addr
                        };

                    end

                endcase


                // Tell cache that data is available
                mem_data.ready <= 1'b1;

            end

        end

    end


    // ============================================================
    // Utility task:
    // Initialize CPU request.
    // ============================================================

    task automatic clear_cpu_request();

        begin

            cpu_req.addr  = 32'b0;
            cpu_req.data  = 32'b0;
            cpu_req.rw    = 1'b0;
            cpu_req.valid = 1'b0;

        end

    endtask


    // ============================================================
    // Utility task:
    // Send CPU READ request.
    //
    // The request is held valid until cpu_res.ready.
    // ============================================================

    task automatic cpu_read(
        input logic [31:0] addr,
        input logic [31:0] expected_data
    );

        integer timeout;

        begin

            test_count = test_count + 1;

            $display("");
            $display("============================================================");
            $display("TEST %0d: CPU READ  addr = %08h", test_count, addr);
            $display("Expected data = %08h", expected_data);
            $display("============================================================");


            // Drive request
            @(negedge clk);

            cpu_req.addr  = addr;
            cpu_req.data  = 32'b0;
            cpu_req.rw    = 1'b0;
            cpu_req.valid = 1'b1;


            // Wait for cache response
            timeout = 0;

            while (!cpu_res.ready && timeout < 100) begin

                @(posedge clk);

                timeout = timeout + 1;

            end


            // Timeout check
            if (timeout >= 100) begin

                $error(
                    "READ TIMEOUT: address = %08h",
                    addr
                );

                fail_count = fail_count + 1;

            end

            else begin

                // Check returned data
                if (cpu_res.data === expected_data) begin

                    $display(
                        "[PASS] READ addr=%08h data=%08h",
                        addr,
                        cpu_res.data
                    );

                    pass_count = pass_count + 1;

                end

                else begin

                    $error(
                        "[FAIL] READ addr=%08h expected=%08h actual=%08h",
                        addr,
                        expected_data,
                        cpu_res.data
                    );

                    fail_count = fail_count + 1;

                end

            end


            // Remove request
            @(negedge clk);

            clear_cpu_request();

        end

    endtask

    // Utility task:
    // Send CPU WRITE request.
    //
    // The request is held valid until cpu_res.ready.

    task automatic cpu_write(
        input logic [31:0] addr,
        input logic [31:0] data
    );

        integer timeout;

        begin

            test_count = test_count + 1;

            $display("");
            $display("============================================================");
            $display("TEST %0d: CPU WRITE addr = %08h", test_count, addr);
            $display("Write data = %08h", data);
            $display("============================================================");


            @(negedge clk);

            cpu_req.addr  = addr;
            cpu_req.data  = data;
            cpu_req.rw    = 1'b1;
            cpu_req.valid = 1'b1;


            timeout = 0;

            while (!cpu_res.ready && timeout < 100) begin

                @(posedge clk);

                timeout = timeout + 1;

            end


            if (timeout >= 100) begin

                $error(
                    "WRITE TIMEOUT: address = %08h",
                    addr
                );

                fail_count = fail_count + 1;

            end

            else begin

                $display(
                    "[PASS] WRITE completed addr=%08h data=%08h",
                    addr,
                    data
                );

                pass_count = pass_count + 1;

            end


            @(negedge clk);

            clear_cpu_request();

        end

    endtask

    // Check that no memory request is generated.
    //
    // Used for cache HIT tests.

    task automatic check_no_memory_request(
        input integer cycles
    );

        integer i;

        begin

            for (i = 0; i < cycles; i = i + 1) begin

                @(posedge clk);

                if (mem_req.valid) begin

                    $error(
                        "[FAIL] Unexpected memory request at time %0t",
                        $time
                    );

                    fail_count = fail_count + 1;

                end

            end

        end

    endtask

    // Check write-back information

    task automatic check_writeback(
        input logic [31:0] expected_addr,
        input logic [127:0] expected_data
    );

        begin

            if (last_writeback_addr === expected_addr) begin

                $display(
                    "[PASS] Write-back address = %08h",
                    last_writeback_addr
                );

                pass_count = pass_count + 1;

            end

            else begin

                $error(
                    "[FAIL] Write-back address: expected=%08h actual=%08h",
                    expected_addr,
                    last_writeback_addr
                );

                fail_count = fail_count + 1;

            end


            if (last_writeback_data === expected_data) begin

                $display(
                    "[PASS] Write-back data = %032h",
                    last_writeback_data
                );

                pass_count = pass_count + 1;

            end

            else begin

                $error(
                    "[FAIL] Write-back data:\nexpected=%032h\nactual  =%032h",
                    expected_data,
                    last_writeback_data
                );

                fail_count = fail_count + 1;

            end

        end

    endtask


    // Main test sequence

    initial begin

        // Initialize bookkeeping

        test_count = 0;
        pass_count = 0;
        fail_count = 0;

        writeback_count    = 0;
        read_request_count = 0;

        last_writeback_addr = 32'b0;
        last_writeback_data = 128'b0;

        mem_data = '0;

        clear_cpu_request();


        // RESET

        $display("");
        $display("============================================================");
        $display("RESET");
        $display("============================================================");

        rst = 1'b1;

        repeat (4) @(posedge clk);

        rst = 1'b0;

        repeat (2) @(posedge clk);

        // TEST 1
        //
        // Read address 0x00000000.
        //
        // Cache starts empty, so this must be a READ MISS.
        //
        // Memory returns:
        //
        // [127:96] = DDDDDDDD
        // [95:64]  = CCCCCCCC
        // [63:32]  = BBBBBBBB
        // [31:0]   = AAAAAAAA

        cpu_read(
            32'h0000_0000,
            32'hAAAA_AAAA
        );

        // TEST 2
        //
        // Read word at +4.
        //
        // This must be a CACHE HIT.
        // No memory request should occur.

        cpu_read(
            32'h0000_0004,
            32'hBBBB_BBBB
        );

        // TEST 3
        //
        // Read word at +8.
        //
        // Cache HIT.

        cpu_read(
            32'h0000_0008,
            32'hCCCC_CCCC
        );

        // TEST 4
        //
        // Read word at +12.
        //
        // Cache HIT.

        cpu_read(
            32'h0000_000C,
            32'hDDDD_DDDD
        );

        // TEST 5
        //
        // WRITE HIT to word 0.
        //
        // Change AAAAAAAA -> 12345678.
        //
        // Cache line should become dirty.

        cpu_write(
            32'h0000_0000,
            32'h1234_5678
        );

        // TEST 6
        //
        // Read back word 0.
        //
        // Should return newly written value.
        // No memory transaction should be required.

        cpu_read(
            32'h0000_0000,
            32'h1234_5678
        );

        // TEST 7
        //
        // Write hit to word 1.

        cpu_write(
            32'h0000_0004,
            32'h8765_4321
        );

        // TEST 8
        //
        // Read back word 1.

        cpu_read(
            32'h0000_0004,
            32'h8765_4321
        );

        // TEST 9
        //
        // Write hit to word 2.

        cpu_write(
            32'h0000_0008,
            32'hDEAD_BEEF
        );

        // TEST 10
        //
        // Read back word 2.

        cpu_read(
            32'h0000_0008,
            32'hDEAD_BEEF
        );

        // TEST 11
        //
        // Write hit to word 3.

        cpu_write(
            32'h0000_000C,
            32'hCAFE_BABE
        );

        // TEST 12
        //
        // Read back word 3.

        cpu_read(
            32'h0000_000C,
            32'hCAFE_BABE
        );

        // At this point cache line 0 should contain:
        //
        // [127:96] = CAFEBABE
        // [95:64]  = DEADBEEF
        // [63:32]  = 87654321
        // [31:0]   = 12345678
        //

        $display("");
        $display("Expected dirty cache line:");
        $display(
            "CAFEBABE_DEADBEEF_87654321_12345678"
        );

        // TEST 13
        //
        // CLEAN MISS.
        //
        // Address 0x00001000:
        //
        // tag   = 0
        // index = 0x100
        //
        // This is a different cache index from 0x00000000.
        //
        // Therefore it should NOT evict the dirty line at index 0.

        cpu_read(
            32'h0000_1000,
            32'h1111_1111
        );

        // Test remaining words of second line

        cpu_read(
            32'h0000_1004,
            32'h2222_2222
        );

        cpu_read(
            32'h0000_1008,
            32'h3333_3333
        );

        cpu_read(
            32'h0000_100C,
            32'h4444_4444
        );

        // TEST 14
        //
        // DIRTY MISS.
        //
        // Address 0x00004000:
        //
        // 0x00000000:
        //     tag   = 0
        //     index = 0
        //
        // 0x00004000:
        //     tag   = 1
        //     index = 0
        //
        // SAME INDEX
        // DIFFERENT TAG
        //
        // Therefore the dirty line at index 0 must be written back.

        cpu_read(
            32'h0000_4000,
            32'h5555_5555
        );

        // Check that exactly one write-back occurred.

        if (writeback_count == 1) begin

            $display(
                "[PASS] Exactly one write-back occurred."
            );

            pass_count = pass_count + 1;

        end

        else begin

            $error(
                "[FAIL] Expected 1 write-back, got %0d",
                writeback_count
            );

            fail_count = fail_count + 1;

        end


        // Verify write-back address.
        //
        // Old line:
        //
        // tag = 0
        // index = 0
        //
        // Therefore write-back address = 0x00000000.

        check_writeback(
            32'h0000_0000,

            {
                32'hCAFE_BABE,
                32'hDEAD_BEEF,
                32'h8765_4321,
                32'h1234_5678
            }
        );


        // TEST 15
        //
        // Verify words in newly allocated 0x4000 line.

        cpu_read(
            32'h0000_4004,
            32'h6666_6666
        );

        cpu_read(
            32'h0000_4008,
            32'h7777_7777
        );

        cpu_read(
            32'h0000_400C,
            32'h8888_8888
        );

        // Final statistics

        #20;

        $display("");
        $display("");
        $display("============================================================");
        $display("                 CACHE TEST SUMMARY");
        $display("============================================================");
        $display("Tests performed : %0d", test_count);
        $display("Passed          : %0d", pass_count);
        $display("Failed          : %0d", fail_count);
        $display("Memory reads    : %0d", read_request_count);
        $display("Write-backs     : %0d", writeback_count);
        $display("============================================================");


        if (fail_count == 0) begin

            $display("");
            $display("****************************************");
            $display("*** ALL CACHE TESTS PASSED ************");
            $display("****************************************");
            $display("");

        end

        else begin

            $display("");
            $display("****************************************");
            $display("*** CACHE TEST FAILED *****************");
            $display("****************************************");
            $display("");

        end


        $finish;

    end

endmodule
