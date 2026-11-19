`timescale 1ns/1ps

// Board top level test.
//   dut   : runs Test C through clock_divider + synchronizers + CPU one CPU clock at a time
//           and checks what the Tang Nano 9K would show on its LEDs.
//   dut_g : runs test_gpio.hex and checks the GPIO pins of ports B and C (tri-state outputs and read-back).
// Port A pins are pulled up like the board and buttons pull them to 0. The buttons are set
// so the port A pins read 0x0A, so Test C writes 0x0A + 1 = 0x0B to OUT (0x81), shown on the LEDs.
module tb_top_tang9k #(
    parameter DIVISOR = 4       // small divisor so the test runs in a few hundred clocks
);
    reg clk;
    reg btn_rst_n;
    reg [7:0] btn_a;                // buttons on port A pins: 1 = pressed (pulls the pin to 0)

    wire [7:0] gpio_a, gpio_b, gpio_c;          // dut pins
    wire [5:0] led;

    wire [7:0] gpio_a_g, gpio_b_g, gpio_c_g;    // dut_g pins
    wire [5:0] led_g;

    // Instantiate DUTs
    top_tang9k #(
        .DIVISOR(DIVISOR),
        .PROGRAM("programs/test_c.hex")
    ) dut (
        .clk(clk),
        .btn_rst_n(btn_rst_n),
        .gpio_a(gpio_a),
        .gpio_b(gpio_b),
        .gpio_c(gpio_c),
        .led(led)
    );

    top_tang9k #(
        .DIVISOR(DIVISOR),
        .PROGRAM("programs/test_gpio.hex")
    ) dut_g (
        .clk(clk),
        .btn_rst_n(btn_rst_n),
        .gpio_a(gpio_a_g),
        .gpio_b(gpio_b_g),
        .gpio_c(gpio_c_g),
        .led(led_g)
    );

    // Board wiring: every GPIO pin has a pull-up; a pressed button pulls a port A pin to 0
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : g_pins
            pullup (gpio_a[i]);
            pullup (gpio_b[i]);
            pullup (gpio_a_g[i]);
            pullup (gpio_b_g[i]);
            pullup (gpio_c[i]);
            pullup (gpio_c_g[i]);
            assign gpio_a[i]   = btn_a[i] ? 1'b0 : 1'bz;
            assign gpio_a_g[i] = btn_a[i] ? 1'b0 : 1'bz;
        end
    endgenerate

    // Board clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    integer errors;
    time    t_rise;             // time of a cpu_clk rising edge

    // One CPU clock: set the button on the falling edge of cpu_clk, let the
    // synchronizer and CPU update on the rising edge, then compare after it settles.
    task board_step;
        input       t_btn;     // task S1 button (0 = pressed)
        input       exp_rst;   // expected reset into the CPU (synchronized S1)
        input [1:0] exp_state; // expected FSM state (0 FETCH, 1 EXECUTE, 2 WRITEBACK, 3 HALT)
        input [7:0] exp_pc;    // expected program counter
        input [7:0] exp_acc;   // expected accumulator
        input [5:0] exp_led;   // expected LEDs (active-low)
        begin
            @(negedge dut.cpu_clk);
            btn_rst_n = t_btn;
            @(posedge dut.cpu_clk);
            #1;
            if (dut.u_rst_sync.data_out !== exp_rst || dut.u_cpu.state !== exp_state ||
                dut.u_cpu.pc !== exp_pc || dut.u_cpu.acc !== exp_acc || led !== exp_led) begin
                $display("FAIL btn=%b | got rst=%b state=%0d pc=%h acc=%h led=%b | expected rst=%b state=%0d pc=%h acc=%h led=%b",
                         t_btn, dut.u_rst_sync.data_out, dut.u_cpu.state, dut.u_cpu.pc, dut.u_cpu.acc, led,
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

        // FPGA power-up: every register starts at 0 (Gowin default), S1 not pressed
        dut.g_divided.u_clk.clk_out   = 1'b0;
        dut.g_divided.u_clk.counter   = 0;
        dut.u_rst_sync.stage1         = 1'b0;
        dut.u_rst_sync.stage2         = 1'b0;
        dut_g.g_divided.u_clk.clk_out = 1'b0;
        dut_g.g_divided.u_clk.counter = 0;
        dut_g.u_rst_sync.stage1       = 1'b0;
        dut_g.u_rst_sync.stage2       = 1'b0;
        btn_rst_n                     = 1'b1;
        btn_a                         = 8'hF5;    // pressed on bits 7..4, 2, 0: pins read 0x0A

        // Power-up reset: the synchronizer starts at 0, so the CPU resets without pressing S1
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

        // GPIO (dut_g): DDRB = 0xF0, DDRC = 0xFF, PORTB = PORTC = PINA = 0x0A
        repeat (20) @(posedge dut_g.cpu_clk);                     // let test_gpio.hex loop a few times
        #1;
        if (dut_g.ddr_b !== 8'hF0 || dut_g.port_b !== 8'h0A) begin
            $display("FAIL GPIO REGS | got ddr_b=%h port_b=%h | expected F0 0A", dut_g.ddr_b, dut_g.port_b);
            errors = errors + 1;
        end
        if (gpio_b_g !== 8'h0F) begin                             // 7..4 driven 0, 3..0 pulled up
            $display("FAIL GPIO PINS | got gpio_b=%h | expected 0F", gpio_b_g);
            errors = errors + 1;
        end
        if (dut_g.output_device !== 8'h0F || led_g !== 6'b110000) begin   // PINB read back
            $display("FAIL GPIO READBACK | got out=%h led=%b | expected 0F 110000",
                     dut_g.output_device, led_g);
            errors = errors + 1;
        end
        if (dut_g.ddr_c !== 8'hFF || gpio_c_g !== 8'h0A) begin   // port C drives all 8 pins
            $display("FAIL GPIO PORT C | got ddr_c=%h gpio_c=%h | expected FF 0A", dut_g.ddr_c, gpio_c_g);
            errors = errors + 1;
        end
        if (gpio_c !== 8'hFF) begin                               // dut never sets DDRC: pins pulled up
            $display("FAIL PORT C INPUTS | got gpio_c=%h | expected FF", gpio_c);
            errors = errors + 1;
        end
        if (gpio_a_g !== 8'h0A) begin                             // port A stays an input
            $display("FAIL GPIO PORT A | got gpio_a=%h | expected 0A", gpio_a_g);
            errors = errors + 1;
        end

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule
