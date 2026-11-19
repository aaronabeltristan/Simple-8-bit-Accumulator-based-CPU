`timescale 1ns/1ps

module tb_data_memory #(
    parameter ADDR_WIDTH = 8,
              DATA_WIDTH = 8
);
    reg clk;
    reg write_en;
    reg [ADDR_WIDTH-1:0] addr;
    reg [DATA_WIDTH-1:0] wdata;
    wire [DATA_WIDTH-1:0] rdata;

    // Instantiate DUT
    data_memory #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .write_en(write_en),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata)
    );

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    integer errors;

    // Write one byte: set inputs on the falling edge, write happens on the rising edge
    task write_step;
        input                  t_write; // task write enable
        input [ADDR_WIDTH-1:0] t_addr;  // task address
        input [DATA_WIDTH-1:0] t_data;  // task write data
        begin
            @(negedge clk);
            write_en = t_write;
            addr     = t_addr;
            wdata    = t_data;
            @(posedge clk);
            #1;
            write_en = 0;
        end
    endtask

    // Read one byte: reads are asynchronous, so rdata follows addr without a clock edge
    task read_step;
        input [ADDR_WIDTH-1:0] t_addr;  // task address
        input [DATA_WIDTH-1:0] exp_out; // expected rdata
        begin
            @(negedge clk);
            write_en = 0;
            addr     = t_addr;
            #1;
            if (rdata !== exp_out) begin
                $display("FAIL READ addr=%h | got %h | expected %h", t_addr, rdata, exp_out);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_data_memory.vcd");
        $dumpvars(0, tb_data_memory);
        errors = 0;

        // All inputs idle
        write_en = 0;
        addr     = 0;
        wdata    = 0;
        repeat (2) @(posedge clk);

        // Write and read back
        write_step(1'b1, 8'h00, 8'h5A);             // RAM[0x00] = 0x5A
        read_step(8'h00, 8'h5A);                    // read back 0x5A

        // Every region of the address range, including the I/O addresses:
        // the RAM itself has no I/O block, data_bus keeps CPU writes out of 0x80-0x8F
        write_step(1'b1, 8'h7F, 8'h11);             // RAM[0x7F] = 0x11
        write_step(1'b1, 8'h80, 8'h22);             // RAM[0x80] = 0x22
        write_step(1'b1, 8'h90, 8'h33);             // RAM[0x90] = 0x33
        write_step(1'b1, 8'hFF, 8'h44);             // RAM[0xFF] = 0x44 (last address)
        read_step(8'h7F, 8'h11);                    // read 0x7F
        read_step(8'h80, 8'h22);                    // read 0x80
        read_step(8'h90, 8'h33);                    // read 0x90
        read_step(8'hFF, 8'h44);                    // read 0xFF
        read_step(8'h00, 8'h5A);                    // first byte unchanged

        // Write disabled: contents stay
        write_step(1'b0, 8'h00, 8'hA5);             // write_en low: ignored
        read_step(8'h00, 8'h5A);                    // still 0x5A

        // Overwrite
        write_step(1'b1, 8'h00, 8'hC3);             // RAM[0x00] = 0xC3
        read_step(8'h00, 8'hC3);                    // new value
        read_step(8'hFF, 8'h44);                    // other bytes unchanged

        // Asynchronous read: rdata changes as soon as addr changes
        @(negedge clk);
        addr = 8'h7F;
        #1;
        if (rdata !== 8'h11) begin
            $display("FAIL ASYNC | got %h | expected 11", rdata);
            errors = errors + 1;
        end
        addr = 8'h90;
        #1;
        if (rdata !== 8'h33) begin
            $display("FAIL ASYNC | got %h | expected 33", rdata);
            errors = errors + 1;
        end

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule
