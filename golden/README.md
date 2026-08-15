# Golden reference model

Independent reference for the N-tap rolling average filter, plus vector
generation and a frequency-response sweep.

**The model is written from the specification, not from the RTL.** A reference
transcribed from the design under test agrees with it by construction and cannot
catch a design bug — which is how the `ADC_valid` defect survived a passing
testbench.

## Files

| File | Purpose |
|---|---|
| `ref_model.py` | Sample-rate model of the filter, plus ADC/DAC voltage encoding and the analytic boxcar response |
| `gen_vectors.py` | Writes `stimulus.hex` / `expected.hex` for `$readmemh`, and `response.csv` for the sweep |
| `rollingAverageFilter_ref_tb.sv` | Self-checking testbench with an inline SV reference model |
| `rollingAverageFilter_fixed.sv` | Corrected filter: window holds when `ADC_valid` is low, one-step divide-and-scale |

## Running

```bash
python3 gen_vectors.py
iverilog -g2012 -o sim ../path/to/rollingAverageFilter.sv rollingAverageFilter_ref_tb.sv
vvp sim
```

## Why the stimulus looks the way it does

A moving average of a held constant returns that constant, so constant stimulus
cannot distinguish a working filter from a wire. The vectors include an impulse
(reveals the true window length), steps (settling must take exactly N samples),
a two-tone passband/stopband pair, and dithered DC (exercises sub-LSB
resolution).

## Bench retest

`response.csv` is the curve to measure against. Test at the **first null**,
f_s/N = 48.83 kHz, not at the -3 dB point: at cutoff the expected change is only
a 30% reduction in ripple, which is invisible on a scope photo. At the null a
working filter shows near-total cancellation and a broken one obviously does not.
