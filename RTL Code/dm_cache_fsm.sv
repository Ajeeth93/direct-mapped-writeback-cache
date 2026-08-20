import cache_def::*;

module dm_cache_fsm (
    input  bit             clk,
    input  bit             rst,

    // CPU interface

    input  cpu_req_type    cpu_req,
    output cpu_result_type cpu_res,

    // Memory interface

    output mem_req_type    mem_req,
    input  mem_data_type    mem_data
);

    timeunit 1ns;
    timeprecision 1ps;

    // FSM states

    typedef enum logic [1:0] {
        IDLE,
        COMPARE_TAG,
        ALLOCATE,
        WRITE_BACK
    } cache_state_type;

    cache_state_type rstate;
    cache_state_type vstate;

    // Tag RAM interface

    cache_tag_type tag_read;
    cache_tag_type tag_write;
    cache_req_type tag_req;

    // Data RAM interface

    cache_data_type data_read;
    cache_data_type data_write;
    cache_req_type  data_req;

    // CPU response

    cpu_result_type v_cpu_res;

    // Memory request

    mem_req_type v_mem_req;

    // Save CPU request
    // A cache miss can take multiple cycles, so we must not use
    // cpu_req directly after the request has been accepted.

    bit [31:0] saved_addr;
    bit [31:0] saved_data;
    bit        saved_rw;

    // Address fields from saved CPU request

    logic [9:0]  saved_index;
    logic [17:0] saved_tag;
    logic [1:0]  saved_word;

    assign saved_index = saved_addr[13:4];
    assign saved_tag   = saved_addr[31:14];
    assign saved_word  = saved_addr[3:2];

    // Output assignments

    assign cpu_res = v_cpu_res;
    assign mem_req = v_mem_req;

    // COMBINATIONAL FSM

    always_comb begin

        // Defaults

        vstate = rstate;

        v_cpu_res = '0;
        v_mem_req = '0;

        tag_req   = '0;
        tag_write = '0;

        data_req  = '0;
        data_write = data_read;

        // Cache index

        tag_req.index  = saved_index;
        data_req.index = saved_index;

        // Default CPU read data

        case (saved_word)

            2'b00:
                v_cpu_res.data = data_read[31:0];

            2'b01:
                v_cpu_res.data = data_read[63:32];

            2'b10:
                v_cpu_res.data = data_read[95:64];

            2'b11:
                v_cpu_res.data = data_read[127:96];

            default:
                v_cpu_res.data = 32'b0;

        endcase

        // Construct modified cache line for WRITE

        case (saved_word)

            2'b00:
                data_write[31:0] = saved_data;

            2'b01:
                data_write[63:32] = saved_data;

            2'b10:
                data_write[95:64] = saved_data;

            2'b11:
                data_write[127:96] = saved_data;

            default:
                data_write = data_read;

        endcase

        // FSM

        case (rstate)


            // IDLE

            IDLE: begin

                if (cpu_req.valid) begin

                    vstate = COMPARE_TAG;

                end

            end

            // COMPARE TAG

            COMPARE_TAG: begin

                // HIT

                if (
                    tag_read.valid &&
                    (tag_read.tag == saved_tag)
                ) begin

                    // READ HIT

                    if (!saved_rw) begin

                        v_cpu_res.ready = 1'b1;

                    end

                    // WRITE HIT

                    else begin

                        // Write modified line
                        data_req.we = 1'b1;

                        // Update tag entry
                        tag_req.we = 1'b1;

                        tag_write.valid = 1'b1;
                        tag_write.dirty = 1'b1;
                        tag_write.tag   = tag_read.tag;

                        // Tell CPU operation is complete
                        v_cpu_res.ready = 1'b1;

                    end

                    // Transaction complete
                    vstate = IDLE;

                end

                // MISS

                else begin

                    // Dirty victim

                    if (
                        tag_read.valid &&
                        tag_read.dirty
                    ) begin

                        // Memory write request
                        v_mem_req.valid = 1'b1;
                        v_mem_req.rw    = 1'b1;

                        // Address of old cache line:
                        //
                        // old tag | current index | 0000
                        //
                        v_mem_req.addr = {
                            tag_read.tag,
                            saved_index,
                            4'b0000
                        };

                        // Entire old cache line
                        v_mem_req.data = data_read;

                        vstate = WRITE_BACK;

                    end

                    // Invalid or clean victim

                    else begin

                        // Request new cache line
                        v_mem_req.valid = 1'b1;
                        v_mem_req.rw    = 1'b0;

                        // Align CPU address to 16-byte boundary
                        v_mem_req.addr = {
                            saved_addr[31:4],
                            4'b0000
                        };

                        vstate = ALLOCATE;

                    end

                end

            end

            // WRITE BACK

            WRITE_BACK: begin

                // Wait for memory controller to finish write-back

                if (mem_data.ready) begin

                    // Request new cache line
                    v_mem_req.valid = 1'b1;
                    v_mem_req.rw    = 1'b0;

                    v_mem_req.addr = {
                        saved_addr[31:4],
                        4'b0000
                    };

                    vstate = ALLOCATE;

                end

            end

            // ALLOCATE

            ALLOCATE: begin

                // Wait for memory to return cache line

                if (mem_data.ready) begin

                    // Store new cache line
                    data_req.we = 1'b1;
                    data_write = mem_data.data;

                    // Install new tag
                    tag_req.we = 1'b1;

                    tag_write.valid = 1'b1;
                    tag_write.tag   = saved_tag;

                    // Read miss:
                    //     dirty = 0
                    //
                    // Write miss:
                    //     dirty = 1
                    //
                    tag_write.dirty = saved_rw;

                    // Go back and complete original CPU request
                    vstate = COMPARE_TAG;

                end

            end

            // Default

            default: begin

                vstate = IDLE;

            end

        endcase

    end

    // SEQUENTIAL LOGIC

    always_ff @(posedge clk) begin

        if (rst) begin

            rstate     <= IDLE;

            saved_addr <= 32'b0;
            saved_data <= 32'b0;
            saved_rw   <= 1'b0;

        end

        else begin

            rstate <= vstate;

            // Capture CPU request

            if (
                (rstate == IDLE) &&
                cpu_req.valid
            ) begin

                saved_addr <= cpu_req.addr;
                saved_data <= cpu_req.data;
                saved_rw   <= cpu_req.rw;

            end

        end

    end

    // TAG MEMORY

    dm_cache_tag ctag (
        .clk       (clk),
        .tag_req   (tag_req),
        .tag_write (tag_write),
        .tag_read  (tag_read)
    );

    // DATA MEMORY

    dm_cache_data cdata (
        .clk        (clk),
        .data_req   (data_req),
        .data_write (data_write),
        .data_read  (data_read)
    );

endmodule
