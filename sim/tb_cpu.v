`timescale 1ns/1ps

// Runs Tests A, B and C from the design guide on three CPU instances at once
// and checks the expected end state of each program.
module tb_cpu;
    reg clk;
    reg rst_n;

    // Test A: countdown from 5 to 0, then halt
    wire [7:0] out_a, pc_a, acc_a;
    wire [11:0] ir_a;
    wire [1:0] flags_a, state_a;

    // Test B: addition and subtraction through memory
    wire [7:0] out_b, pc_b, acc_b;
    wire [11:0] ir_b;
    wire [1:0] flags_b, state_b;

    // Test C: memory-mapped I/O
    reg [7:0] in_c;
    wire [7:0] out_c, pc_c, acc_c;
    wire [11:0] ir_c;
    wire [1:0] flags_c, state_c;

    // Instantiate one CPU per program
    cpu #(
        .PROGRAM("programs/test_a.hex")
    ) cpu_a (
        .clk(clk),
        .rst_n(rst_n),
        .input_device(8'h00),
        .output_device(out_a),
        .pc(pc_a),
        .ir(ir_a),
        .acc(acc_a),
        .flags(flags_a),
        .state(state_a)
    );

    cpu #(
        .PROGRAM("programs/test_b.hex")
    ) cpu_b (
        .clk(clk),
        .rst_n(rst_n),
        .input_device(8'h00),
        .output_device(out_b),
        .pc(pc_b),
        .ir(ir_b),
        .acc(acc_b),
        .flags(flags_b),
        .state(state_b)
    );

    cpu #(
        .PROGRAM("programs/test_c.hex")
    ) cpu_c (
        .clk(clk),
        .rst_n(rst_n),
        .input_device(in_c),
        .output_device(out_c),
        .pc(pc_c),
        .ir(ir_c),
        .acc(acc_c),
        .flags(flags_c),
        .state(state_c)
    );

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    localparam HALT = 2'd3;

    integer errors;
    integer cycles;

    // Compare one value against its expected end state
    task check;
        input [8*24:1] name;     // what is being checked
        input [7:0]    got;      // actual value
        input [7:0]    exp_val;  // expected value
        begin
            if (got !== exp_val) begin
                $display("FAIL %0s | got %h | expected %h", name, got, exp_val);
                errors = errors + 1;
            end
        end
    endtask

    // Trace Test A's accumulator so the countdown is visible in the log
    always @(acc_a) if (rst_n) $display("  Test A: ACC = %0d at %0t ns", acc_a, $time);

    initial begin
        $dumpfile("tb_cpu.vcd");
        $dumpvars(0, tb_cpu);
        errors = 0;

        // Reset all three CPUs for 2 clocks, then release on a falling edge
        rst_n = 0;
        in_c  = 8'h01;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1;

        // Run until every CPU has halted (or give up after 1000 clocks)
        cycles = 0;
        while ((state_a != HALT || state_b != HALT || state_c != HALT) && cycles < 1000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        #1;
        $display("  All programs finished after %0d clocks", cycles);

        // Test A: ACC = 0x00, Z = 1, halted
        check("A halted",         {6'b0, state_a},    {6'b0, HALT});
        check("A ACC",            acc_a,              8'h00);
        check("A Z flag",         {7'b0, flags_a[0]}, 8'h01);

        // Test B: ACC = 0x0B, MEM[01] = 0x0D, MEM[02] = 0x18, C = 0, halted
        check("B halted",         {6'b0, state_b},    {6'b0, HALT});
        check("B ACC",            acc_b,              8'h0B);
        check("B MEM[01]",        cpu_b.u_dm.mem[1],  8'h0D);
        check("B MEM[02]",        cpu_b.u_dm.mem[2],  8'h18);
        check("B C flag",         {7'b0, flags_b[1]}, 8'h00);

        // Test C: output device = input + 1 = 0x02, halted
        check("C halted",         {6'b0, state_c},    {6'b0, HALT});
        check("C ACC",            acc_c,              8'h02);
        check("C output device",  out_c,              8'h02);

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule