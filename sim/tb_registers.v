`timescale 1ns/1ps

module tb_registers #(
    parameter PC_WIDTH   = 8,
              IR_WIDTH   = 12,
              ACC_WIDTH  = 8,
              FLAG_WIDTH = 2
);
    reg clk;
    reg rst_n;

    // Program counter signals
    reg pc_load_en;
    reg pc_inc_en;
    reg [PC_WIDTH-1:0] pc_in;
    wire [PC_WIDTH-1:0] pc_out;

    // Instruction register signals
    reg ir_load_en;
    reg [IR_WIDTH-1:0] ir_in;
    wire [IR_WIDTH-1:0] ir_out;

    // Accumulator signals
    reg acc_load_en;
    reg acc_clear_en;
    reg [ACC_WIDTH-1:0] acc_in;
    wire [ACC_WIDTH-1:0] acc_out;

    // Flag register signals
    reg fr_load_en;
    reg fr_clear_en;
    reg [FLAG_WIDTH-1:0] fr_in;
    wire [FLAG_WIDTH-1:0] fr_out;

    // Instantiate DUTs
    program_counter #(
        .WIDTH(PC_WIDTH)
    ) pc (
        .clk(clk),
        .rst_n(rst_n),
        .inc_en(pc_inc_en),
        .load_en(pc_load_en),
        .data_in(pc_in),
        .data_out(pc_out)
    );

    instruction_register #(
        .WIDTH(IR_WIDTH)
    ) ir (
        .clk(clk),
        .rst_n(rst_n),
        .load_en(ir_load_en),
        .data_in(ir_in),
        .data_out(ir_out)
    );

    accumulator #(
        .WIDTH(ACC_WIDTH)
    ) acc (
        .clk(clk),
        .rst_n(rst_n),
        .load_en(acc_load_en),
        .clear_en(acc_clear_en),
        .data_in(acc_in),
        .data_out(acc_out)
    );

    flag_register #(
        .FLAG_WIDTH(FLAG_WIDTH)
    ) fr (
        .clk(clk),
        .rst_n(rst_n),
        .load_en(fr_load_en),
        .clear_en(fr_clear_en),
        .data_in(fr_in),
        .data_out(fr_out)
    );

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    integer errors;

    // Each step task: set inputs on the falling edge, let the register
    // capture them on the rising edge, then compare after it settles.

    task pc_step;
        input                t_load;  // task load enable
        input                t_inc;   // task increment enable
        input [PC_WIDTH-1:0] t_in;    // task data in
        input [PC_WIDTH-1:0] exp_out; // expected out
        begin
            @(negedge clk);
            pc_load_en = t_load;
            pc_inc_en  = t_inc;
            pc_in      = t_in;
            @(posedge clk);
            #1;
            if (pc_out !== exp_out) begin
                $display("FAIL PC load=%b inc=%b in=%h | got %h | expected %h",
                         t_load, t_inc, t_in, pc_out, exp_out);
                errors = errors + 1;
            end
        end
    endtask

    task ir_step;
        input                t_load;  // task load enable
        input [IR_WIDTH-1:0] t_in;    // task data in
        input [IR_WIDTH-1:0] exp_out; // expected out
        begin
            @(negedge clk);
            ir_load_en = t_load;
            ir_in      = t_in;
            @(posedge clk);
            #1;
            if (ir_out !== exp_out) begin
                $display("FAIL IR load=%b in=%h | got %h | expected %h",
                         t_load, t_in, ir_out, exp_out);
                errors = errors + 1;
            end
        end
    endtask

    task acc_step;
        input                 t_load;  // task load enable
        input                 t_clear; // task clear enable
        input [ACC_WIDTH-1:0] t_in;    // task data in
        input [ACC_WIDTH-1:0] exp_out; // expected out
        begin
            @(negedge clk);
            acc_load_en  = t_load;
            acc_clear_en = t_clear;
            acc_in       = t_in;
            @(posedge clk);
            #1;
            if (acc_out !== exp_out) begin
                $display("FAIL ACC load=%b clear=%b in=%h | got %h | expected %h",
                         t_load, t_clear, t_in, acc_out, exp_out);
                errors = errors + 1;
            end
        end
    endtask

    task flag_step;
        input                  t_load;  // task load enable
        input                  t_clear; // task clear enable
        input [FLAG_WIDTH-1:0] t_in;    // task data in ([1] C, [0] Z)
        input [FLAG_WIDTH-1:0] exp_out; // expected out
        begin
            @(negedge clk);
            fr_load_en  = t_load;
            fr_clear_en = t_clear;
            fr_in       = t_in;
            @(posedge clk);
            #1;
            if (fr_out !== exp_out) begin
                $display("FAIL FLAGS load=%b clear=%b in=%b | got %b | expected %b",
                         t_load, t_clear, t_in, fr_out, exp_out);
                errors = errors + 1;
            end
        end
    endtask

    // All four registers must read 0 after reset
    task check_reset;
        begin
            if (pc_out !== 0 || ir_out !== 0 || acc_out !== 0 || fr_out !== 0) begin
                $display("FAIL RESET | got pc=%h ir=%h acc=%h flags=%b | expected all 0",
                         pc_out, ir_out, acc_out, fr_out);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_registers.vcd");
        $dumpvars(0, tb_registers);
        errors = 0;

        // All inputs idle, reset held
        rst_n        = 0;
        pc_load_en   = 0;  pc_inc_en    = 0;  pc_in  = 0;
        ir_load_en   = 0;  ir_in        = 0;
        acc_load_en  = 0;  acc_clear_en = 0;  acc_in = 0;
        fr_load_en   = 0;  fr_clear_en  = 0;  fr_in  = 0;

        // Reset: hold for 2 clocks, check, then release on a falling edge
        repeat (2) @(posedge clk);
        #1;
        check_reset;                                     // all registers start at 0
        @(negedge clk);
        rst_n = 1;

        // Program counter
        pc_step(1'b0, 1'b1, 8'h00, 8'h01);              // increment: 0 -> 1
        pc_step(1'b0, 1'b1, 8'h00, 8'h02);              // increment: 1 -> 2
        pc_step(1'b0, 1'b1, 8'h00, 8'h03);              // increment: 2 -> 3
        pc_step(1'b1, 1'b0, 8'h20, 8'h20);              // load 0x20 (jump)
        pc_step(1'b1, 1'b1, 8'h40, 8'h40);              // load and inc together: load wins
        pc_step(1'b1, 1'b0, 8'hFF, 8'hFF);              // load 0xFF
        pc_step(1'b0, 1'b1, 8'h00, 8'h00);              // increment wraps: 0xFF -> 0x00
        pc_step(1'b0, 1'b0, 8'hAA, 8'h00);              // both low: holds, data ignored
        pc_step(1'b0, 1'b0, 8'h55, 8'h00);              // still holds

        // Instruction register
        ir_step(1'b1, 12'h905, 12'h905);                // load LDI 0x05
        ir_step(1'b0, 12'hABC, 12'h905);                // load low: holds, data ignored
        ir_step(1'b1, 12'hE01, 12'hE01);                // load HALT
        ir_step(1'b0, 12'h000, 12'hE01);                // still holds

        // Accumulator
        acc_step(1'b1, 1'b0, 8'h5A, 8'h5A);             // load 0x5A
        acc_step(1'b0, 1'b0, 8'hA5, 8'h5A);             // load low: holds, data ignored
        acc_step(1'b0, 1'b1, 8'hA5, 8'h00);             // clear
        acc_step(1'b1, 1'b0, 8'hFF, 8'hFF);             // load 0xFF
        acc_step(1'b1, 1'b1, 8'h77, 8'h00);             // load and clear together: clear wins

        // Flag register ([1] C, [0] Z)
        flag_step(1'b1, 1'b0, 2'b11, 2'b11);            // load Z and C
        flag_step(1'b0, 1'b0, 2'b00, 2'b11);            // load low: holds, data ignored
        flag_step(1'b0, 1'b1, 2'b11, 2'b00);            // clear
        flag_step(1'b1, 1'b0, 2'b01, 2'b01);            // load Z only
        flag_step(1'b1, 1'b0, 2'b10, 2'b10);            // load C only
        flag_step(1'b1, 1'b1, 2'b11, 2'b00);            // load and clear together: clear wins

        // Mid-run reset: load nonzero values first
        pc_step(1'b1, 1'b0, 8'h33, 8'h33);              // PC = 0x33
        ir_step(1'b1, 12'h123, 12'h123);                // IR = 0x123
        acc_step(1'b1, 1'b0, 8'h44, 8'h44);             // ACC = 0x44
        flag_step(1'b1, 1'b0, 2'b11, 2'b11);            // flags = 11

        // Assert reset with every enable high: reset must win
        @(negedge clk);
        rst_n       = 0;
        pc_load_en  = 1;  pc_in  = 8'h99;
        ir_load_en  = 1;  ir_in  = 12'hFFF;
        acc_load_en = 1;  acc_in = 8'h99;
        fr_load_en  = 1;  fr_in  = 2'b11;
        @(posedge clk);
        #1;
        check_reset;                                     // reset beats load on every register

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule