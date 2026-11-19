`timescale 1ns/1ps

// Combinational ALU: [0] Z flag, [1] C flag (carry on ADD/ADDI, borrow on SUB/SUBI)
// Memory (0x0-0x3) and immediate (0x4-0x7) forms share the same operation; B is chosen outside the ALU
module alu #(
    parameter OPCODE_WIDTH = 4, 
              DATA_WIDTH = 8, 
              FLAG_WIDTH = 2
) (
    input wire [OPCODE_WIDTH-1:0] opcode,
    input wire [DATA_WIDTH-1:0] A,
    input wire [DATA_WIDTH-1:0] B,
    output wire [DATA_WIDTH-1:0] out,
    output wire [FLAG_WIDTH-1:0] flags_out
);

    localparam ADD  = 4'h0, 
               SUB  = 4'h1, 
               AND  = 4'h2, 
               OR   = 4'h3, 
               ADDI = 4'h4, 
               SUBI = 4'h5, 
               ANDI = 4'h6, 
               ORI  = 4'h7, 
               NOT  = 4'hD;

    wire [DATA_WIDTH:0] a_ext = {1'b0, A};
    wire [DATA_WIDTH:0] b_ext = {1'b0, B};
    reg [DATA_WIDTH:0] result;

    always @(*) begin
        case (opcode)
            ADD, ADDI: result = a_ext + b_ext;
            SUB, SUBI: result = a_ext - b_ext;
            AND, ANDI: result = {1'b0, A & B};
            OR,  ORI:  result = {1'b0, A | B};
            NOT:       result = {1'b0, ~A};
            default: result = {(DATA_WIDTH+1){1'b0}};
        endcase
    end

    assign out = result[DATA_WIDTH-1:0];
    assign flags_out[0] = ~|out;
    assign flags_out[1] = result[DATA_WIDTH];

endmodule