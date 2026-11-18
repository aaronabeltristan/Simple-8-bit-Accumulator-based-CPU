`timescale 1ns/1ps

module instruction_memory #(
    parameter ADDR_WIDTH = 8,
              DATA_WIDTH = 12,
              PROGRAM = "programs/test_a.hex"
) (
    input wire [ADDR_WIDTH-1:0] addr,
    output wire [DATA_WIDTH-1:0] data_out
);
    localparam DEPTH = 1 << ADDR_WIDTH; // 1 << 8 is 256 values
    
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    integer i;

    // Initialize memory with halt code: 12'hE01, then load the program
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = 12'hE01;
        end

        $readmemh(PROGRAM, mem);
    end   

    assign data_out = mem[addr];
endmodule