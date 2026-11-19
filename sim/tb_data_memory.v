`timescale 1ns/1ps

module tb_data_memory #(
    parameter ADDR_WIDTH = 8,
              DATA_WIDTH = 8
);
    reg clk;
    reg rst_n;
    reg read_en;
    reg write_en;
    reg [ADDR_WIDTH-1:0] addr;
    reg [DATA_WIDTH-1:0] wdata;
    reg [DATA_WIDTH-1:0] input_device;   // PINA
    reg [DATA_WIDTH-1:0] pin_b;          // PINB
    wire [DATA_WIDTH-1:0] rdata;
    wire [DATA_WIDTH-1:0] output_device; // DISPLAY
    wire [DATA_WIDTH-1:0] port_a;
    wire [DATA_WIDTH-1:0] ddr_a;
    wire [DATA_WIDTH-1:0] port_b;
    wire [DATA_WIDTH-1:0] ddr_b;

    // Instantiate DUT
    data_memory #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .read_en(read_en),
        .write_en(write_en),
        .addr(addr),
        .wdata(wdata),
        .input_device(input_device),
        .pin_b(pin_b),
        .rdata(rdata),
        .output_device(output_device),
        .port_a(port_a),
        .ddr_a(ddr_a),
        .port_b(port_b),
        .ddr_b(ddr_b)
    );

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    integer errors;

    // Write one byte: set inputs on the falling edge, write happens on the rising edge
    task write_step;
        input [ADDR_WIDTH-1:0] t_addr;  // task address
        input [DATA_WIDTH-1:0] t_data;  // task write data
        begin
            @(negedge clk);
            write_en = 1;
            read_en  = 0;
            addr     = t_addr;
            wdata    = t_data;
            @(posedge clk);
            #1;
        end
    endtask

    // Read one byte: rdata updates on the rising edge, compare after it settles
    task read_step;
        input                  t_read;  // task read enable
        input [ADDR_WIDTH-1:0] t_addr;  // task address
        input [DATA_WIDTH-1:0] exp_out; // expected rdata
        begin
            @(negedge clk);
            write_en = 0;
            read_en  = t_read;
            addr     = t_addr;
            @(posedge clk);
            #1;
            if (rdata !== exp_out) begin
                $display("FAIL READ read_en=%b addr=%h | got %h | expected %h",
                         t_read, t_addr, rdata, exp_out);
                errors = errors + 1;
            end
        end
    endtask

    // Output register is visible on its port at all times
    task check_out;
        input [DATA_WIDTH-1:0] exp_out; // expected output_device
        begin
            if (output_device !== exp_out) begin
                $display("FAIL OUTPUT | got %h | expected %h", output_device, exp_out);
                errors = errors + 1;
            end
        end
    endtask

    // GPIO registers are visible on their ports at all times
    task check_gpio;
        input [DATA_WIDTH-1:0] exp_port_a; // expected port_a
        input [DATA_WIDTH-1:0] exp_ddr_a;  // expected ddr_a
        input [DATA_WIDTH-1:0] exp_port_b; // expected port_b
        input [DATA_WIDTH-1:0] exp_ddr_b;  // expected ddr_b
        begin
            if (port_a !== exp_port_a || ddr_a !== exp_ddr_a ||
                port_b !== exp_port_b || ddr_b !== exp_ddr_b) begin
                $display("FAIL GPIO | got porta=%h ddra=%h portb=%h ddrb=%h | expected %h %h %h %h",
                         port_a, ddr_a, port_b, ddr_b, exp_port_a, exp_ddr_a, exp_port_b, exp_ddr_b);
                errors = errors + 1;
            end
        end
    endtask

    // rdata and every I/O register must read 0 after reset
    task check_reset;
        begin
            if (rdata !== 0 || output_device !== 0 ||
                port_a !== 0 || ddr_a !== 0 || port_b !== 0 || ddr_b !== 0) begin
                $display("FAIL RESET | got rdata=%h output=%h porta=%h ddra=%h portb=%h ddrb=%h | expected all 0",
                         rdata, output_device, port_a, ddr_a, port_b, ddr_b);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_data_memory.vcd");
        $dumpvars(0, tb_data_memory);
        errors = 0;

        // All inputs idle, reset held
        rst_n        = 0;
        read_en      = 0;
        write_en     = 0;
        addr         = 0;
        wdata        = 0;
        input_device = 8'h3C;
        pin_b        = 8'h5A;

        // Reset: hold for 2 clocks, check, then release on a falling edge
        repeat (2) @(posedge clk);
        #1;
        check_reset;                                // rdata and every I/O register start at 0
        @(negedge clk);
        rst_n = 1;

        // RAM write and read back
        write_step(8'h00, 8'h5A);                   // RAM[0x00] = 0x5A
        read_step(1'b1, 8'h00, 8'h5A);              // read back 0x5A

        // RAM on both sides of the I/O addresses, and the top of memory
        write_step(8'h7F, 8'h11);                   // RAM[0x7F] = 0x11 (just below I/O)
        write_step(8'h88, 8'h22);                   // RAM[0x88] = 0x22 (just above the I/O block)
        write_step(8'hFF, 8'h33);                   // RAM[0xFF] = 0x33 (last address)
        read_step(1'b1, 8'h7F, 8'h11);              // read 0x7F
        read_step(1'b1, 8'h88, 8'h22);              // read 0x88
        read_step(1'b1, 8'hFF, 8'h33);              // read 0xFF

        // Input device at 0x80
        read_step(1'b1, 8'h80, 8'h3C);              // reads input_device = 0x3C
        input_device = 8'hC3;
        read_step(1'b1, 8'h80, 8'hC3);              // follows the input live: 0xC3
        write_step(8'h80, 8'h99);                   // write to input: ignored
        read_step(1'b1, 8'h80, 8'hC3);              // still reads input_device, not 0x99

        // Output device at 0x81
        write_step(8'h81, 8'hA5);                   // output register = 0xA5
        check_out(8'hA5);                           // visible on output_device port
        read_step(1'b1, 8'h81, 8'hA5);              // readable back at 0x81
        check_out(8'hA5);                           // reading does not change it

        // GPIO registers at 0x82-0x86
        write_step(8'h82, 8'h0F);                   // PORTA = 0x0F
        write_step(8'h83, 8'hF0);                   // DDRA  = 0xF0
        write_step(8'h85, 8'h33);                   // PORTB = 0x33
        write_step(8'h86, 8'hCC);                   // DDRB  = 0xCC
        check_gpio(8'h0F, 8'hF0, 8'h33, 8'hCC);     // all four visible on their ports
        read_step(1'b1, 8'h82, 8'h0F);              // PORTA reads back
        read_step(1'b1, 8'h83, 8'hF0);              // DDRA reads back
        read_step(1'b1, 8'h85, 8'h33);              // PORTB reads back
        read_step(1'b1, 8'h86, 8'hCC);              // DDRB reads back
        check_out(8'hA5);                           // GPIO writes leave DISPLAY alone

        // PINB at 0x84 (read only)
        read_step(1'b1, 8'h84, 8'h5A);              // reads pin_b = 0x5A
        pin_b = 8'hA5;
        read_step(1'b1, 8'h84, 8'hA5);              // follows the pins live: 0xA5
        write_step(8'h84, 8'h77);                   // write to PINB: ignored
        read_step(1'b1, 8'h84, 8'hA5);              // still reads the pins
        check_gpio(8'h0F, 8'hF0, 8'h33, 8'hCC);     // and no GPIO register changed

        // Reserved 0x87 and the RAM underneath the I/O block
        write_step(8'h87, 8'h66);                   // write to reserved: ignored
        read_step(1'b1, 8'h87, 8'h00);              // reads 0x00
        read_step(1'b1, 8'h7F, 8'h11);              // RAM below the block unchanged
        read_step(1'b1, 8'h88, 8'h22);              // RAM above the block unchanged

        // Read disabled
        read_step(1'b0, 8'h00, 8'h00);              // read_en low: rdata = 0
        read_step(1'b1, 8'h00, 8'h5A);              // RAM[0x00] still 0x5A

        // Mid-run reset: output register clears, RAM keeps its contents
        @(negedge clk);
        rst_n    = 0;
        write_en = 0;
        read_en  = 0;
        @(posedge clk);
        #1;
        check_reset;                                // rdata and every I/O register back to 0
        @(negedge clk);
        rst_n = 1;

        check_out(8'h00);                           // output stays 0 after reset
        read_step(1'b1, 8'h00, 8'h5A);              // RAM[0x00] survived reset
        read_step(1'b1, 8'hFF, 8'h33);              // RAM[0xFF] survived reset

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule