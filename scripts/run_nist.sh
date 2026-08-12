#!/usr/bin/env bash
# run_nist.sh - assess the combined Fibonacci PRNG with the NIST SP 800-22 suite.
#
# Because the RTL is verified bit-exact against model/fib_prng_model.py
# (see tb/tb_fib_prng.sv), running the suite on the model's bit stream
# characterises the hardware output too.
#
# Configuration (environment variables, all optional):
#   NIST_ITER      number of bitstreams to test        (default 100)
#   NIST_BITS      bits per bitstream                   (default 1000000)
#   NIST_MOD2      MAFG2 modulus s                      (default 8)
#   NIST_LS2_TAP   MAFG2 LS tap mask                    (default 0b0101)
#   NIST_OUTDIR    output directory                     (default build/nist)
#   STS_BIN        path to the sts binary               (default tools/sts-src/sts)
#
# The dissertation configuration is NIST_ITER=1000, NIST_BITS=1000000 (10^9 bits).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

STS_BIN="${STS_BIN:-tools/sts-src/sts}"
ITER="${NIST_ITER:-100}"
BITS="${NIST_BITS:-1000000}"
MOD2="${NIST_MOD2:-8}"
LS2_TAP="${NIST_LS2_TAP:-0b0101}"
OUTDIR="${NIST_OUTDIR:-build/nist}"
PYTHON="${PYTHON:-python3}"

if [ ! -x "${STS_BIN}" ]; then
    echo "NIST STS not found at ${STS_BIN}"
    echo "Install it first:  make nist-install   (or ./scripts/install_nist_sts.sh)"
    exit 1
fi

TOTAL=$(( ITER * BITS ))
mkdir -p "${OUTDIR}"
BIN="${OUTDIR}/prng.bin"

echo "==> Generating ${TOTAL} bits (${ITER} streams x ${BITS}) with the reference model"
echo "    MAFG2 modulus s=${MOD2}, LS tap=${LS2_TAP}"
"${PYTHON}" model/fib_prng_model.py --bitstream "${TOTAL}" \
    -s "${MOD2}" --ls2-tap "${LS2_TAP}" -o "${BIN}"

echo "==> Running NIST STS (${ITER} x ${BITS} bits, all 15 tests)"
"${STS_BIN}" -i "${ITER}" -S "${BITS}" -F r -w "${OUTDIR}" -s -t 0 "${BIN}"

echo ""
echo "==> Summary (full report: ${OUTDIR}/result.txt)"
sed -n '1,20p' "${OUTDIR}/result.txt"
