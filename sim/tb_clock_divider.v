`timescale 1ns/1ps

module tb_clock_divider #(
    parameter DIV_A = 16,    // power of two
              DIV_B = 6     // not a power of two
);
    reg clk_in;
    reg rst_n;
    wire clk_a;
    wire clk_b;

    // Instantiate DUTs (small divisors so the test runs in a few cycles)
    clock_divider #(
        .DIVISOR(DIV_A)
    ) div_a (
        .clk_in(clk_in),
        .rst_n(rst_n),
        .clk_out(clk_a)
    );

    clock_divider #(
        .DIVISOR(DIV_B)
    ) div_b (
        .clk_in(clk_in),
        .rst_n(rst_n),
        .clk_out(clk_b)
    );

    // Clock: 10 ns period
    initial clk_in = 0;
    always #5 clk_in = ~clk_in;

    integer errors;
    integer edges;          // clk_in rising edges since reset was released
    integer i;

    // Expected output after n edges: toggles every DIVISOR/2 edges, starts low
    function expected;
        input integer n;
        input integer divisor;
        begin
            expected = (n / (divisor / 2)) % 2;
        end
    endfunction

    // One clk_in cycle: let the dividers count on the rising edge, then compare
    task tick;
        begin
            @(posedge clk_in);
            #1;
            edges = edges + 1;
            if (clk_a !== expected(edges, DIV_A)) begin
                $display("FAIL DIV=%0d edge=%0d | got %b | expected %b",
                         DIV_A, edges, clk_a, expected(edges, DIV_A));
                errors = errors + 1;
            end
            if (clk_b !== expected(edges, DIV_B)) begin
                $display("FAIL DIV=%0d edge=%0d | got %b | expected %b",
                         DIV_B, edges, clk_b, expected(edges, DIV_B));
                errors = errors + 1;
            end
        end
    endtask

    // Hold reset for one rising edge, release on the falling edge
    task reset;
        begin
            @(negedge clk_in);
            rst_n = 0;
            @(posedge clk_in);
            #1;
            if (clk_a !== 1'b0 || clk_b !== 1'b0) begin
                $display("FAIL reset | got clk_a=%b clk_b=%b | expected 0 0", clk_a, clk_b);
                errors = errors + 1;
            end
            @(negedge clk_in);
            rst_n = 1;
            edges = 0;
        end
    endtask

    initial begin
        $dumpfile("tb_clock_divider.vcd");
        $dumpvars(0, tb_clock_divider);
        errors = 0;
        edges  = 0;
        rst_n  = 0;

        // Power-up reset, then run 3 full periods of the slower clock
        reset;
        for (i = 0; i < 3 * DIV_A; i = i + 1) tick;      // toggle every DIVISOR/2, 50% duty

        // Mid-run reset while both outputs are high
        for (i = 0; i < DIV_A / 2; i = i + 1) tick;      // edge count 4*DIV_A + 4: clk_a high
        reset;                                            // reset wins: both outputs low
        for (i = 0; i < 2 * DIV_A; i = i + 1) tick;      // count restarts from 0

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule
