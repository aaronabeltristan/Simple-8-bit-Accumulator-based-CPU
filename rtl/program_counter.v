`timescale 1ns/1ps

module program_counter #(
    parameter WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire inc_en,
    input wire load_en,
    input wire [WIDTH-1:0] data_in,
    output reg [WIDTH-1:0] data_out
);

    always @(posedge clk) begin
        if (!rst_n) data_out <= {WIDTH{1'b0}};
        else if (load_en) data_out <= data_in;
        else if (inc_en) data_out <= data_out + 1'b1;
    end
    
endmodule