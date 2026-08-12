// mafg.sv
// Generic (Modified) Additive Fibonacci Generator, as described in the
// dissertation (Sawicki, Opole 2026), Sections 2 and 3.
//
// Recurrence (eq. 2.7 / 3.9):
//
//     y_i = ( y_{i-LAG_A} + y_{i-LAG_B} + a ) mod MOD
//
// where `a` is the output of the logic circuit LS/LC (eq. 2.8):
//
//     a = h_0 XOR h_k     (XOR of selected bits of register RG1)
//
// The generator is a chain of N base-MOD "digit" registers RG1..RGN holding
// y_{i-1} .. y_{i-N}. Each clock it forms the new value with mod_add and shifts.
// Set USE_LS=0 (and LS_TAP_MASK=0) to get a classic AFG (a = 0), e.g. MAFG1.
//
// The output pseudo-random bit is the least-significant bit of the freshly
// computed value (the MUX output in the hardware figures).

`default_nettype none

module mafg #(
    parameter int unsigned N           = 20,   // number of digit registers
    parameter int unsigned MOD         = 8,    // recurrence modulus
    parameter int unsigned LAG_A       = 20,   // first  feedback lag (1..N)
    parameter int unsigned LAG_B       = 3,    // second feedback lag (1..N)
    parameter bit          USE_LS      = 1'b1, // enable LS logic-circuit term
    // Which bits of RG1 are XORed to form `a` (only used when USE_LS=1).
    parameter int unsigned LS_TAP_MASK = 'b0101,
    // Digit width: smallest n with 2**n >= MOD (mod_add supports 2**n >= MOD).
    parameter int unsigned WIDTH       = (MOD <= 1) ? 1 : $clog2(MOD)
) (
    input  wire                    clk,
    input  wire                    rst_n,    // asynchronous, active-low
    input  wire                    en,       // advance one step when high
    input  wire                    load,     // load seed_in on next edge
    input  wire [N*WIDTH-1:0]      seed_in,  // packed RG1..RGN seed digits
    output logic                   out_bit,  // LSB of the new value (bi/di)
    output logic [WIDTH-1:0]       out_digit,// full new value (RG1 after update)
    output logic [N*WIDTH-1:0]     state     // packed RG1..RGN (for verification)
);
    // Register file: rg[0] = RG1 = y_{i-1}, rg[N-1] = RGN = y_{i-N}.
    logic [WIDTH-1:0] rg [N];

    // Default non-zero seed: RGN = 1, others 0 (a zero state would lock up).
    function automatic [WIDTH-1:0] default_digit(input int unsigned idx);
        default_digit = (idx == N-1) ? {{(WIDTH-1){1'b0}}, 1'b1} : '0;
    endfunction

    // Logic circuit LS/LC output: a = XOR of selected bits of RG1.
    wire a_term = USE_LS ? ^(rg[0] & LS_TAP_MASK[WIDTH-1:0]) : 1'b0;

    // Feedback sum: y_{i-LAG_A} + y_{i-LAG_B} + a  (LAG is 1-based).
    wire [WIDTH+1:0] fb_sum = {2'b00, rg[LAG_A-1]} + {2'b00, rg[LAG_B-1]}
                            + {{(WIDTH+1){1'b0}}, a_term};

    logic [WIDTH-1:0] next_val;
    mod_add #(.WIDTH(WIDTH), .MOD(MOD)) u_mod (
        .sum_in (fb_sum),
        .out    (next_val)
    );

    integer k;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < N; k = k + 1)
                rg[k] <= default_digit(k);
        end else if (load) begin
            for (k = 0; k < N; k = k + 1)
                rg[k] <= seed_in[k*WIDTH +: WIDTH];
        end else if (en) begin
            for (k = N-1; k > 0; k = k - 1)
                rg[k] <= rg[k-1];
            rg[0] <= next_val;
        end
    end

    assign out_digit = next_val;
    assign out_bit   = next_val[0];

    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : g_state
            assign state[g*WIDTH +: WIDTH] = rg[g];
        end
    endgenerate
endmodule

`default_nettype wire
