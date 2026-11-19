`timescale 1ns/1ps

module tb_instruction_memory #(
    parameter ADDR_WIDTH = 8,
              DATA_WIDTH = 12,
              PROGRAM    = "programs/test_a.hex"
);
    reg [ADDR_WIDTH-1:0] addr;
    wire [DATA_WIDTH-1:0] data_out;

    // Instantiate DUT
    instruction_memory #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .PROGRAM(PROGRAM)
    ) dut (
        .addr(addr),
        .data_out(data_out)
    );

    integer errors;

    // Set the address, let the read settle, compare
    task check;
        input [ADDR_WIDTH-1:0] t_addr;  // task address
        input [DATA_WIDTH-1:0] exp_out; // expected instruction
        begin
            addr = t_addr;
            #1;
            if (data_out !== exp_out) begin
                $display("FAIL addr=%h | got %h | expected %h", t_addr, data_out, exp_out);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_instruction_memory.vcd");
        $dumpvars(0, tb_instruction_memory);
        errors = 0;

        // Program loaded from test_a.hex
        check(8'h00, 12'hA05);   // LDI 0x05
        check(8'h01, 12'h981);   // STE 0x81
        check(8'h02, 12'h501);   // SUBI 0x01 (DEC)
        check(8'h03, 12'hC02);   // SKIP if Z = 1
        check(8'h04, 12'hB01);   // GOTO 0x01
        check(8'h05, 12'h981);   // STE 0x81
        check(8'h06, 12'hE01);   // CTL HALT

        // HALT filler outside the program
        check(8'h07, 12'hE01);   // first empty location
        check(8'h80, 12'hE01);   // middle of memory
        check(8'hFF, 12'hE01);   // last location

        // Read-back after jumping around (no state inside the ROM)
        check(8'h03, 12'hC02);   // back to SKIP if Z = 1
        check(8'h00, 12'hA05);   // back to LDI 0x05

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule