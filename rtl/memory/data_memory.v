`timescale 1ns/1ps

// Data Memory: 256 x 8-bit RAM.
// Writes happen on the rising clock edge when write_en is high.
// Reads are asynchronous: rdata always shows the byte at addr (data_bus registers it for the CPU).
// RAM contents are not reset.
module data_memory #(
    parameter ADDR_WIDTH = 8,
              DATA_WIDTH = 8
) (
    input wire clk,
    input wire write_en,
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] wdata,
    output wire [DATA_WIDTH-1:0] rdata
);

    localparam DEPTH = 1 << ADDR_WIDTH;     // 1 << 8 is 256 bytes

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (write_en) mem[addr] <= wdata;
    end

    assign rdata = mem[addr];

endmodule
