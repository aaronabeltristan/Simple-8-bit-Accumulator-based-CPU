`timescale 1ns/1ps

// GPIO port: one general-purpose I/O port with three memory-mapped registers.
//
//   Address     Register   Read (LD)                    Write (STE)
//   PIN_ADDR    PIN        pin levels                   ignored (read only)
//   PORT_ADDR   PORT       output register              updates port (driven on output pins)
//   DDR_ADDR    DDR        direction register           updates ddr (1 = output, 0 = input)
//
// Writes happen on the rising clock edge.
// rdata shows the addressed register at once, and 0x00 for any other address,
// so the data bus can OR together the rdata of every I/O module.
// Reset clears PORT and DDR: all pins start as inputs.
module gpio #(
    parameter ADDR_WIDTH = 8,
              DATA_WIDTH = 8,
              PIN_ADDR   = 8'h80,
              PORT_ADDR  = 8'h82,
              DDR_ADDR   = 8'h83
) (
    input wire clk,
    input wire rst_n,
    input wire write_en,
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] wdata,
    input wire [DATA_WIDTH-1:0] pin,            // pin levels (synchronized)
    output reg [DATA_WIDTH-1:0] port,           // output values
    output reg [DATA_WIDTH-1:0] ddr,            // direction, 1 = output
    output reg [DATA_WIDTH-1:0] rdata
);

    // Writes: PORT and DDR only; PIN is read only
    always @(posedge clk) begin
        if (!rst_n) begin
            port <= {DATA_WIDTH{1'b0}};
            ddr  <= {DATA_WIDTH{1'b0}};             // all pins start as inputs
        end
        else if (write_en) begin
            case (addr)
                PORT_ADDR: port <= wdata;
                DDR_ADDR:  ddr  <= wdata;
                default: ;                          // PIN and other addresses
            endcase
        end
    end

    // Reads: the addressed register, 0x00 for any other address
    always @(*) begin
        case (addr)
            PIN_ADDR:  rdata = pin;
            PORT_ADDR: rdata = port;
            DDR_ADDR:  rdata = ddr;
            default:   rdata = {DATA_WIDTH{1'b0}};
        endcase
    end

endmodule
