# fib-prng

Hardware (SystemVerilog) implementation of the **combined Fibonacci PRNG** from
the doctoral dissertation of P. Sawicki (Opole University of Technology, 2026):
two Modified Additive Fibonacci Generators (MAFG1 over `GF(3)`, MAFG2 with an LS
logic circuit) whose bit streams are XORed to produce a long-period, uniform
output — `bdi = bi XOR di`.

RTL development, simulation, bit-exact verification, and generic
(technology-independent) synthesis on macOS.

## Quick start

```bash
./scripts/bootstrap.sh   # install toolchain + VS Code extensions (idempotent)
make lint                # static analysis (Verilator + Icarus)
make sim                 # simulate the combined PRNG (self-checking vs golden model)
make wave                # open waveforms in Surfer
make synth               # generic synthesis + gate stats (Yosys)
make regress             # run ALL testbenches (CI-friendly)
make explore             # play with the Python reference model
make nist-install        # build the NIST SP 800-22 suite (one-time)
make nist                # statistically test the output (dissertation claim)
```

## Documentation

- **[docs/PRNG_GUIDE.md](docs/PRNG_GUIDE.md)** — complete, beginner-friendly guide
  to the algorithm, architecture, and every command (start here).
- **[docs/DEV_ENVIRONMENT.md](docs/DEV_ENVIRONMENT.md)** — reproducible toolchain
  and environment setup.

## Design at a glance

| File                | Role                                                        |
| ------------------- | ----------------------------------------------------------- |
| `rtl/mod_add.sv`    | arbitrary-modulus adder (the "mod m" trick, eq. 3.1/3.6)    |
| `rtl/mafg.sv`       | generic (Modified) Additive Fibonacci Generator             |
| `rtl/fib_prng.sv`   | top level: MAFG1 (`GF(3)`) XOR MAFG2 (LS logic)             |
| `model/fib_prng_model.py` | Python golden reference model + explorer              |
| `tb/`               | self-checking testbenches + golden vectors                  |

