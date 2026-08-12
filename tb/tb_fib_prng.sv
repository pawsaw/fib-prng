// tb_fib_prng.sv
// Self-checking testbench for the combined Fibonacci PRNG top level.
// Compares rand_bit (bdi), bi and di against golden vectors produced by the
// Python reference model (model/fib_prng_model.py). Uses the RTL default seed
// (no load), which matches the reference model's default seed.
//
// Plusargs:
//   +golden=<path>  golden vector file ("bdi bi di" per line)
//   +vcd=<path>     VCD output path

`timescale 1ns / 1ps
`default_nettype none

module tb_fib_prng;

    logic clk = 1'b0;
    logic rst_n;
    logic en;
    logic load;
    logic rand_bit, bi, di;

    // Default parameters: MAFG2 modulus s=8, LS tap = h0 XOR h2 (0b0101).
    fib_prng dut (
        .clk (clk), .rst_n (rst_n), .en (en), .load (load),
        .seed1_in ('0), .seed2_in ('0),
        .rand_bit (rand_bit), .bi (bi), .di (di)
    );

    always #5 clk = ~clk;

    // Waveforms.
    string vcd_file;
    initial begin
        if (!$value$plusargs("vcd=%s", vcd_file)) vcd_file = "tb_fib_prng.vcd";
        $dumpfile(vcd_file);
        $dumpvars(0, tb_fib_prng);
    end

    string   golden_file;
    integer  fd, rc;
    integer  errors = 0;
    integer  ones = 0;
    integer  i;
    integer  g_bdi, g_bi, g_di;

    initial begin
        if (!$value$plusargs("golden=%s", golden_file))
            golden_file = "tb/golden_bits.txt";

        fd = $fopen(golden_file, "r");
        if (fd == 0) begin
            $display("TEST FAILED : cannot open golden file %s", golden_file);
            $finish;
        end

        // Drive a real high->low->high reset so the async negedge fires.
        rst_n = 1'b1; en = 1'b0; load = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);          // state == default seed; out_bit == step 1
        en = 1'b1;               // set mid-cycle: no race with the posedge

        // Sample at negedge (state stable); the posedge between iterations
        // advances the generator one step.
        i = 0;
        while (!$feof(fd)) begin
            rc = $fscanf(fd, "%d %d %d\n", g_bdi, g_bi, g_di);
            if (rc != 3) begin
                @(negedge clk);
                continue;
            end
            if (bi !== g_bi[0]) begin
                errors = errors + 1;
                if (errors <= 10) $display("ERROR i=%0d bi got=%b exp=%b", i, bi, g_bi[0]);
            end
            if (di !== g_di[0]) begin
                errors = errors + 1;
                if (errors <= 10) $display("ERROR i=%0d di got=%b exp=%b", i, di, g_di[0]);
            end
            if (rand_bit !== g_bdi[0]) begin
                errors = errors + 1;
                if (errors <= 10) $display("ERROR i=%0d bdi got=%b exp=%b", i, rand_bit, g_bdi[0]);
            end
            ones = ones + rand_bit;
            i = i + 1;
            @(negedge clk);
        end
        $fclose(fd);

        if (errors == 0)
            $display("TEST PASSED : %0d bits match golden model (ones=%0d, ratio=%0.3f)",
                     i, ones, (i > 0) ? real'(ones) / real'(i) : 0.0);
        else
            $display("TEST FAILED : %0d error(s) over %0d bits", errors, i);
        $finish;
    end

    // Safety timeout.
    initial begin
        #500000;
        $display("TEST FAILED : timeout");
        $finish;
    end

endmodule

`default_nettype wire
