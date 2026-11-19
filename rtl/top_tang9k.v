`timescale 1ns/1ps

// Board top level for the Sipeed Tang Nano 9K (GW1NR-9).
// 27 MHz board clock -> clock_divider -> CPU clock (2 Hz by default).
// S1 resets the CPU, the LEDs show output_device[5:0] (address 0x81).
module top_tang9k #(
    parameter DIVISOR = 1_350_000,             // 27 MHz / 13.5M = 2 Hz CPU clock
              PROGRAM = "../../programs/test_a.hex"
) (
    input wire clk,                             // 27 MHz board clock
    input wire btn_rst_n,                       // S1, low when pressed
    output wire [5:0] led                       // active-low LEDs
);

    wire cpu_clk;
    wire [7:0] output_device;

    reg [1:0] rst_sync;                         // reset synchronizer (CPU clock domain)

    // CPU clock: never reset, so cpu_clk keeps running while S1 is held
    clock_divider #(
        .DIVISOR(DIVISOR)
    ) u_clk (
        .clk_in(clk),
        .rst_n(1'b1),
        .clk_out(cpu_clk)
    );

    // Bring the button into the CPU clock domain through two flip-flops
    always @(posedge cpu_clk) begin
        rst_sync <= {rst_sync[0], btn_rst_n};
    end

    cpu #(
        .PROGRAM(PROGRAM)
    ) u_cpu (
        .clk(cpu_clk),
        .rst_n(rst_sync[1]),
        .input_device(8'h0A),                   // no switches on the board
        .output_device(output_device),
        .pc(),
        .ir(),
        .acc(),
        .flags(),
        .state()
    );

    assign led = ~output_device[5:0];           // LEDs are active-low

endmodule