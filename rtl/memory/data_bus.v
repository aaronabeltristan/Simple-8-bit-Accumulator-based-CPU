`timescale 1ns/1ps

// Data Bus: connects the CPU's data port to the RAM and to the I/O block at 0x80-0x8F.
//
//   Address       Register   Read (LD)                    Write (STE)
//   0x80          PINA       port A pin levels            ignored (read only)
//   0x81          OUT        output_device register       updates output_device (onboard LEDs)
//   0x82          PORTA      port A output register       updates port_a
//   0x83          DDRA       port A direction register    updates ddr_a (1 = output, 0 = input)
//   0x84          PINB       port B pin levels            ignored (read only)
//   0x85          PORTB      port B output register       updates port_b
//   0x86          DDRB       port B direction register    updates ddr_b (1 = output, 0 = input)
//   0x87          PINC       port C pin levels            ignored (read only)
//   0x88          PORTC      port C output register       updates port_c
//   0x89          DDRC       port C direction register    updates ddr_c (1 = output, 0 = input)
//   0x8A-0x8F     reserved   0x00                         ignored
//   all others    RAM        RAM                          RAM
//
// Each I/O module decodes its own addresses and returns 0x00 for any other address,
// so the I/O read data is the OR of all modules. A new peripheral (timer, UART) is
// added the same way: one instance with its addresses, and one more term in io_rdata.
//
// Reads and writes happen on the rising clock edge.
// rdata is 0x00 when read_en is low.
// Reset clears rdata and every I/O register (all GPIO pins start as inputs); RAM contents are not reset.
module data_bus #(
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
    input wire [DATA_WIDTH-1:0] pin_c,             // PINC: port C pin levels
    output reg [DATA_WIDTH-1:0] rdata,
    output reg [DATA_WIDTH-1:0] output_device,     // OUT register
    output wire [DATA_WIDTH-1:0] port_a,
    output wire [DATA_WIDTH-1:0] ddr_a,
    output wire [DATA_WIDTH-1:0] port_b,
    output wire [DATA_WIDTH-1:0] ddr_b,
    output wire [DATA_WIDTH-1:0] port_c,
    output wire [DATA_WIDTH-1:0] ddr_c
);

    localparam IO_FIRST = 8'h80,
               OUT_ADDR = 8'h81,
               IO_LAST  = 8'h8F;

    wire is_io = (addr >= IO_FIRST) && (addr <= IO_LAST);   // I/O block, not RAM

    wire [DATA_WIDTH-1:0] ram_rdata;
    wire [DATA_WIDTH-1:0] gpio_a_rdata;
    wire [DATA_WIDTH-1:0] gpio_b_rdata;
    wire [DATA_WIDTH-1:0] gpio_c_rdata;
    wire [DATA_WIDTH-1:0] out_rdata;
    wire [DATA_WIDTH-1:0] io_rdata;

    // RAM: every address outside the I/O block
    data_memory #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_ram (
        .clk(clk),
        .write_en(write_en && !is_io),
        .addr(addr),
        .wdata(wdata),
        .rdata(ram_rdata)
    );

    // GPIO port A: PINA 0x80, PORTA 0x82, DDRA 0x83
    gpio #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .PIN_ADDR(8'h80),
        .PORT_ADDR(8'h82),
        .DDR_ADDR(8'h83)
    ) u_gpio_a (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .addr(addr),
        .wdata(wdata),
        .pin(input_device),
        .port(port_a),
        .ddr(ddr_a),
        .rdata(gpio_a_rdata)
    );

    // GPIO port B: PINB 0x84, PORTB 0x85, DDRB 0x86
    gpio #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .PIN_ADDR(8'h84),
        .PORT_ADDR(8'h85),
        .DDR_ADDR(8'h86)
    ) u_gpio_b (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .addr(addr),
        .wdata(wdata),
        .pin(pin_b),
        .port(port_b),
        .ddr(ddr_b),
        .rdata(gpio_b_rdata)
    );

    // GPIO port C: PINC 0x87, PORTC 0x88, DDRC 0x89
    gpio #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .PIN_ADDR(8'h87),
        .PORT_ADDR(8'h88),
        .DDR_ADDR(8'h89)
    ) u_gpio_c (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .addr(addr),
        .wdata(wdata),
        .pin(pin_c),
        .port(port_c),
        .ddr(ddr_c),
        .rdata(gpio_c_rdata)
    );

    // OUT register at 0x81: the original output device, shown on the onboard LEDs
    always @(posedge clk) begin
        if (!rst_n) output_device <= {DATA_WIDTH{1'b0}};
        else if (write_en && addr == OUT_ADDR) output_device <= wdata;
    end

    assign out_rdata = (addr == OUT_ADDR) ? output_device : {DATA_WIDTH{1'b0}};

    // I/O read data: each module is 0x00 unless addressed; reserved 0x8A-0x8F read 0x00
    assign io_rdata = gpio_a_rdata | gpio_b_rdata | gpio_c_rdata | out_rdata;

    // Reads: I/O block or RAM, registered; 0x00 when read_en is low
    always @(posedge clk) begin
        if (!rst_n) rdata <= {DATA_WIDTH{1'b0}};

        else if (read_en) rdata <= is_io ? io_rdata : ram_rdata;

        else rdata <= {DATA_WIDTH{1'b0}};
    end

endmodule
