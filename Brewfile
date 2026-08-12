# Brewfile - reproducible tool installation for the fib-prng dev environment.
#
# Install everything with:
#   brew bundle --file=Brewfile
#
# NOTE: GTKWave is intentionally NOT listed. Its Homebrew cask was discontinued
#       upstream and disabled on 2025-10-29, so it can no longer be installed via
#       Homebrew. Surfer is used as the modern, maintained waveform viewer.

brew "git"
brew "make"
brew "icarus-verilog"
brew "verilator"
brew "yosys"
brew "surfer"

# Build dependency for the NIST STS statistical test suite (see scripts/install_nist_sts.sh).
brew "fftw"
