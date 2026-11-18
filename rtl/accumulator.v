`timescale 1ns/1ps

// Holds data for the entire cpu to work
module accumulator #(
    parameter WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire load_en,
    input wire clear_en,
    input wire [WIDTH-1:0] data_in,
    output reg [WIDTH-1:0] data_out
);

    always @(posedge clk) begin
        if (!rst_n || clear_en) data_out <= {WIDTH{1'b0}};
        else if (write_en) data_out <= data_in;
    end

endmodule