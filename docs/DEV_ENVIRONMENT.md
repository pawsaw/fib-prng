# fib-prng — Reproducible Development Environment

Local macOS environment for developing, simulating, verifying, and performing
generic (technology-independent) synthesis of a **synthesizable SystemVerilog**
PRNG.

The flow is RTL-only. Vendor FPGA/ASIC implementation (Vivado, Quartus, Libero,
Design Compiler, Genus, place-and-route, timing closure, power) is **out of
scope** and can be added later by third parties without changing the RTL.

---

## 1. Target platform

| Item        | Value                                             |
| ----------- | ------------------------------------------------- |
| OS          | macOS (Apple Silicon **and** Intel)               |
| Verified on | macOS 26.5.2, Apple Silicon (arm64)               |
| Editor      | Visual Studio Code                                |
| VCS         | Git                                               |

---

## 2. Toolchain

| Purpose                         | Tool                | Install source          | Verified version |
| ------------------------------- | ------------------- | ----------------------- | ---------------- |
| Package manager                 | Homebrew            | script                  | 6.0.15           |
| HDL simulator                   | Icarus Verilog      | `brew icarus-verilog`   | 13.0             |
| Linter / compiler / fast sim    | Verilator           | `brew verilator`        | 5.050            |
| Generic logic synthesis         | Yosys               | `brew yosys`            | 0.68             |
| Waveform viewer                 | Surfer              | `brew surfer`           | 0.7.0            |
| Build system                    | GNU Make            | `brew make` (or system) | 4.4.1 / 3.81     |
| Version control                 | Git                 | system / `brew git`     | 2.50.1           |
| Statistical test suite          | NIST STS (SP 800-22)| source build (arcetri/sts) | 3.2.7         |
| STS build dependency            | FFTW                | `brew fftw`             | 3.3.11           |

### Note on statistical testing (NIST STS)

The dissertation's central claim is that the combined generator passes the full
NIST SP 800-22 suite. That suite is **built from source** into `tools/`
(git-ignored) rather than vendored, using the actively-maintained,
non-interactive [arcetri/sts](https://github.com/arcetri/sts) fork (identical
tests to the classic NIST STS). `scripts/install_nist_sts.sh` installs FFTW (its
only extra dependency) and builds it; `make nist` runs it. See
[PRNG_GUIDE.md §5.8 and §10](PRNG_GUIDE.md) for usage and interpretation.


### Note on the waveform viewer (GTKWave → Surfer)

GTKWave was the originally requested viewer. Its Homebrew cask was **discontinued
upstream and disabled on 2025-10-29**, so it can no longer be installed with
`brew install --cask gtkwave`. This environment uses **[Surfer](https://surfer-project.org/)**
instead — a modern, actively maintained VCD/FST viewer that:

- reads the same `.vcd` waveforms produced by Icarus Verilog,
- runs as a native macOS app (`surfer file.vcd`), and
- has an official **VS Code extension** (`surfer-project.surfer`) so waveforms
  can be inspected inside the editor.

If GTKWave is specifically required, install a standalone `gtkwave.app` bundle
manually and run `make wave WAVE=/Applications/gtkwave.app/Contents/Resources/bin/gtkwave`.

---

## 3. VS Code extensions

Installed automatically by the bootstrap script and recommended via
[.vscode/extensions.json](../.vscode/extensions.json):

| Extension                   | ID                          | Role                                        |
| --------------------------- | --------------------------- | ------------------------------------------- |
| Verilog-HDL/SystemVerilog   | `mshr-h.veriloghdl`         | Language support, syntax highlighting, lint |
| Makefile Tools              | `ms-vscode.makefile-tools`  | Makefile support                            |
| Error Lens                  | `usernamehw.errorlens`      | Inline diagnostics                          |
| EditorConfig                | `editorconfig.editorconfig` | Consistent formatting                       |
| GitLens                     | `eamodio.gitlens`           | Git integration                             |
| Surfer                      | `surfer-project.surfer`     | Waveform viewing inside VS Code             |

Editor behaviour is configured in [.vscode/settings.json](../.vscode/settings.json)
(Verilator as the in-editor linter, 4-space SystemVerilog indentation, file
associations). Build/test tasks are wired in [.vscode/tasks.json](../.vscode/tasks.json)
(`Terminal → Run Task…`).

---

## 4. One-command setup (clean machine)

```bash
git clone <repo-url> fib-prng
cd fib-prng
./scripts/bootstrap.sh
```

[scripts/bootstrap.sh](../scripts/bootstrap.sh) is idempotent and:

1. installs Homebrew if missing,
2. installs the toolchain from the [Brewfile](../Brewfile) (`brew bundle`),
3. installs the VS Code extensions,
4. builds the NIST STS suite (optional; set `SKIP_NIST=1` to skip), and
5. prints the resulting tool versions.

### Manual equivalent

```bash
# 1. Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Toolchain
brew bundle --file=Brewfile
# ...or explicitly:
brew install icarus-verilog verilator yosys surfer make git fftw

# 3. VS Code extensions
for e in mshr-h.veriloghdl ms-vscode.makefile-tools usernamehw.errorlens \
         EditorConfig.EditorConfig eamodio.gitlens surfer-project.surfer; do
  code --install-extension "$e" --force
done

# 4. NIST STS statistical test suite (optional)
./scripts/install_nist_sts.sh
```

---

## 5. Project layout

```
fib-prng/
├── rtl/                 # synthesizable SystemVerilog RTL
│   ├── mod_add.sv       # arbitrary-modulus adder (mod-m trick, eq. 3.1/3.6)
│   ├── mafg.sv          # generic (Modified) Additive Fibonacci Generator
│   └── fib_prng.sv      # TOP: combined generator MAFG1 (GF(3)) XOR MAFG2
├── tb/                  # simulation testbenches
│   ├── tb_mod_add.sv    # exhaustive unit test of mod_add
│   ├── tb_fib_prng.sv   # combined generator vs golden model (bit-exact)
│   └── golden_bits.txt  # golden "bdi bi di" vectors from the reference model
├── model/
│   └── fib_prng_model.py# Python golden reference model + explorer
├── synth/               # Yosys synthesis scripts
│   └── synth.ys         # generic, technology-independent synthesis + stats
├── scripts/
│   ├── bootstrap.sh          # one-command environment setup
│   ├── install_nist_sts.sh   # build the NIST SP 800-22 suite locally
│   └── run_nist.sh           # generate a stream and run the NIST suite
├── tools/               # third-party tools built locally, e.g. NIST STS (git-ignored)
├── build/               # generated artifacts (git-ignored)
│   ├── wave/            # VCD waveforms
│   ├── synth/           # netlists, stats, logs
│   └── nist/            # NIST STS bit stream + result.txt
├── .vscode/             # editor settings, recommended extensions, tasks
├── spec/                # dissertation / specification
├── Brewfile             # reproducible tool list for `brew bundle`
├── Makefile             # lint / sim / wave / synth / regress / golden / explore / nist
├── .editorconfig
└── docs/DEV_ENVIRONMENT.md + docs/PRNG_GUIDE.md
```

> The RTL implements the combined Fibonacci PRNG defined in the dissertation
> (`spec/`, Sections 2.3 / 4.3): MAFG1 over `GF(3)` XORed with MAFG2 (which uses
> an LS logic circuit). See [PRNG_GUIDE.md](PRNG_GUIDE.md) for the full
> algorithm and architecture walkthrough.

---

## 6. Make targets

| Command        | Action                                                            |
| -------------- | ----------------------------------------------------------------- |
| `make lint`    | Verilator `--lint-only -Wall` + Icarus syntax check               |
| `make sim`     | Compile with Icarus, run testbench `TB`, write VCD to `build/wave/`|
| `make wave`    | Run the sim, then open the VCD in Surfer                          |
| `make synth`   | Yosys generic synthesis, write netlist + `stats.txt`             |
| `make regress` | Run **all** testbenches; exits non-zero on any failure            |
| `make golden`  | Regenerate golden vectors from the Python reference model         |
| `make explore` | Run the Python reference model (e.g. `make explore ARGS='-n 256'`)|
| `make nist-install` | Build the NIST SP 800-22 suite into `tools/` (one-time)      |
| `make nist`    | Assess the PRNG with NIST STS (opt-in; not in `regress`/`all`)    |
| `make all`     | `lint` + `regress` + `synth`                                     |
| `make clean`   | Remove `build/` and `obj_dir/`                                   |
| `make help`    | List targets                                                      |

Common overrides: `make sim TB=tb_mod_add`, `make wave WAVE=gtkwave`,
`make golden MODEL_ARGS='-s 6 --ls2-tap 0b0011'`,
`make nist NIST_ITER=1000` (full dissertation config).

---

## 7. Expected workflow

1. **Edit** RTL in `rtl/`.
2. **Lint** — `make lint`.
3. **Simulate** — `make sim`.
4. **Inspect waveforms** — `make wave` (or open `build/wave/*.vcd` with the
   Surfer VS Code extension).
5. **Fix** functional issues and repeat.
6. **Synthesize** — `make synth`.
7. **Review** `build/synth/stats.txt`.
8. **Statistically test** (optional) — `make nist-install` once, then `make nist`.
9. **Commit** with Git.

---

## 8. Verification / success criteria

Run from the project root on a freshly set-up machine:

```bash
make lint      # -> ">> Lint OK"
make regress   # -> ">> Regression PASSED"
make synth     # -> prints gate statistics
```

Reference output captured on the verified platform:

```text
$ make lint
>> Verilator lint
>> Icarus Verilog syntax check
>> Lint OK

$ make regress
--- tb_mod_add ---
TEST PASSED : mod_add exhaustive check
--- tb_fib_prng ---
TEST PASSED : 2000 bits match golden model (ones=1013, ratio=0.506)
>> Regression PASSED

$ make synth
=== fib_prng ===
     279 cells
     124   flip-flops   (MAFG1: 32x2-bit + MAFG2: 20x3-bit)
     ... generic AND/OR/XOR/MUX gates ...

$ make nist                     # after `make nist-install`
==> Running NIST STS (100 x 1000000 bits, all 15 tests)
        186/188 tests passed successfully both the analyses.
```

(With the full `make nist NIST_ITER=1000` configuration the pass rate is stable;
at 100 streams one or two of the 188 sub-tests may be flagged by chance — see
[PRNG_GUIDE.md §5.8](PRNG_GUIDE.md).)

| Success criterion                                    | Status |
| ---------------------------------------------------- | ------ |
| Compile SystemVerilog sources                        | ✅     |
| Execute simulations                                  | ✅     |
| Generate and inspect waveforms (VCD → Surfer)        | ✅     |
| Successful linting (Verilator + Icarus)              | ✅     |
| Generic synthesis with Yosys + statistics            | ✅     |
| Statistical validation (NIST SP 800-22, opt-in)      | ✅     |
| Reproducible on a clean macOS install (bootstrap.sh) | ✅     |

> Icarus prints benign notes that some `mod_add` sensitivity optimisations are
> not fully supported and that a `mafg` `always_comb` has no sensitivities when
> `USE_LS=0`. These do not affect simulation results; the RTL uses continuous
> assignments so behaviour is correct.

---

## 9. Out of scope

FPGA vendor projects · Vivado · Quartus · Libero · Synopsys Design Compiler ·
Cadence Genus · ASIC place-and-route · timing closure · physical implementation ·
power optimization · technology-library-specific synthesis.

These can be integrated later using proprietary technology libraries **without
changing the RTL**.
