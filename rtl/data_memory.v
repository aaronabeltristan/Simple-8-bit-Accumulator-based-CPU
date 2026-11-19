`timescale 1ns/1ps

// Data Memory: 256 x 8-bit, synchronous, with a memory-mapped I/O block at 0x80-0x87.
//
//   Address       Register   Read (LD)                    Write (STE)
//   0x80          PINA       port A pin levels            ignored (read only)
//   0x81          DISPLAY    output_device register       updates output_device (7-segment display)
//   0x82          PORTA      port A output register       updates port_a
//   0x83          DDRA       port A direction register    updates ddr_a (1 = output, 0 = input)
//   0x84          PINB       port B pin levels            ignored (read only)
//   0x85          PORTB      port B output register       updates port_b
//   0x86          DDRB       port B direction register    updates ddr_b (1 = output, 0 = input)
//   0x87          reserved   0x00                         ignored
//   all others    RAM        RAM                          RAM
//
// Reads and writes happen on the rising clock edge.
// rdata is 0x00 when read_en is low.
// Reset clears rdata and every I/O register (all GPIO pins start as inputs); RAM contents are not reset.
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
    input wire [DATA_WIDTH-1:0] input_device,      // PINA: port A pin levels
    input wire [DATA_WIDTH-1:0] pin_b,             // PINB: port B pin levels
    output reg [DATA_WIDTH-1:0] rdata,
    output reg [DATA_WIDTH-1:0] output_device,     // DISPLAY register
    output reg [DATA_WIDTH-1:0] port_a,
    output reg [DATA_WIDTH-1:0] ddr_a,
    output reg [DATA_WIDTH-1:0] port_b,
    output reg [DATA_WIDTH-1:0] ddr_b
);

    localparam DEPTH      = 1 << ADDR_WIDTH,
               PINA_ADDR  = 8'h80,
               DISP_ADDR  = 8'h81,
               PORTA_ADDR = 8'h82,
               DDRA_ADDR  = 8'h83,
               PINB_ADDR  = 8'h84,
               PORTB_ADDR = 8'h85,
               DDRB_ADDR  = 8'h86,
               IO_LAST    = 8'h87;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    wire is_io = (addr >= PINA_ADDR) && (addr <= IO_LAST);   // I/O block, not RAM

    // Writes: RAM (all addresses outside the I/O block) and the I/O registers
    always @(posedge clk) begin
        if (write_en && !is_io) mem[addr] <= wdata;

        if (!rst_n) begin
            output_device <= 8'h00;
            port_a        <= 8'h00;
            ddr_a         <= 8'h00;                         // all pins start as inputs
            port_b        <= 8'h00;
            ddr_b         <= 8'h00;
        end
        else if (write_en) begin
            case (addr)
                DISP_ADDR:  output_device <= wdata;
                PORTA_ADDR: port_a        <= wdata;
                DDRA_ADDR:  ddr_a         <= wdata;
                PORTB_ADDR: port_b        <= wdata;
                DDRB_ADDR:  ddr_b         <= wdata;
                default: ;                                  // RAM, PINA, PINB, reserved
            endcase
        end
    end

    // Reads: I/O registers inside the I/O block, else RAM; 0x00 when read_en is low
    always @(posedge clk) begin
        if (!rst_n) rdata <= 8'h00;

        else if (read_en) begin
            case (addr)
                PINA_ADDR:  rdata <= input_device;
                DISP_ADDR:  rdata <= output_device;
                PORTA_ADDR: rdata <= port_a;
                DDRA_ADDR:  rdata <= ddr_a;
                PINB_ADDR:  rdata <= pin_b;
                PORTB_ADDR: rdata <= port_b;
                DDRB_ADDR:  rdata <= ddr_b;
                IO_LAST:    rdata <= 8'h00;                 // reserved
                default:    rdata <= mem[addr];
            endcase
        end

        else rdata <= {DATA_WIDTH{1'b0}};
    end

endmodule
