`timescale 1ns/1ps

// Board top level test: runs Test C through clock_divider + reset synchronizer + CPU
// one CPU clock at a time and checks what the Tang Nano 9K would show on its LEDs.
// input_device is tied to 0x0A on the board, so Test C writes 0x0A + 1 = 0x0B to 0x81.
module tb_top_tang9k #(
    parameter DIVISOR = 4       // small divisor so the test runs in a few hundred clocks
);
    reg clk;
    reg btn_rst_n;
    wire [5:0] led;

    // Instantiate DUT
    top_tang9k #(
        .DIVISOR(DIVISOR),
        .PROGRAM("programs/test_c.hex")
    ) dut (
        .clk(clk),
        .btn_rst_n(btn_rst_n),
        .led(led)
    );

    // Board clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    integer errors;
    time    t_rise;             // time of a cpu_clk rising edge

    // One CPU clock: set the button on the falling edge of cpu_clk, let the
    // synchronizer and CPU update on the rising edge, then compare after it settles.
    task board_step;
        input       t_btn;     // task S1 button (0 = pressed)
        input       exp_rst;   // expected reset into the CPU (rst_sync[1])
        input [1:0] exp_state; // expected FSM state (0 FETCH, 1 EXECUTE, 2 WRITEBACK, 3 HALT)
        input [7:0] exp_pc;    // expected program counter
        input [7:0] exp_acc;   // expected accumulator
        input [5:0] exp_led;   // expected LEDs (active-low)
        begin
            @(negedge dut.cpu_clk);
            btn_rst_n = t_btn;
            @(posedge dut.cpu_clk);
            #1;
            if (dut.rst_sync[1] !== exp_rst || dut.u_cpu.state !== exp_state ||
                dut.u_cpu.pc !== exp_pc || dut.u_cpu.acc !== exp_acc || led !== exp_led) begin
                $display("FAIL btn=%b | got rst=%b state=%0d pc=%h acc=%h led=%b | expected rst=%b state=%0d pc=%h acc=%h led=%b",
                         t_btn, dut.rst_sync[1], dut.u_cpu.state, dut.u_cpu.pc, dut.u_cpu.acc, led,
                         exp_rst, exp_state, exp_pc, exp_acc, exp_led);
                errors = errors + 1;
            end
        end
    endtask

    // cpu_clk period must be DIVISOR board clocks
    task clk_period_check;
        input integer exp_cycles; // expected period in board clocks
        begin
            @(posedge dut.cpu_clk);
            t_rise = $time;
            @(posedge dut.cpu_clk);
            if (($time - t_rise) / 10 != exp_cycles) begin
                $display("FAIL CPU CLOCK | got %0d board clocks | expected %0d",
                         ($time - t_rise) / 10, exp_cycles);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_top_tang9k.vcd");
        $dumpvars(0, tb_top_tang9k);
        errors = 0;

        // FPGA power-up: every register starts at 0 (Gowin default), button not pressed
        dut.u_clk.clk_out = 1'b0;
        dut.u_clk.counter = 0;
        dut.rst_sync      = 2'b00;
        btn_rst_n         = 1'b1;

        // Power-up reset: rst_sync starts at 00, so the CPU resets without pressing S1
        board_step(1'b1, 1'b1, 2'd0, 8'h00, 8'h00, 6'b111111);   // still in reset, LEDs off

        // Test C: LD 0x80, ADDI 1, STE 0x81, HALT
        board_step(1'b1, 1'b1, 2'd1, 8'h01, 8'h00, 6'b111111);   // FETCH 880: PC -> 1
        board_step(1'b1, 1'b1, 2'd2, 8'h01, 8'h00, 6'b111111);   // EXECUTE LD: read input 0x0A
        board_step(1'b1, 1'b1, 2'd0, 8'h01, 8'h0A, 6'b111111);   // WRITEBACK LD: ACC = 0x0A
        board_step(1'b1, 1'b1, 2'd1, 8'h02, 8'h0A, 6'b111111);   // FETCH 401: PC -> 2
        board_step(1'b1, 1'b1, 2'd0, 8'h02, 8'h0B, 6'b111111);   // EXECUTE ADDI 1: ACC = 0x0B
        board_step(1'b1, 1'b1, 2'd1, 8'h03, 8'h0B, 6'b111111);   // FETCH 981: PC -> 3
        board_step(1'b1, 1'b1, 2'd0, 8'h03, 8'h0B, 6'b110100);   // EXECUTE STE 0x81: LEDs show 0x0B
        board_step(1'b1, 1'b1, 2'd1, 8'h04, 8'h0B, 6'b110100);   // FETCH E01: PC -> 4
        board_step(1'b1, 1'b1, 2'd3, 8'h04, 8'h0B, 6'b110100);   // EXECUTE HALT
        board_step(1'b1, 1'b1, 2'd3, 8'h04, 8'h0B, 6'b110100);   // stays halted, LEDs hold

        // Press S1: reset reaches the CPU two cpu_clk edges later
        board_step(1'b0, 1'b1, 2'd3, 8'h04, 8'h0B, 6'b110100);   // sync stage 1: CPU not reset yet
        board_step(1'b0, 1'b0, 2'd3, 8'h04, 8'h0B, 6'b110100);   // sync stage 2: reset now active
        board_step(1'b0, 1'b0, 2'd0, 8'h00, 8'h00, 6'b111111);   // CPU reset: PC, ACC, LEDs cleared
        board_step(1'b0, 1'b0, 2'd0, 8'h00, 8'h00, 6'b111111);   // held in reset

        // Release S1: reset clears two cpu_clk edges later, then Test C runs again
        board_step(1'b1, 1'b0, 2'd0, 8'h00, 8'h00, 6'b111111);   // sync stage 1: still in reset
        board_step(1'b1, 1'b1, 2'd0, 8'h00, 8'h00, 6'b111111);   // sync stage 2: last reset clock
        board_step(1'b1, 1'b1, 2'd1, 8'h01, 8'h00, 6'b111111);   // FETCH 880: PC -> 1
        board_step(1'b1, 1'b1, 2'd2, 8'h01, 8'h00, 6'b111111);   // EXECUTE LD
        board_step(1'b1, 1'b1, 2'd0, 8'h01, 8'h0A, 6'b111111);   // WRITEBACK LD: ACC = 0x0A
        board_step(1'b1, 1'b1, 2'd1, 8'h02, 8'h0A, 6'b111111);   // FETCH 401
        board_step(1'b1, 1'b1, 2'd0, 8'h02, 8'h0B, 6'b111111);   // EXECUTE ADDI 1: ACC = 0x0B
        board_step(1'b1, 1'b1, 2'd1, 8'h03, 8'h0B, 6'b111111);   // FETCH 981
        board_step(1'b1, 1'b1, 2'd0, 8'h03, 8'h0B, 6'b110100);   // EXECUTE STE 0x81: LEDs show 0x0B
        board_step(1'b1, 1'b1, 2'd1, 8'h04, 8'h0B, 6'b110100);   // FETCH E01
        board_step(1'b1, 1'b1, 2'd3, 8'h04, 8'h0B, 6'b110100);   // EXECUTE HALT

        // CPU clock from the divider
        clk_period_check(DIVISOR);                                // DIVISOR board clocks per CPU clock

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule
