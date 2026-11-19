`timescale 1ns/1ps

// Board top level for the Sipeed Tang Nano 9K (GW1NR-9).
//   Clock   : 27 MHz board clock, used directly (DIVISOR = 1) or divided by clock_divider
//   Reset   : S1, synchronized to the CPU clock
//   GPIO    : two 8-bit ports (A, B); each pin is an input or an output, chosen by DDRA/DDRB
//             PINA 0x80, PORTA 0x82, DDRA 0x83, PINB 0x84, PORTB 0x85, DDRB 0x86
//   Display : DISPLAY register (0x81) -> 4-digit 7-segment display (decimal, 5641BS)
//                                     -> 6 onboard LEDs (binary)
module top_tang9k #(
    parameter DIVISOR = 1,                      // 1 = CPU runs at 27 MHz, else 27 MHz / DIVISOR
                    PROGRAM = "../../acc8c/out/press.hex"
) (
    input wire clk,                             // 27 MHz board clock
    input wire btn_rst_n,                       // S1, low when pressed
    inout wire [7:0] gpio_a,                    // GPIO port A pins
    inout wire [7:0] gpio_b,                    // GPIO port B pins
    output wire [5:0] led,                      // onboard LEDs, active-low
    output wire [7:0] seg,                      // 7-segment {dp, g, f, e, d, c, b, a}, active-low
    output wire [3:0] dig                       // digit select {DIG4 .. DIG1}, active-low (PNP)
);

    wire cpu_clk;
    wire cpu_rst_n;                             // S1, synchronized to cpu_clk
    wire [7:0] pin_a, pin_b;                    // GPIO pin levels, synchronized to cpu_clk
    wire [7:0] port_a, ddr_a, port_b, ddr_b;    // GPIO registers from data memory
    wire [7:0] output_device;                   // DISPLAY register

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
        .WIDTH(16)
    ) u_gpio_sync (
        .clk(cpu_clk),
        .data_in({gpio_b, gpio_a}),             // pin levels, whether input or output
        .data_out({pin_b, pin_a})
    );

    cpu #(
        .PROGRAM(PROGRAM)
    ) u_cpu (
        .clk(cpu_clk),
        .rst_n(cpu_rst_n),
        .input_device(pin_a),                   // PINA
        .pin_b(pin_b),                          // PINB
        .output_device(output_device),          // DISPLAY
        .port_a(port_a),
        .ddr_a(ddr_a),
        .port_b(port_b),
        .ddr_b(ddr_b),
        .pc(),
        .ir(),
        .acc(),
        .flags(),
        .state()
    );

    // 4-digit 7-segment display: shows the DISPLAY register in decimal
    seven_seg_display #(
        .CLK_HZ(27_000_000)
    ) u_display (
        .clk(clk),                              // board clock, so the scan never depends on DIVISOR
        .value(output_device),
        .seg(seg),
        .dig(dig)
    );

    assign led = ~output_device[5:0];           // onboard LEDs are active-low

endmodule
