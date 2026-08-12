#!/usr/bin/env bash
# bootstrap.sh - reproducibly set up the fib-prng dev environment on a clean macOS.
#
# Usage:
#   ./scripts/bootstrap.sh
#
# Installs Homebrew (if missing), the HDL toolchain (via Brewfile), and the
# recommended VS Code extensions. Safe to re-run: all steps are idempotent.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> fib-prng environment bootstrap"

# 1. Homebrew ---------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
    echo "==> Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Load brew into the current shell (Apple Silicon and Intel paths).
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo "==> Homebrew already installed"
fi

# 2. HDL toolchain ----------------------------------------------------------
echo "==> Installing HDL toolchain (brew bundle)"
brew bundle --file="${REPO_ROOT}/Brewfile"

# 3. VS Code extensions -----------------------------------------------------
if command -v code >/dev/null 2>&1; then
    echo "==> Installing VS Code extensions"
    EXTENSIONS=(
        mshr-h.veriloghdl
        ms-vscode.makefile-tools
        usernamehw.errorlens
        EditorConfig.EditorConfig
        eamodio.gitlens
        surfer-project.surfer
    )
    for ext in "${EXTENSIONS[@]}"; do
        code --install-extension "$ext" --force
    done
else
    echo "==> 'code' CLI not found; skipping VS Code extensions."
    echo "    In VS Code run: Shell Command: Install 'code' command in PATH"
fi

# 4. NIST STS statistical test suite (optional) -----------------------------
# Set SKIP_NIST=1 to skip. Non-fatal: the core flow does not depend on it.
if [ "${SKIP_NIST:-0}" != "1" ]; then
    echo "==> Installing NIST STS (statistical test suite)"
    "${REPO_ROOT}/scripts/install_nist_sts.sh" \
        || echo "==> NIST STS install skipped/failed (optional; run 'make nist-install' later)"
fi

# 5. Verify -----------------------------------------------------------------
echo "==> Verifying tool versions"
iverilog  -V 2>&1 | head -1
verilator --version
yosys     --version
surfer    --version
make      --version | head -1
git       --version

echo "==> Bootstrap complete. Try: make lint && make sim && make synth"
