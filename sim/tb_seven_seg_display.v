`timescale 1ns/1ps

module tb_seven_seg_display #(
    parameter CLK_HZ  = 40,     // small values so each digit is lit for only 4 clocks
              SCAN_HZ = 10
);
    reg clk;
    reg [7:0] value;
    wire [7:0] seg;             // {dp, g, f, e, d, c, b, a}, active-low
    wire [3:0] dig;             // {DIG4 .. DIG1}, active-low

    // Instantiate DUT
    seven_seg_display #(
        .CLK_HZ(CLK_HZ),
        .SCAN_HZ(SCAN_HZ),
        .SEG_ACTIVE_LOW(1),
        .DIG_ACTIVE_LOW(1)
    ) dut (
        .clk(clk),
        .value(value),
        .seg(seg),
        .dig(dig)
    );

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    localparam SCAN_COUNT = CLK_HZ / SCAN_HZ;    // clocks per digit

    // Digit select, active-low
    localparam DIG1 = 4'b1110,
               DIG2 = 4'b1101,
               DIG3 = 4'b1011,
               DIG4 = 4'b0111;

    // Segment patterns, active-low {dp, g, f, e, d, c, b, a}
    localparam S0 = 8'hC0, S1 = 8'hF9, S2 = 8'hA4, S3 = 8'hB0, S4 = 8'h99,
               S5 = 8'h92, S6 = 8'h82, S7 = 8'hF8, S8 = 8'h80, S9 = 8'h90,
               BLANK = 8'hFF;

    integer errors;
    time    t_start;            // time DIG1 turned on

    // One digit: wait until the scan lights that digit, then compare its segments
    task digit_step;
        input [3:0] t_dig;     // task digit select to wait for
        input [7:0] exp_seg;   // expected segments while that digit is lit
        begin
            wait (dig == t_dig);
            #1;
            if (seg !== exp_seg) begin
                $display("FAIL value=%0d dig=%b | got seg=%h | expected %h", value, t_dig, seg, exp_seg);
                errors = errors + 1;
            end
        end
    endtask

    // One value: set it, then check all four digits in scan order (DIG1 to DIG4)
    task value_step;
        input [7:0] t_value;   // task value to display
        input [7:0] exp_d1;    // expected segments on DIG1 (left)
        input [7:0] exp_d2;    // expected segments on DIG2
        input [7:0] exp_d3;    // expected segments on DIG3
        input [7:0] exp_d4;    // expected segments on DIG4 (right)
        begin
            @(negedge clk);
            value = t_value;
            wait (dig != DIG1);                  // start from a fresh scan:
            wait (dig == DIG1);                  // the next time DIG1 turns on
            digit_step(DIG1, exp_d1);
            digit_step(DIG2, exp_d2);
            digit_step(DIG3, exp_d3);
            digit_step(DIG4, exp_d4);
        end
    endtask

    // Only one digit may be lit at any time
    always @(dig) begin
        #1;
        if (dig !== DIG1 && dig !== DIG2 && dig !== DIG3 && dig !== DIG4) begin
            $display("FAIL SCAN | dig=%b is not exactly one digit", dig);
            errors = errors + 1;
        end
    end

    initial begin
        $dumpfile("tb_seven_seg_display.vcd");
        $dumpvars(0, tb_seven_seg_display);
        errors = 0;
        value  = 0;

        // Leading zeros are blanked, the ones digit is always shown
        value_step(8'd0,   BLANK, BLANK, BLANK, S0);   // "   0"
        value_step(8'd7,   BLANK, BLANK, BLANK, S7);   // "   7"
        value_step(8'd42,  BLANK, BLANK, S4,    S2);   // "  42"
        value_step(8'd99,  BLANK, BLANK, S9,    S9);   // "  99"

        // Three digits: a zero inside the number is shown
        value_step(8'd100, BLANK, S1,    S0,    S0);   // " 100"
        value_step(8'd105, BLANK, S1,    S0,    S5);   // " 105"
        value_step(8'd168, BLANK, S1,    S6,    S8);   // " 168"
        value_step(8'd203, BLANK, S2,    S0,    S3);   // " 203"
        value_step(8'd255, BLANK, S2,    S5,    S5);   // " 255"

        // Scan timing: each digit lit for SCAN_COUNT clocks, all four in 4 x SCAN_COUNT
        wait (dig != DIG1);
        wait (dig == DIG1);                     // DIG1 just turned on
        t_start = $time;
        wait (dig == DIG2);
        if (($time - t_start) / 10 != SCAN_COUNT) begin
            $display("FAIL DIGIT TIME | got %0d clocks | expected %0d", ($time - t_start) / 10, SCAN_COUNT);
            errors = errors + 1;
        end
        wait (dig == DIG1);
        if (($time - t_start) / 10 != 4 * SCAN_COUNT) begin
            $display("FAIL SCAN TIME | got %0d clocks | expected %0d", ($time - t_start) / 10, 4 * SCAN_COUNT);
            errors = errors + 1;
        end

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule
