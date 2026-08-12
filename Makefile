# Makefile for the fib-prng SystemVerilog development flow.
#
# Quick start:
#   make lint       # static analysis (Verilator + Icarus)
#   make sim        # run the top-level testbench (combined PRNG)
#   make wave       # run sim and open the waveform in Surfer
#   make synth      # generic synthesis + gate statistics (Yosys)
#   make regress    # run ALL testbenches, fail on any error
#   make explore    # run the Python reference model interactively
#   make help       # full target list
#
# Run one specific testbench:  make sim TB=tb_mod_add

# ---- Configuration ---------------------------------------------------------
RTL_DIR   := rtl
TB_DIR    := tb
SYN_DIR   := synth
MODEL_DIR := model
BUILD_DIR := build
WAVE_DIR  := $(BUILD_DIR)/wave
SYNO_DIR  := $(BUILD_DIR)/synth

# TOP = RTL top module (lint/synth); TB = testbench module to simulate.
TOP       ?= fib_prng
TB        ?= tb_fib_prng

RTL_SRCS  := $(RTL_DIR)/mod_add.sv $(RTL_DIR)/mafg.sv $(RTL_DIR)/fib_prng.sv

# List of all testbenches exercised by `make regress`.
TESTBENCHES := tb_mod_add tb_fib_prng

# Tools (override on the command line if needed, e.g. WAVE=gtkwave)
IVERILOG  := iverilog
VVP       := vvp
VERILATOR := verilator
YOSYS     := yosys
WAVE      := surfer
PYTHON    := python3

GOLDEN    := $(TB_DIR)/golden_bits.txt
SIM_BIN   := $(BUILD_DIR)/$(TB).vvp
VCD       := $(WAVE_DIR)/$(TB).vcd

IVERILOG_FLAGS := -g2012 -Wall -I$(RTL_DIR)
VERILATOR_LINT := --lint-only -Wall --top-module $(TOP)

# ---- Phony targets ---------------------------------------------------------
.PHONY: all lint sim wave synth regress golden explore model nist nist-install clean help dirs

all: lint regress synth

help:
	@echo "Available targets:"
	@echo "  lint         - Verilator lint + Icarus syntax check of the RTL"
	@echo "  sim          - simulate testbench TB (default $(TB))"
	@echo "  wave         - run TB and open the waveform in $(WAVE)"
	@echo "  synth        - generic synthesis + statistics (Yosys)"
	@echo "  regress      - run ALL testbenches ($(TESTBENCHES))"
	@echo "  golden       - regenerate golden vectors from the Python model"
	@echo "  explore      - run the Python reference model (e.g. make explore ARGS='-n 128')"
	@echo "  nist-install - build the NIST STS statistical test suite locally"
	@echo "  nist         - assess the PRNG with NIST SP 800-22 (needs nist-install)"
	@echo "  all          - lint + regress + synth"
	@echo "  clean        - remove generated artifacts"
	@echo ""
	@echo "Run one testbench:      make sim TB=tb_mod_add"
	@echo "Change MAFG2 modulus:   make golden MODEL_ARGS='-s 6 --ls2-tap 0b0011'"
	@echo "Full NIST run (10^9):   make nist NIST_ITER=1000"

dirs:
	@mkdir -p $(BUILD_DIR) $(WAVE_DIR) $(SYNO_DIR)

# ---- Lint / static analysis ------------------------------------------------
lint:
	@echo ">> Verilator lint"
	$(VERILATOR) $(VERILATOR_LINT) $(RTL_SRCS)
	@echo ">> Icarus Verilog syntax check"
	$(IVERILOG) $(IVERILOG_FLAGS) -t null -s $(TOP) $(RTL_SRCS)
	@echo ">> Lint OK"

# ---- Golden reference vectors ----------------------------------------------
MODEL_ARGS ?=
golden:
	@echo ">> Regenerating golden vectors ($(GOLDEN))"
	$(PYTHON) $(MODEL_DIR)/fib_prng_model.py --vectors 2000 $(MODEL_ARGS) > $(GOLDEN)

# ---- Simulation ------------------------------------------------------------
$(SIM_BIN): $(RTL_SRCS) $(TB_DIR)/$(TB).sv | dirs
	$(IVERILOG) $(IVERILOG_FLAGS) -s $(TB) -o $@ $(RTL_SRCS) $(TB_DIR)/$(TB).sv

sim: $(SIM_BIN) | dirs
	@echo ">> Running $(TB)"
	$(VVP) $(SIM_BIN) +vcd=$(VCD) +golden=$(GOLDEN)
	@echo ">> Waveform written to $(VCD)"

# ---- Regression: run every testbench, fail on any error --------------------
regress: | dirs
	@echo ">> Regression over: $(TESTBENCHES)"
	@fail=0; \
	for tb in $(TESTBENCHES); do \
	  echo "--- $$tb ---"; \
	  $(IVERILOG) $(IVERILOG_FLAGS) -s $$tb -o $(BUILD_DIR)/$$tb.vvp $(RTL_SRCS) $(TB_DIR)/$$tb.sv || { fail=1; continue; }; \
	  $(VVP) $(BUILD_DIR)/$$tb.vvp +vcd=$(WAVE_DIR)/$$tb.vcd +golden=$(GOLDEN) | tee $(BUILD_DIR)/$$tb.log; \
	  grep -q "TEST PASSED" $(BUILD_DIR)/$$tb.log || { echo "FAILED: $$tb"; fail=1; }; \
	done; \
	if [ $$fail -ne 0 ]; then echo ">> REGRESSION FAILED"; exit 1; fi; \
	echo ">> Regression PASSED"

# ---- Waveform viewing ------------------------------------------------------
wave: sim
	@echo ">> Opening $(VCD) in $(WAVE)"
	$(WAVE) $(VCD)

# ---- Synthesis -------------------------------------------------------------
synth: | dirs
	@echo ">> Yosys generic synthesis"
	$(YOSYS) -q -l $(SYNO_DIR)/yosys.log -s $(SYN_DIR)/synth.ys
	@echo ">> Synthesis statistics ($(SYNO_DIR)/stats.txt):"
	@cat $(SYNO_DIR)/stats.txt

# ---- Reference model -------------------------------------------------------
ARGS ?= -n 128
explore model:
	$(PYTHON) $(MODEL_DIR)/fib_prng_model.py $(ARGS)

# ---- Statistical testing (NIST SP 800-22) ----------------------------------
# Opt-in: not part of `regress`/`all` (needs the external suite and is slow).
# Dissertation configuration: NIST_ITER=1000 NIST_BITS=1000000 (10^9 bits).
NIST_ITER    ?= 100
NIST_BITS    ?= 1000000
NIST_MOD2    ?= 8
NIST_LS2_TAP ?= 0b0101

nist-install:
	./scripts/install_nist_sts.sh

nist:
	NIST_ITER=$(NIST_ITER) NIST_BITS=$(NIST_BITS) NIST_MOD2=$(NIST_MOD2) \
	NIST_LS2_TAP=$(NIST_LS2_TAP) ./scripts/run_nist.sh

# ---- Cleanup ---------------------------------------------------------------
clean:
	rm -rf $(BUILD_DIR) obj_dir
	@echo ">> Cleaned"
