#!/usr/bin/env python3
"""Golden reference model for the combined Fibonacci PRNG (dissertation, Sec. 2.3/4.3).

Pure-Python, bit-exact re-implementation of the RTL. Used to:
  * generate expected output vectors for the SystemVerilog testbenches, and
  * let humans explore the generator behaviour without any HDL tooling.

Recurrences:
  MAFG1 (GF(3)):  x_i = (x_{i-32} + x_{i-5}) mod 3            (no LS term)
  MAFG2:          y_i = (y_{i-20} + y_{i-3} + hhh) mod s      (LS term)
                  hhh = XOR of selected bits of RG1 (h0 XOR h_k)
  Combined:       bdi = bi XOR di   (bi/di = LSB of each new value)

Register convention matches the RTL: rg[0]=RG1=y_{i-1}, rg[N-1]=RGN=y_{i-N}.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass, field


@dataclass
class MAFG:
    """Generic (Modified) Additive Fibonacci Generator."""

    n: int                      # number of digit registers
    mod: int                    # recurrence modulus
    lag_a: int                  # first feedback lag (1..n)
    lag_b: int                  # second feedback lag (1..n)
    use_ls: bool = False        # enable LS logic-circuit term
    ls_tap_mask: int = 0        # which bits of RG1 XOR to form `a`
    seed: list[int] | None = None
    rg: list[int] = field(init=False)

    def __post_init__(self) -> None:
        if self.seed is not None:
            assert len(self.seed) == self.n
            self.rg = [d % self.mod for d in self.seed]
        else:
            # Default non-zero seed: RGN = 1, others 0 (matches RTL default).
            self.rg = [0] * self.n
            self.rg[self.n - 1] = 1

    @property
    def width(self) -> int:
        return max(1, (self.mod - 1).bit_length())

    def _a_term(self) -> int:
        if not self.use_ls:
            return 0
        bits = self.rg[0] & self.ls_tap_mask
        return bin(bits).count("1") & 1

    def step(self) -> int:
        """Advance one step; return the output bit (LSB of the new value)."""
        new = (self.rg[self.lag_a - 1] + self.rg[self.lag_b - 1] + self._a_term()) % self.mod
        self.rg = [new] + self.rg[:-1]
        return new & 1


@dataclass
class CombinedPRNG:
    """MAFG1 (GF(3)) XOR MAFG2 (with LS logic circuit)."""

    mod2: int = 8
    ls2_tap: int = 0b0101       # h0 XOR h2 (default for s=8)
    seed1: list[int] | None = None
    seed2: list[int] | None = None

    def __post_init__(self) -> None:
        self.mafg1 = MAFG(n=32, mod=3, lag_a=32, lag_b=5, use_ls=False, seed=self.seed1)
        self.mafg2 = MAFG(
            n=20, mod=self.mod2, lag_a=20, lag_b=3,
            use_ls=True, ls_tap_mask=self.ls2_tap, seed=self.seed2,
        )

    def step(self) -> tuple[int, int, int]:
        bi = self.mafg1.step()
        di = self.mafg2.step()
        return bi ^ di, bi, di

    def bits(self, count: int) -> list[int]:
        return [self.step()[0] for _ in range(count)]


def write_binary(prng: "CombinedPRNG", nbits: int, out) -> None:
    """Stream `nbits` output bits packed MSB-first into bytes (STS raw 'r' format).

    Written in fixed-size chunks so arbitrarily long streams (>=10**9 bits) use
    constant memory.
    """
    step = prng.step
    buf = bytearray()
    acc = 0
    filled = 0
    for _ in range(nbits):
        acc = (acc << 1) | step()[0]
        filled += 1
        if filled == 8:
            buf.append(acc)
            acc = 0
            filled = 0
            if len(buf) >= 65536:
                out.write(buf)
                buf.clear()
    if filled:                       # flush a final partial byte, left-aligned
        buf.append(acc << (8 - filled))
    if buf:
        out.write(buf)


def write_ascii(prng: "CombinedPRNG", nbits: int, out) -> None:
    """Stream `nbits` output bits as ASCII '0'/'1' characters (STS 'a' format)."""
    step = prng.step
    chunk = []
    for _ in range(nbits):
        chunk.append("1" if step()[0] else "0")
        if len(chunk) >= 65536:
            out.write("".join(chunk))
            chunk.clear()
    if chunk:
        out.write("".join(chunk))



def main() -> None:
    ap = argparse.ArgumentParser(description="Combined Fibonacci PRNG reference model")
    ap.add_argument("-n", "--count", type=int, default=64, help="number of bits")
    ap.add_argument("-s", "--mod2", type=int, default=8, help="MAFG2 modulus s")
    ap.add_argument("--ls2-tap", type=lambda x: int(x, 0), default=0b0101,
                    help="LS tap mask for MAFG2 (e.g. 0b0101)")
    ap.add_argument("--vectors", type=int, default=0,
                    help="emit N golden vectors as 'bdi bi di' lines and exit")
    ap.add_argument("--bitstream", type=int, default=0, metavar="N",
                    help="emit N output bits and exit (for NIST STS / dieharder)")
    ap.add_argument("--format", choices=("raw", "ascii"), default="raw",
                    help="bitstream format: raw binary ('r') or ASCII '0'/'1'")
    ap.add_argument("-o", "--out", default="-",
                    help="bitstream output file (default '-' = stdout)")
    args = ap.parse_args()

    prng = CombinedPRNG(mod2=args.mod2, ls2_tap=args.ls2_tap)

    if args.bitstream:
        import sys
        if args.format == "raw":
            fh = sys.stdout.buffer if args.out == "-" else open(args.out, "wb")
            try:
                write_binary(prng, args.bitstream, fh)
            finally:
                if fh is not sys.stdout.buffer:
                    fh.close()
        else:
            fh = sys.stdout if args.out == "-" else open(args.out, "w")
            try:
                write_ascii(prng, args.bitstream, fh)
            finally:
                if fh is not sys.stdout:
                    fh.close()
        return

    if args.vectors:
        for _ in range(args.vectors):
            bdi, bi, di = prng.step()
            print(f"{bdi} {bi} {di}")
        return

    bits = prng.bits(args.count)
    stream = "".join(str(b) for b in bits)
    ones = sum(bits)
    print(f"bits    : {stream}")
    print(f"count   : {len(bits)}  ones: {ones}  zeros: {len(bits) - ones}  "
          f"ratio: {ones / len(bits):.3f}")


if __name__ == "__main__":
    main()
