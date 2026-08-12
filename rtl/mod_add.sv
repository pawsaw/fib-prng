// mod_add.sv
// Arbitrary-modulus adder used by the (M)AFG generators in the dissertation.
//
// Implements the hardware "mod m" trick from equations (3.1)/(3.6):
//
//     A    = 2**WIDTH - MOD               (compile-time constant)
//     s1   = (sum_in)   mod 2**WIDTH,  c1 = carry out of that add
//     s2   = (s1 + A)   mod 2**WIDTH,  c2 = carry out of that add
//     out  = (c1 == 0 && c2 == 0) ? s1 : s2
//
// This yields (sum_in mod MOD) for any MOD with 2**WIDTH > MOD, without an
// explicit divider. sum_in is the already-summed set of tap/feedback terms.
//
// The two carries drive the OR gate + multiplexer (MUX) described in the text:
// no carry on either adder  -> pass the first adder's result (AD1),
// otherwise                 -> pass the corrected result (AD2 = AD1 + A).

`default_nettype none

module mod_add #(
    parameter int unsigned WIDTH = 8,
    parameter int unsigned MOD   = 3
) (
    // sum_in may be up to a few WIDTH-bit terms added together, so give it head-room.
    input  wire [WIDTH+1:0]   sum_in,
    output logic [WIDTH-1:0]  out
);
    localparam logic [WIDTH:0] A = (WIDTH+1)'((1 << WIDTH) - MOD);

    wire [WIDTH-1:0] s1 = sum_in[WIDTH-1:0];      // sum_in mod 2**WIDTH
    wire             c1 = |sum_in[WIDTH+1:WIDTH]; // sum_in >= 2**WIDTH ?
    wire [WIDTH:0]   s2 = {1'b0, s1} + A;         // conditional subtract of MOD
    wire             c2 = s2[WIDTH];

    assign out = (!c1 && !c2) ? s1 : s2[WIDTH-1:0];
endmodule

`default_nettype wire
