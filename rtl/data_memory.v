`timescale 1ns/1ps

// Data Memory: 256 x 8-bit, synchronous, with memory-mapped I/O.
//
//   Address       Read (LD)                Write (STE)
//   0x80          input_device             ignored (read only)
//   0x81          output_device register   updates output_device
//   all others    RAM                      RAM
//
// Reads and writes happen on the rising clock edge.
// rdata is 0x00 when read_en is low.
// Reset clears output_device and rdata only; RAM contents are not reset.
module data_memory #(
    parameter ADDR_WIDTH = 8,
              DATA_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire read_en,
    input wire write_en,
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] wdata,
    input wire [DATA_WIDTH-1:0] input_device,
    output reg [DATA_WIDTH-1:0] rdata,
    output reg [DATA_WIDTH-1:0] output_device
);

    localparam DEPTH    = 1 << ADDR_WIDTH,
               IN_ADDR  = 8'h80,
               OUT_ADDR = 8'h81;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Writes: RAM (all addresses except I/O) and output register (0x81)
    always @(posedge clk) begin
        if (write_en && addr != IN_ADDR && addr != OUT_ADDR) mem[addr] <= wdata;

        if (!rst_n) output_device <= 8'h00;
        else if (write_en && addr == OUT_ADDR) output_device <= wdata;
    end

    // Reads: input (0x80), output register (0x81), else RAM; 0x00 when read_en is low
    always @(posedge clk) begin
        if (!rst_n) rdata <= 8'h00;
        
        else if (read_en) begin
            if (addr == IN_ADDR) rdata <= input_device;
            else if (addr == OUT_ADDR) rdata <= output_device;
            else rdata <= mem[addr];
        end

        else rdata <= {DATA_WIDTH{1'b0}};
    end
    
endmodule