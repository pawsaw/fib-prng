#!/usr/bin/env bash
# install_nist_sts.sh - build the NIST Statistical Test Suite (SP 800-22) locally.
#
# Uses the actively-maintained, non-interactive arcetri/sts fork (same tests as
# the classic NIST STS, with a proper command-line interface). Idempotent.
#
# Result: an executable at tools/sts-src/sts
#
# Requires: git, make, a C compiler, and FFTW (installed here via Homebrew).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="${REPO_ROOT}/tools"
SRC="${TOOLS}/sts-src"
STS_URL="https://github.com/arcetri/sts"

echo "==> Installing NIST STS (arcetri/sts fork)"

# FFTW is a build dependency (Discrete Fourier Transform test).
if command -v brew >/dev/null 2>&1; then
    if ! brew list fftw >/dev/null 2>&1; then
        echo "==> Installing FFTW (build dependency)"
        brew install fftw
    fi
else
    echo "==> WARNING: Homebrew not found; ensure FFTW (fftw3.h) is installed."
fi

mkdir -p "${TOOLS}"
if [ -d "${SRC}/.git" ]; then
    echo "==> Updating existing clone"
    git -C "${SRC}" pull --ff-only || true
else
    echo "==> Cloning ${STS_URL}"
    git clone --depth 1 "${STS_URL}" "${SRC}"
fi

echo "==> Building"
make -C "${SRC}"

if [ -x "${SRC}/sts" ]; then
    echo "==> NIST STS built: ${SRC}/sts"
    "${SRC}/sts" -h >/dev/null 2>&1 && echo "==> OK. Run the suite with:  make nist"
else
    echo "ERROR: build did not produce ${SRC}/sts" >&2
    exit 1
fi
