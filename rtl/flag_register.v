// Flag Register: holds the CPU status flags.
//   [0] Z - Zero
//   [1] C - Carry

module flag_register #(parameter WIDTH = 2) (
    input wire clk,
    input wire rst_n,
    input wire load_en,
    input wire clear_en,
    input wire [WIDTH-1:0] data_in,
    output reg [WIDTH-1:0] data_out
);

    always @(posedge clk) begin
        if (!rst_n || clear_en) data_out <= {WIDTH{1'b0}};
        else if (load_en) data_out <= data_in;
    end
    
endmodule