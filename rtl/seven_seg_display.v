`timescale 1ns/1ps

// 4-digit multiplexed 7-segment driver for a 5641BS (common anode, 0.56").
// Shows value (0-255) in decimal, right-aligned, with leading zeros blanked: "   7", "  42", " 255".
// One digit is lit at a time; the digits are scanned fast enough (about 100 Hz per digit) to look steady.
//
// seg[7:0] = {dp, g, f, e, d, c, b, a}
// dig[3:0] = {DIG4 (rightmost), DIG3, DIG2, DIG1 (leftmost)}
module seven_seg_display #(
    parameter CLK_HZ   = 27_000_000,
              SCAN_HZ  = 400,           // digit switching rate: 4 digits -> 100 Hz full refresh
              SEG_ACTIVE_LOW = 1,       // common anode: a segment lights when its cathode pin is 0
              DIG_ACTIVE_LOW = 1        // 1 = PNP transistor per digit (pin 0 turns the digit on)
) (
    input wire clk,
    input wire [7:0] value,
    output wire [7:0] seg,
    output wire [3:0] dig
);

    localparam SCAN_COUNT = CLK_HZ / SCAN_HZ;

    reg [$clog2(SCAN_COUNT)-1:0] scan_counter = 0;
    reg [1:0] digit_sel = 0;            // which digit is lit: 0 = DIG1 ... 3 = DIG4

    // Scan: move to the next digit every SCAN_COUNT clocks
    always @(posedge clk) begin
        if (scan_counter == SCAN_COUNT - 1) begin
            scan_counter <= 0;
            digit_sel    <= digit_sel + 1'b1;
        end
        else scan_counter <= scan_counter + 1'b1;
    end

    // Split the value into decimal digits (each result fits in 4 bits)
    wire [7:0] hundreds_full = value / 8'd100;
    wire [7:0] tens_full     = (value / 8'd10) % 8'd10;
    wire [7:0] ones_full     = value % 8'd10;
    wire [3:0] hundreds      = hundreds_full[3:0];
    wire [3:0] tens          = tens_full[3:0];
    wire [3:0] ones          = ones_full[3:0];

    // Digit to show at the current scan position (4'hF = blank)
    reg [3:0] digit;
    always @(*) begin
        case (digit_sel)
            2'd0: digit = 4'hF;                                     // DIG1 unused (max 255)
            2'd1: digit = (hundreds == 0) ? 4'hF : hundreds;        // blank leading zero
            2'd2: digit = (hundreds == 0 && tens == 0) ? 4'hF : tens;
            default: digit = ones;                                  // DIG4 always shown
        endcase
    end

    // Segment patterns, active-high: {dp, g, f, e, d, c, b, a}
    reg [7:0] pattern;
    always @(*) begin
        case (digit)
            4'd0: pattern = 8'b0011_1111;
            4'd1: pattern = 8'b0000_0110;
            4'd2: pattern = 8'b0101_1011;
            4'd3: pattern = 8'b0100_1111;
            4'd4: pattern = 8'b0110_0110;
            4'd5: pattern = 8'b0110_1101;
            4'd6: pattern = 8'b0111_1101;
            4'd7: pattern = 8'b0000_0111;
            4'd8: pattern = 8'b0111_1111;
            4'd9: pattern = 8'b0110_1111;
            default: pattern = 8'b0000_0000;                        // blank
        endcase
    end

    wire [3:0] dig_onehot = 4'b0001 << digit_sel;

    assign seg = SEG_ACTIVE_LOW ? ~pattern    : pattern;
    assign dig = DIG_ACTIVE_LOW ? ~dig_onehot : dig_onehot;

endmodule
