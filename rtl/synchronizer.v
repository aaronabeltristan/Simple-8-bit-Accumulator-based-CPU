`timescale 1ns/1ps

// Two flip-flop synchronizer: brings asynchronous inputs (buttons, external signals)
// into the clk domain. data_out follows data_in two clock edges later and never
// changes halfway through a clock, so the logic after it always sees a clean 0 or 1.
// Each bit is synchronized on its own: use it for independent signals, not for buses
// whose bits must change together.
module synchronizer #(
    parameter WIDTH = 1
) (
    input wire clk,
    input wire [WIDTH-1:0] data_in,
    output wire [WIDTH-1:0] data_out
);

    reg [WIDTH-1:0] stage1;
    reg [WIDTH-1:0] stage2;

    always @(posedge clk) begin
        stage1 <= data_in;      // may go metastable: never used directly
        stage2 <= stage1;       // settled by the next edge
    end

    assign data_out = stage2;

endmodule
