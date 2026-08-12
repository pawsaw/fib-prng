// fib_prng.sv
// Combined pseudo-random bit-sequence generator from the dissertation
// (Sawicki, Opole 2026), Section 2.3 / 4.3 (IEEE Access 2025 design).
//
//   bdi = bi XOR di
//
//   MAFG1: primitive polynomial (x^32 + x^5 + 2) over GF(3)
//          recurrence  x_i = (x_{i-32} + x_{i-5}) mod 3        (no LS term)
//          -> maximal period 3^32 - 1 for every seed (no "weak keys"),
//             but odd modulus gives a slightly biased bit stream (bi).
//
//   MAFG2: primitive polynomial (y^20 + y^3 + 1), modulus s = MOD2
//          recurrence  y_i = (y_{i-20} + y_{i-3} + hhh) mod s   (with LS term)
//          hhh = h0 XOR h_k  (bits of RG1) -> uniform bit stream (di).
//
// XORing a max-period-but-biased stream (bi) with a uniform stream (di) yields
// a uniform, long-period output bdi (proof sketched on p.39 of the spec).

`default_nettype none

module fib_prng #(
    // ---- MAFG1 (GF(3), guarantees period, no LS) ----------------------------
    parameter int unsigned N1     = 32,
    parameter int unsigned MOD1   = 3,
    parameter int unsigned LAG1_A = 32,
    parameter int unsigned LAG1_B = 5,
    // ---- MAFG2 (uniform distribution via LS logic circuit) ------------------
    parameter int unsigned N2      = 20,
    parameter int unsigned MOD2    = 8,          // s (modulus of MAFG2)
    parameter int unsigned LAG2_A  = 20,
    parameter int unsigned LAG2_B  = 3,
    parameter bit          USE_LS2 = 1'b1,
    parameter int unsigned LS2_TAP = 'b0101      // hhh = h0 XOR h2 (for s=8)
) (
    input  wire  clk,
    input  wire  rst_n,
    input  wire  en,
    input  wire  load,
    input  wire [N1*($clog2(MOD1))-1:0] seed1_in,
    input  wire [N2*($clog2(MOD2))-1:0] seed2_in,
    output logic rand_bit,   // bdi
    output logic bi,         // MAFG1 output bit
    output logic di          // MAFG2 output bit
);
    logic [N1*($clog2(MOD1))-1:0] state1_unused;
    logic [N2*($clog2(MOD2))-1:0] state2_unused;
    logic [$clog2(MOD1)-1:0]      digit1_unused;
    logic [$clog2(MOD2)-1:0]      digit2_unused;

    // MAFG1 -- classic AFG over GF(3), no logic circuit.
    mafg #(
        .N          (N1),
        .MOD        (MOD1),
        .LAG_A      (LAG1_A),
        .LAG_B      (LAG1_B),
        .USE_LS     (1'b0),
        .LS_TAP_MASK(0)
    ) u_mafg1 (
        .clk (clk), .rst_n (rst_n), .en (en), .load (load),
        .seed_in  (seed1_in),
        .out_bit  (bi),
        .out_digit(digit1_unused),
        .state    (state1_unused)
    );

    // MAFG2 -- modified AFG with LS logic circuit for uniform bit distribution.
    mafg #(
        .N          (N2),
        .MOD        (MOD2),
        .LAG_A      (LAG2_A),
        .LAG_B      (LAG2_B),
        .USE_LS     (USE_LS2),
        .LS_TAP_MASK(LS2_TAP)
    ) u_mafg2 (
        .clk (clk), .rst_n (rst_n), .en (en), .load (load),
        .seed_in  (seed2_in),
        .out_bit  (di),
        .out_digit(digit2_unused),
        .state    (state2_unused)
    );

    assign rand_bit = bi ^ di;
endmodule

`default_nettype wire
