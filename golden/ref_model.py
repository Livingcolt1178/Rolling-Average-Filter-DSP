#!/usr/bin/env python3
"""
Golden reference model for the N-tap rolling average filter.

Written from the SPECIFICATION, not from the RTL. That distinction is the whole
point: a reference model derived by reading the DUT reproduces the DUT's bugs and
proves nothing.

Spec, in words:
  - One new sample enters the window per ADC sample period (NOT per clock).
  - y[n] = (1/N) * sum(x[n-k], k=0..N-1)
  - The 8-bit average is scaled to the DAC's 12-bit range by x16, because
    ADC LSB = VREF/2^8 and DAC LSB = VREF/2^12.
  - Divide and scale are applied as one operation so the average is not
    re-quantized onto whole ADC codes:  Dout = (sum << 4) >> log2(N)
"""

import math

VREF = 3.3


class RollingAverage:
    """Sample-rate reference model. One step() call == one ADC sample."""

    def __init__(self, n_taps=64, adc_bits=8, dac_bits=12):
        assert n_taps & (n_taps - 1) == 0, "N must be a power of two"
        self.N = n_taps
        self.log2n = int(math.log2(n_taps))
        self.adc_bits = adc_bits
        self.dac_bits = dac_bits
        self.shift_up = dac_bits - adc_bits          # 4 for 8 -> 12
        self.window = [0] * n_taps

    def reset(self):
        self.window = [0] * self.N

    def step(self, sample):
        """Push one ADC sample, return the 12-bit DAC code."""
        assert 0 <= sample < (1 << self.adc_bits)
        self.window.insert(0, sample)
        self.window.pop()
        s = sum(self.window)
        return (s << self.shift_up) >> self.log2n

    # --- the form currently in the RTL, kept so the loss is measurable ---
    def step_lossy(self, sample):
        self.window.insert(0, sample)
        self.window.pop()
        s = sum(self.window)
        avg = s >> self.log2n                        # truncate to 8 bits
        return avg << self.shift_up                  # then re-expand


def adc_encode(volts, bits=8, vref=VREF):
    """Voltage -> code. Mirrors how a real converter chunks its range."""
    code = int(volts / vref * (1 << bits))
    return max(0, min((1 << bits) - 1, code))


def dac_decode(code, bits=12, vref=VREF):
    return code / (1 << bits) * vref


def ideal_boxcar_response(f, n_taps, fs):
    """|H(f)| for an N-point moving average. The analytic curve to measure against."""
    if f == 0:
        return 1.0
    num = math.sin(math.pi * f * n_taps / fs)
    den = n_taps * math.sin(math.pi * f / fs)
    if den == 0:
        return 0.0
    return abs(num / den)


def cutoff_hz(n_taps, fs):
    """-3 dB point of an N-point boxcar."""
    return 0.443 * fs / n_taps


def first_null_hz(n_taps, fs):
    """First zero of the response. The frequency to photograph."""
    return fs / n_taps
