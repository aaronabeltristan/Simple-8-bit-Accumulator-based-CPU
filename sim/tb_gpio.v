`timescale 1ns/1ps

module tb_gpio #(
    parameter ADDR_WIDTH = 8,
              DATA_WIDTH = 8,
              PIN_ADDR   = 8'h84,
              PORT_ADDR  = 8'h85,
              DDR_ADDR   = 8'h86
);
    reg clk;
    reg rst_n;
    reg write_en;
    reg [ADDR_WIDTH-1:0] addr;
    reg [DATA_WIDTH-1:0] wdata;
    reg [DATA_WIDTH-1:0] pin;
    wire [DATA_WIDTH-1:0] port;
    wire [DATA_WIDTH-1:0] ddr;
    wire [DATA_WIDTH-1:0] rdata;

    // Instantiate DUT (port B addresses)
    gpio #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .PIN_ADDR(PIN_ADDR),
        .PORT_ADDR(PORT_ADDR),
        .DDR_ADDR(DDR_ADDR)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .addr(addr),
        .wdata(wdata),
        .pin(pin),
        .port(port),
        .ddr(ddr),
        .rdata(rdata)
    );

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    integer errors;

    // Write one register: set inputs on the falling edge, write happens on the rising edge
    task write_step;
        input [ADDR_WIDTH-1:0] t_addr;  // task address
        input [DATA_WIDTH-1:0] t_data;  // task write data
        begin
            @(negedge clk);
            write_en = 1;
            addr     = t_addr;
            wdata    = t_data;
            @(posedge clk);
            #1;
            write_en = 0;
        end
    endtask

    // Read one register: rdata follows addr at once, no clock edge needed
    task read_step;
        input [ADDR_WIDTH-1:0] t_addr;  // task address
        input [DATA_WIDTH-1:0] exp_out; // expected rdata
        begin
            @(negedge clk);
            write_en = 0;
            addr     = t_addr;
            #1;
            if (rdata !== exp_out) begin
                $display("FAIL READ addr=%h | got %h | expected %h", t_addr, rdata, exp_out);
                errors = errors + 1;
            end
        end
    endtask

    // PORT and DDR are visible on their outputs at all times
    task check_regs;
        input [DATA_WIDTH-1:0] exp_port; // expected port
        input [DATA_WIDTH-1:0] exp_ddr;  // expected ddr
        begin
            if (port !== exp_port || ddr !== exp_ddr) begin
                $display("FAIL REGS | got port=%h ddr=%h | expected %h %h", port, ddr, exp_port, exp_ddr);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_gpio.vcd");
        $dumpvars(0, tb_gpio);
        errors = 0;

        // All inputs idle, reset held
        rst_n    = 0;
        write_en = 0;
        addr     = 0;
        wdata    = 0;
        pin      = 8'h5A;

        // Reset: PORT and DDR start at 0 (all pins inputs)
        repeat (2) @(posedge clk);
        #1;
        check_regs(8'h00, 8'h00);
        @(negedge clk);
        rst_n = 1;

        // PORT and DDR write and read back
        write_step(PORT_ADDR, 8'h33);               // PORT = 0x33
        write_step(DDR_ADDR,  8'hF0);               // DDR  = 0xF0
        check_regs(8'h33, 8'hF0);                   // visible on the outputs
        read_step(PORT_ADDR, 8'h33);                // PORT reads back
        read_step(DDR_ADDR,  8'hF0);                // DDR reads back

        // PIN follows the pins, write ignored
        read_step(PIN_ADDR, 8'h5A);                 // reads pin = 0x5A
        pin = 8'hA5;
        read_step(PIN_ADDR, 8'hA5);                 // follows the pins live: 0xA5
        write_step(PIN_ADDR, 8'h77);                // write to PIN: ignored
        read_step(PIN_ADDR, 8'hA5);                 // still reads the pins
        check_regs(8'h33, 8'hF0);                   // PORT and DDR unchanged

        // Other addresses: rdata 0x00, writes ignored
        read_step(8'h80, 8'h00);                    // another port's address
        read_step(8'h87, 8'h00);                    // just past this port
        read_step(8'h00, 8'h00);                    // RAM address
        write_step(8'h82, 8'hFF);                   // another port's PORT: ignored
        write_step(8'h00, 8'hFF);                   // RAM address: ignored
        check_regs(8'h33, 8'hF0);                   // unchanged

        // Write enable low: no change
        @(negedge clk);
        write_en = 0;
        addr     = PORT_ADDR;
        wdata    = 8'hEE;
        @(posedge clk);
        #1;
        check_regs(8'h33, 8'hF0);

        // Mid-run reset: PORT and DDR clear
        @(negedge clk);
        rst_n = 0;
        @(posedge clk);
        #1;
        check_regs(8'h00, 8'h00);
        @(negedge clk);
        rst_n = 1;
        read_step(PORT_ADDR, 8'h00);                // reads back 0
        read_step(DDR_ADDR,  8'h00);
        read_step(PIN_ADDR,  8'hA5);                // PIN still follows the pins

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule
