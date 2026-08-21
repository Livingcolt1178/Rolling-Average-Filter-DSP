#!/usr/bin/env python3
"""
Generate stimulus + expected-output vectors for the filter testbench, and
measure the reference model's frequency response so the RTL has a curve to
be checked against.

Writes:
  stimulus.hex   one 8-bit ADC code per line   ($readmemh)
  expected.hex   one 12-bit DAC code per line  ($readmemh)
  response.csv   f_hz, |H| ideal, |H| measured from the model
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ref_model import (RollingAverage, adc_encode, ideal_boxcar_response,
                       cutoff_hz, first_null_hz, VREF)

N_TAPS = 64
FS = 3_125_000.0          # 50 MHz / 16
OUT = os.path.dirname(os.path.abspath(__file__))


def build_stimulus():
    """
    Deliberately exercises what held constants cannot:
      1. impulse      - reveals the true window length
      2. step         - settling must take exactly N samples
      3. two-tone     - 1 kHz passband + 200 kHz stopband
      4. noisy DC     - sub-LSB dither, exercises the resolution question
    """
    stim = []

    stim += [0] * 8
    stim += [255] + [0] * (N_TAPS + 8)                     # impulse
    stim += [0] * 4
    stim += [200] * (2 * N_TAPS)                           # step up
    stim += [40] * (2 * N_TAPS)                            # step down

    n = 1024                                               # two-tone
    for i in range(n):
        t = i / FS
        v = 1.65 + 0.8 * math.sin(2 * math.pi * 1_000 * t) \
                 + 0.4 * math.sin(2 * math.pi * 200_000 * t)
        stim.append(adc_encode(v))

    for i in range(256):                                   # dithered DC
        v = 1.6120 + 0.004 * math.sin(2 * math.pi * 97_000 * (i / FS))
        stim.append(adc_encode(v))

    return stim


def sweep(freqs, n_taps=N_TAPS, fs=FS, cycles=400):
    """Drive a pure tone through the model, measure output/input amplitude."""
    rows = []
    for f in freqs:
        m = RollingAverage(n_taps)
        nsamp = max(2048, int(cycles * fs / f))
        nsamp = min(nsamp, 200_000)
        ins, outs = [], []
        for i in range(nsamp):
            v = 1.65 + 1.2 * math.sin(2 * math.pi * f * (i / fs))
            c = adc_encode(v)
            d = m.step(c)
            if i > 4 * n_taps:                             # discard settling
                ins.append(c)
                outs.append(d)
        # peak-to-peak ratio, normalised for the 16x DAC scaling
        vin = (max(ins) - min(ins)) * 16
        vout = max(outs) - min(outs)
        meas = vout / vin if vin else 0.0
        rows.append((f, ideal_boxcar_response(f, n_taps, fs), meas))
    return rows


def main():
    stim = build_stimulus()
    model = RollingAverage(N_TAPS)
    exp = [model.step(s) for s in stim]

    with open(os.path.join(OUT, "stimulus.hex"), "w") as fh:
        fh.write("\n".join(f"{v:02x}" for v in stim) + "\n")
    with open(os.path.join(OUT, "expected.hex"), "w") as fh:
        fh.write("\n".join(f"{v:03x}" for v in exp) + "\n")

    freqs = [1e3, 5e3, 10e3, 15e3, cutoff_hz(N_TAPS, FS), 30e3, 40e3,
             first_null_hz(N_TAPS, FS), 60e3, 80e3, 100e3]
    rows = sweep(freqs)
    with open(os.path.join(OUT, "response.csv"), "w") as fh:
        fh.write("f_hz,H_ideal,H_model\n")
        for f, hi, hm in rows:
            fh.write(f"{f:.1f},{hi:.6f},{hm:.6f}\n")

    print(f"stimulus.hex  {len(stim)} samples")
    print(f"expected.hex  {len(exp)} samples")
    print(f"\n-3 dB cutoff : {cutoff_hz(N_TAPS, FS)/1e3:8.2f} kHz")
    print(f"first null   : {first_null_hz(N_TAPS, FS)/1e3:8.2f} kHz  <- test here\n")
    print(f"{'f (kHz)':>10} {'|H| ideal':>10} {'|H| model':>10} {'dB':>8}")
    for f, hi, hm in rows:
        db = 20 * math.log10(hm) if hm > 1e-6 else float("-inf")
        print(f"{f/1e3:10.2f} {hi:10.4f} {hm:10.4f} {db:8.2f}")


if __name__ == "__main__":
    main()
