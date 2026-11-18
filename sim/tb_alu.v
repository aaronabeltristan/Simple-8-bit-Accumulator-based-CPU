`timescale 1ns/1ps

module tb_alu #(
    parameter OPCODE_WIDTH = 4, 
              DATA_WIDTH = 8, 
              FLAG_WIDTH = 2
);
    reg [OPCODE_WIDTH-1:0] opcode;
    reg [DATA_WIDTH-1:0] A;
    reg [DATA_WIDTH-1:0] B;
    wire [DATA_WIDTH-1:0] out;
    wire [FLAG_WIDTH-1:0] flags_out;

    // Instantiate DUT
    alu #(
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .FLAG_WIDTH(FLAG_WIDTH)
    ) dut (
        .opcode(opcode),
        .A(A),
        .B(B),
        .out(out),
        .flags_out(flags_out)
    );

    integer errors;

    // Create a verilog task to speed up testing
    task check;
        input [OPCODE_WIDTH-1:0] t_op; // task opcode
        input [DATA_WIDTH-1:0]   t_a;  // task operand a
        input [DATA_WIDTH-1:0]   t_b;  // task operand b
        input [DATA_WIDTH-1:0]   exp_out; // expected out
        input                    exp_z;   // expected zero flag
        input                    exp_c;   // expected carry flag
        begin
            opcode = t_op;
            A      = t_a;
            B      = t_b;
            #1;
            if (out !== exp_out || flags_out[0] !== exp_z || flags_out[1] !== exp_c) begin
                $display("FAIL op=%h A=%h B=%h | got out=%h Z=%b C=%b | expected out=%h Z=%b C=%b",
                         t_op, t_a, t_b, out, flags_out[0], flags_out[1], exp_out, exp_z, exp_c);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);
        errors = 0;

        // ADD
        check(4'h0, 8'h16, 8'h02, 8'h18, 1'b0, 1'b0);   // ADD normal: 0x16+0x02 = 0x18
        check(4'h0, 8'h00, 8'h00, 8'h00, 1'b1, 1'b0);   // ADD 0+0: zero flag only
        check(4'h0, 8'hFF, 8'h01, 8'h00, 1'b1, 1'b1);   // ADD overflow to zero: Z and C
        check(4'h0, 8'hFF, 8'hFF, 8'hFE, 1'b0, 1'b1);   // ADD overflow, nonzero result: C only

        // SUB
        check(4'h1, 8'h18, 8'h0D, 8'h0B, 1'b0, 1'b0);   // SUB normal: 24-13 = 11
        check(4'h1, 8'h05, 8'h05, 8'h00, 1'b1, 1'b0);   // SUB equal operands: zero, no borrow
        check(4'h1, 8'h03, 8'h05, 8'hFE, 1'b0, 1'b1);   // SUB A<B: wraps, borrow
        check(4'h1, 8'h00, 8'h01, 8'hFF, 1'b0, 1'b1);   // SUB 0-1: wraps to 0xFF, borrow

        // AND
        check(4'h2, 8'hF0, 8'h3C, 8'h30, 1'b0, 1'b0);   // AND mixed bits
        check(4'h2, 8'hF0, 8'h0F, 8'h00, 1'b1, 1'b0);   // AND no common bits: zero, C stays 0
        check(4'h2, 8'hFF, 8'hFF, 8'hFF, 1'b0, 1'b0);   // AND all ones: C stays 0

        // OR
        check(4'h3, 8'h50, 8'h05, 8'h55, 1'b0, 1'b0);   // OR mixed bits
        check(4'h3, 8'hF0, 8'h0F, 8'hFF, 1'b0, 1'b0);   // OR to all ones: C stays 0
        check(4'h3, 8'h00, 8'h00, 8'h00, 1'b1, 1'b0);   // OR zeros: zero flag

        // ADDI (immediate form of ADD: same operation, B = operand)
        check(4'h4, 8'h16, 8'h02, 8'h18, 1'b0, 1'b0);   // ADDI normal: 0x16+0x02 = 0x18
        check(4'h4, 8'h41, 8'h01, 8'h42, 1'b0, 1'b0);   // ADDI 1 (replaces INC)
        check(4'h4, 8'hFF, 8'h01, 8'h00, 1'b1, 1'b1);   // ADDI 1 wrap: Z and C

        // SUBI (immediate form of SUB)
        check(4'h5, 8'h80, 8'h01, 8'h7F, 1'b0, 1'b0);   // SUBI 1 (replaces DEC), across bit 7
        check(4'h5, 8'h01, 8'h01, 8'h00, 1'b1, 1'b0);   // SUBI 1 to zero: Z, no borrow
        check(4'h5, 8'h00, 8'h01, 8'hFF, 1'b0, 1'b1);   // SUBI 1 wrap: borrow

        // ANDI (immediate form of AND)
        check(4'h6, 8'hF0, 8'h3C, 8'h30, 1'b0, 1'b0);   // ANDI mixed bits
        check(4'h6, 8'hF0, 8'h0F, 8'h00, 1'b1, 1'b0);   // ANDI no common bits: zero, C stays 0

        // ORI (immediate form of OR)
        check(4'h7, 8'h50, 8'h05, 8'h55, 1'b0, 1'b0);   // ORI mixed bits
        check(4'h7, 8'h00, 8'h00, 8'h00, 1'b1, 1'b0);   // ORI zeros: zero flag

        // NOT (B = 0xAA to prove B is ignored)
        check(4'hD, 8'hFF, 8'hAA, 8'h00, 1'b1, 1'b0);   // NOT 0xFF -> 0x00: zero flag
        check(4'hD, 8'h00, 8'hAA, 8'hFF, 1'b0, 1'b0);   // NOT 0x00 -> 0xFF: C stays 0
        check(4'hD, 8'h5A, 8'hAA, 8'hA5, 1'b0, 1'b0);   // NOT mixed bits

        // Non-ALU opcodes output 0
        check(4'h8, 8'h12, 8'h34, 8'h00, 1'b1, 1'b0);   // LD opcode: ALU outputs 0
        check(4'hC, 8'hFF, 8'h01, 8'h00, 1'b1, 1'b0);   // SKIP opcode: ALU outputs 0
        check(4'hF, 8'hFF, 8'hFF, 8'h00, 1'b1, 1'b0);   // CLR opcode: ALU outputs 0

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule