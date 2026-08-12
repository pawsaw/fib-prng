// tb_mod_add.sv
// Exhaustive self-checking unit test for the arbitrary-modulus adder.
// Checks out == (sum_in mod MOD) for every sum_in in [0, 2*MOD-1] and a few
// representative moduli (odd/even, power-of-two and not).

`timescale 1ns / 1ps
`default_nettype none

module tb_mod_add;

    integer errors = 0;

    // Instantiate one adder per modulus (parameters must be elaboration-time).
    logic [4:0] sum3, sum6, sum8;
    logic [1:0] out3;
    logic [2:0] out6, out8;

    mod_add #(.WIDTH(2), .MOD(3)) u3 (.sum_in(sum3[3:0]), .out(out3));
    mod_add #(.WIDTH(3), .MOD(6)) u6 (.sum_in(sum6),      .out(out6));
    mod_add #(.WIDTH(3), .MOD(8)) u8 (.sum_in(sum8),      .out(out8));

    task automatic check(input int unsigned m, input int unsigned got,
                         input int unsigned s);
        if (got !== (s % m)) begin
            errors = errors + 1;
            $display("ERROR: MOD=%0d sum_in=%0d got=%0d expected=%0d",
                     m, s, got, s % m);
        end
    endtask

    integer s;
    initial begin
        for (s = 0; s < 2*3; s = s + 1) begin sum3 = s[4:0]; #1; check(3, out3, s); end
        for (s = 0; s < 2*6; s = s + 1) begin sum6 = s[4:0]; #1; check(6, out6, s); end
        for (s = 0; s < 2*8; s = s + 1) begin sum8 = s[4:0]; #1; check(8, out8, s); end

        if (errors == 0) $display("TEST PASSED : mod_add exhaustive check");
        else             $display("TEST FAILED : %0d error(s)", errors);
        $finish;
    end

endmodule

`default_nettype wire
