`timescale 1ns/1ps

module instruction_decoder #(
    parameter OPCODE_WIDTH = 4, 
              OPERAND_WIDTH = 8
) (
    input wire [OPCODE_WIDTH + OPERAND_WIDTH - 1:0] data_in,
    output wire [OPCODE_WIDTH-1:0] opcode,
    output wire [OPERAND_WIDTH-1:0] operand
);
    assign {opcode, operand} = data_in;
endmodule