// Combinational ALU: [0] Z flag, [1] C flag (carry on ADD/INC, borrow on SUB/DEC)
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

    localparam ADD = 4'h0, 
               SUB = 4'h1, 
               AND = 4'h2, 
               OR  = 4'h3, 
               NOT = 4'h4, 
               INC = 4'h5, 
               DEC = 4'h6;

    wire [DATA_WIDTH:0] a_ext = {1'b0, A};
    wire [DATA_WIDTH:0] b_ext = {1'b0, B};
    reg [DATA_WIDTH:0] result;

    always @(*) begin
        case (opcode)
            ADD: result = a_ext + b_ext;
            SUB: result = a_ext - b_ext;
            AND: result = {1'b0, A & B};
            OR:  result = {1'b0, A | B};
            NOT: result = {1'b0, ~A};
            INC: result = a_ext + 1'b1;
            DEC: result = a_ext - 1'b1;
            default: result = {(DATA_WIDTH+1){1'b0}};
        endcase
    end

    assign out = result[DATA_WIDTH-1:0];
    assign flags_out[0] = ~|out;
    assign flags_out[1] = result[DATA_WIDTH];

endmodule