// lfsr.v -- parameterized Fibonacci LFSR, advances 4 bits per step.
//
// TA feedback addressed here: the two dice use DIFFERENT feedback
// polynomials (and even different widths), not just different seeds.
// Same-taps LFSRs produce the same sequence shifted in time.
//
// Why 4 bits per step (not 3): the LFSR state cycles through all
// 2^WIDTH-1 nonzero states. Stepping by k visits them in cycles of
// length (2^WIDTH-1)/gcd(k, 2^WIDTH-1). 2^WIDTH-1 is divisible by 3
// for even WIDTH, so stepping by 3 would cut the period by 3x.
// gcd(4, odd) = 1, so stepping by 4 keeps the full period.
//
// Plain Verilog-2001. No SystemVerilog required.

module lfsr #(
    parameter          WIDTH = 24,
    parameter [31:0]   TAPS  = 32'h00E10000,  // XOR mask of tap bits
    parameter [31:0]   SEED  = 32'h005A5A5A   // must be nonzero
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       step,      // advance 4 bits this cycle
    output wire [2:0] rand3      // low 3 bits of state = one raw draw
);

    reg [WIDTH-1:0] state;

    // one Fibonacci step: shift left, feedback = XOR of tapped bits
    function [WIDTH-1:0] next1(input [WIDTH-1:0] s);
        begin
            next1 = {s[WIDTH-2:0], ^(s & TAPS[WIDTH-1:0])};
        end
    endfunction

    wire [WIDTH-1:0] n1 = next1(state);
    wire [WIDTH-1:0] n2 = next1(n1);
    wire [WIDTH-1:0] n3 = next1(n2);
    wire [WIDTH-1:0] n4 = next1(n3);

    always @(posedge clk) begin
        if (rst)
            state <= SEED[WIDTH-1:0];
        else if (step)
            state <= n4;
    end

    assign rand3 = state[2:0];

endmodule
