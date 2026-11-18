`timescale 1ns/1ps

// N-to-1 MUX: out = input[sel]. Inputs packed as {in[N-1], ..., in[0]}; out = 0 if sel >= N..
module nto1mux #(
    parameter N=4, 
              WIDTH=8
) (
    input wire [N*WIDTH-1:0] in, 
    input wire [$clog2(N)-1:0] sel,
    output wire [WIDTH-1:0] out
);
    assign out = (sel < N) ? in[sel*WIDTH +: WIDTH] : {WIDTH{1'b0}};  
endmodule