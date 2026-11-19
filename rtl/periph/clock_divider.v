`timescale 1ns/1ps

module clock_divider #(
    parameter DIVISOR = 13_500_000 // clk_out period in clk_in cycles (27 MHz / 13.5M = 2 Hz)
) (
    input wire clk_in,
    input wire rst_n,
    output reg clk_out
);

    reg [$clog2(DIVISOR)-1:0] counter;

    always @(posedge clk_in) begin
        if (!rst_n) begin
            clk_out <= 1'b0;
            counter <= 0;
        end
        else if (counter == DIVISOR/2 - 1) begin
            clk_out <= ~clk_out; // toggle every half period
            counter <= 0;
        end
        else counter <= counter + 1'b1;
    end

endmodule