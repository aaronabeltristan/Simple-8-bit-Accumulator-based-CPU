`timescale 1ns/1ps

module tb_synchronizer #(
    parameter WIDTH = 8
);
    reg clk;
    reg [WIDTH-1:0] data_in;
    wire [WIDTH-1:0] data_out;

    // Instantiate DUT
    synchronizer #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .data_in(data_in),
        .data_out(data_out)
    );

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    integer errors;

    // One clock: set the input on the falling edge, let both stages update
    // on the rising edge, then compare the output after it settles.
    task sync_step;
        input [WIDTH-1:0] t_in;    // task data in
        input [WIDTH-1:0] exp_out; // expected data out
        begin
            @(negedge clk);
            data_in = t_in;
            @(posedge clk);
            #1;
            if (data_out !== exp_out) begin
                $display("FAIL in=%h | got %h | expected %h", t_in, data_out, exp_out);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_synchronizer.vcd");
        $dumpvars(0, tb_synchronizer);
        errors = 0;

        // No reset: fill both stages with a known value first
        data_in = 0;
        repeat (2) @(posedge clk);
        #1;

        // A new value appears on the output two clock edges later
        sync_step(8'h00, 8'h00);                // settled at 0x00
        sync_step(8'hA5, 8'h00);                // edge 1: in stage 1, output still 0x00
        sync_step(8'hA5, 8'hA5);                // edge 2: reaches the output
        sync_step(8'hA5, 8'hA5);                // holds while the input holds

        // Back-to-back changes keep their order, each delayed by two edges
        sync_step(8'h3C, 8'hA5);                // 0x3C enters, output still 0xA5
        sync_step(8'hC3, 8'h3C);                // 0x3C out, 0xC3 enters
        sync_step(8'hFF, 8'hC3);                // 0xC3 out, 0xFF enters
        sync_step(8'hFF, 8'hFF);                // 0xFF out

        // A one-clock pulse passes through intact, two edges late
        sync_step(8'h00, 8'hFF);                // input drops to 0x00
        sync_step(8'h01, 8'h00);                // pulse on bit 0 enters
        sync_step(8'h00, 8'h01);                // pulse reaches the output for one clock
        sync_step(8'h00, 8'h00);                // pulse over

        // Each bit is independent: only the changed bits change
        sync_step(8'h80, 8'h00);                // bit 7 rises
        sync_step(8'h81, 8'h80);                // bit 7 out, bit 0 rises
        sync_step(8'h01, 8'h81);                // both out, bit 7 falls
        sync_step(8'h01, 8'h01);                // only bit 0 left

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule
