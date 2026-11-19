`timescale 1ns/1ps

// Board top level for the Sipeed Tang Nano 9K (GW1NR-9).
//   Clock : 27 MHz board clock, used directly (DIVISOR = 1) or divided by clock_divider
//   Reset : S1, synchronized to the CPU clock
//   GPIO  : three 8-bit ports (A, B, C); each pin is an input or an output, chosen by DDRx
//           PINA 0x80, PORTA 0x82, DDRA 0x83
//           PINB 0x84, PORTB 0x85, DDRB 0x86
//           PINC 0x87, PORTC 0x88, DDRC 0x89
//   LEDs  : OUT register (0x81) -> 6 onboard LEDs (binary)
module top_tang9k #(
    parameter DIVISOR = 1,                      // 1 = CPU runs at 27 MHz, else 27 MHz / DIVISOR
              PROGRAM = "../../acc8c/out/multiplex.hex"
) (
    input wire clk,                             // 27 MHz board clock
    input wire btn_rst_n,                       // S1, low when pressed
    inout wire [7:0] gpio_a,                    // GPIO port A pins (3.3 V)
    inout wire [7:0] gpio_b,                    // GPIO port B pins (1.8 V)
    inout wire [7:0] gpio_c,                    // GPIO port C pins (3.3 V)
    output wire [5:0] led                       // onboard LEDs, active-low
);

    wire cpu_clk;
    wire cpu_rst_n;                             // S1, synchronized to cpu_clk
    wire [7:0] pin_a, pin_b, pin_c;             // GPIO pin levels, synchronized to cpu_clk
    wire [7:0] port_a, ddr_a;                   // GPIO registers from data memory
    wire [7:0] port_b, ddr_b;
    wire [7:0] port_c, ddr_c;
    wire [7:0] output_device;                   // OUT register

    // CPU clock: the board clock directly when DIVISOR = 1, otherwise divided
    generate
        if (DIVISOR == 1) begin : g_full_speed
            assign cpu_clk = clk;
        end else begin : g_divided
            clock_divider #(
                .DIVISOR(DIVISOR)
            ) u_clk (
                .clk_in(clk),
                .rst_n(1'b1),                   // never reset, so cpu_clk keeps running while S1 is held
                .clk_out(cpu_clk)
            );
        end
    endgenerate

    // GPIO pins: drive PORTx where DDRx = 1, release (high-impedance) where DDRx = 0
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : g_gpio
            assign gpio_a[i] = ddr_a[i] ? port_a[i] : 1'bz;
            assign gpio_b[i] = ddr_b[i] ? port_b[i] : 1'bz;
            assign gpio_c[i] = ddr_c[i] ? port_c[i] : 1'bz;
        end
    endgenerate

    // Bring the asynchronous inputs into the CPU clock domain
    synchronizer #(
        .WIDTH(1)
    ) u_rst_sync (
        .clk(cpu_clk),
        .data_in(btn_rst_n),
        .data_out(cpu_rst_n)
    );

    synchronizer #(
        .WIDTH(24)
    ) u_gpio_sync (
        .clk(cpu_clk),
        .data_in({gpio_c, gpio_b, gpio_a}),     // pin levels, whether input or output
        .data_out({pin_c, pin_b, pin_a})
    );

    cpu #(
        .PROGRAM(PROGRAM)
    ) u_cpu (
        .clk(cpu_clk),
        .rst_n(cpu_rst_n),
        .input_device(pin_a),                   // PINA
        .pin_b(pin_b),                          // PINB
        .pin_c(pin_c),                          // PINC
        .output_device(output_device),          // OUT
        .port_a(port_a),
        .ddr_a(ddr_a),
        .port_b(port_b),
        .ddr_b(ddr_b),
        .port_c(port_c),
        .ddr_c(ddr_c),
        .pc(),
        .ir(),
        .acc(),
        .flags(),
        .state()
    );

    assign led = ~output_device[5:0];           // onboard LEDs are active-low

endmodule
