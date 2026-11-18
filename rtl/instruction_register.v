// Holds the instruction from Instruction Memory whose register field consists of:
// 12 bits: opcode for [11:8] and operand for [7:0]
// The operand is an data memory address, immediate value, or an option bit depending on the opcode

module instruction_register #(
    parameter WIDTH = 12
) (
    input wire clk,
    input wire rst_n,
    input wire load_en,
    input wire [WIDTH-1:0] data_in,
    output reg [WIDTH-1:0] data_out
);

    always @(posedge clk) begin
        if (!rst_n) data_out <= {WIDTH{1'b0}};
        else if (load_en) data_out <= data_in;
    end
    
endmodule