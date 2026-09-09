# Bench session 2026-09-08 — image archive

Every frame from the retest, including the ones that did not make it into the README or the site. Keysight InfiniiVision MSOX4034A with its built-in WaveGen. Unless a caption says otherwise: sine at 1.20 Vpp on a 1.65 V offset, High-Z, DC coupled, ch1 = ADC input, ch2 = DAC output.

Numbers here are read straight off each screen. The tables in the [README](../../README.md) are derived from them.

## Single-tone sweep

| File | f | Vin | Vout | \|H\| | notes |
|---|---|---|---|---|---|
| `sweep-001kHz.jpg` | 1 kHz | 1.26 V | 1.27 V | 1.008 | both 500 mV/div, 200 µs/div |
| `sweep-010kHz.jpg` | 10 kHz | 1.27 V | 1.19 V | 0.937 | 50 µs/div |
| `sweep-015kHz.jpg` | 15 kHz | 1.26 V | 1.09 V | 0.865 | 20 µs/div |
| `sweep-021kHz63-minus3dB.jpg` | **21.63 kHz** | 1.24 V | 920 mV | **0.742** | the −3 dB point, theory 0.707 |
| `sweep-030kHz.jpg` | 30 kHz | 1.26 V | 670 mV | 0.532 | 10 µs/div |
| `sweep-040kHz.jpg` | 40 kHz | 1.26 V | 320 mV | 0.254 | 5 µs/div |
| `sweep-048kHz83-null-500mVdiv.jpg` | 48.83 kHz | 1.26 V | 70 mV | ≤0.056 | ch2 at 500 mV/div, so 70 mV **is** the scope floor |
| `sweep-048kHz83-null-200mVdiv.jpg` | 48.83 kHz | 1.24 V | 40 mV | ≤0.032 | ch2 zoomed to 200 mV/div |
| `sweep-048kHz83-null-BEST.jpg` | **48.83 kHz** | 1.26 V | **33 mV** | **≤0.026** | best null reading, −31.6 dB, Freq(2) reports Low signal |
| `sweep-060kHz.jpg` | 60 kHz | 1.26 V | 270 mV | 0.214 | Freq(2) tracks the input at 59.995 kHz |
| `sweep-080kHz.jpg` | 80 kHz | 1.27 V | 270 mV | 0.213 | Freq(2) reads 81.689 kHz against 80.056 kHz in — the one spur in the sweep |
| `sweep-100kHz.jpg` | 100 kHz | 1.26 V | 100 mV | ≤0.079 | floor limited |

5 kHz was measured (1.27 V in / 1.26 V out, |H| = 0.992) but not photographed.

The three null frames are worth keeping together. The same null reads 70, 40 and 33 mV depending only on where channel 2's volts-per-division is set, which is the clearest evidence in the whole set that the number is the instrument's floor rather than the filter's output.

## Passband detail

| File | What |
|---|---|
| `passband-1kHz-staircase.jpg` | 1 kHz, both channels 200 mV/div. 1.225 V in, 1.252 V out. The flat steps on the output are the quantization from `>> LOG2_N` then `<< 4`, not noise. |

## Measurement floor

| File | What |
|---|---|
| `floor-dc-input.jpg` | Generator on DC at 1.65 V. Ch1 80 mV at 500 mV/div, ch2 40 mV at 200 mV/div. Two independent paths on the same level, scaling with volts per division, so this is the oscilloscope. |
| `floor-48Hz-accidental.jpg` | The accidental version, generator left at 48.8 **Hz** instead of 48.83 kHz. At 5 µs/div that input is DC across the window, so both channels read 70 mV. Same conclusion, reached by mistake. |

## Two-tone cross-check

1 kHz carrier held fixed, interferer swept, both summed into the ADC through matched resistors. The carrier passes at unity so the leftover ripple is the interferer, and `|H|` falls out of it.

| File | interferer | Vin | Vout | \|H\| implied | from the sweep | ideal |
|---|---|---|---|---|---|---|
| `twotone-1kHz-plus-015kHz.jpg` | 15 kHz | 1.27 V | 1.19 V | 0.874 | 0.865 | 0.852 |
| `twotone-1kHz-plus-020kHz.jpg` | 20 kHz | 1.24 V | 1.12 V | 0.806 | not taken | 0.746 |
| `twotone-1kHz-plus-030kHz.jpg` | **30 kHz** | 1.24 V | 950 mV | **0.532** | **0.532** | 0.485 |
| `twotone-1kHz-plus-040kHz.jpg` | **40 kHz** | 1.26 V | 790 mV | **0.254** | **0.254** | 0.209 |
| `twotone-1kHz-plus-048kHz83-NULL.jpg` | 48.83 kHz | 1.26 V | 670 mV | 0.063 | ≤0.026 | 0.000 |
| `twotone-1kHz-plus-050kHz.jpg` | 50 kHz | 1.26 V | 690 mV | 0.095 | not taken | 0.023 |

30 kHz and 40 kHz agree with the swept measurement to three decimal places, from two experiments that share almost no failure modes.

## Noise rejection

| File | carrier | noise | Vin | Vout |
|---|---|---|---|---|
| `noise-1kHz-25pct.jpg` | 1 kHz | 25% | 1.59 V | 1.31 V |
| `noise-1kHz-50pct.jpg` | 1 kHz | 50% | 1.92 V | 1.32 V |
| `noise-5kHz-63pct.jpg` | 5 kHz | 63% | — | — | 
| `noise-20kHz-63pct.jpg` | 20 kHz | 63% | — | — |

Against a clean reference of 1.225 V in and 1.252 V out, the 50% case turns roughly 695 mV of added mess into 68 mV, about 10:1. Peak-to-peak arithmetic on a sine plus noise is approximate and should be quoted that way. The 5 kHz and 20 kHz frames were taken at 1.00 V/div and 50 µs/div without both Pk-Pk measurements recorded, so they are illustrations rather than data.

## Bench

| File | What |
|---|---|
| `bench-setup-wide.jpg` | Scope, breadboard summing network, laptop and the Spartan Edge Accelerator board. |
| `bench-close-board.jpg` | Close on the board, the resistive summer and the probe connections. |
| `bench-close-board-2.jpg` | Second angle on the same wiring. |

## RTL as built

Screenshots of the source that produced these measurements, so the numbers and the code that made them stay together.

| File | What |
|---|---|
| `rtl-adc-strobe-and-clk.png` | `ADC1173_controller.sv` sample strobe counter. `assign ADC_clk = strob_counter[3]` divides 50 MHz to 3.125 MHz so the ADC1173 runs inside its 15 MSPS rating. |
| `rtl-fifo-and-valid-pulse.png` | `ADC1173_controller.sv` FIFO blocks. The `else` branch in `FIFO_Reading` drives `ADC_valid` low, making it a one cycle pulse instead of the level that caused the original bug. |
| `rtl-filter-window-hold.png` | `rollingAverageFilter.sv` shift register. `samples[i] <= samples[i]` holds the window when `ADC_valid` is low. This had to land together with the pulse fix. |
| `rtl-filter-average-and-scaling.png` | `rollingAverageFilter.sv` average and output scaling. `avg = sum >> LOG2_N` then `filter_Dout <= avg << 4`, the two step scaling that quantizes the output to 12.89 mV steps. |

---

*Photographed 2026-09-08, catalogued 2026-09-09. Phone photos of the screen rather than USB screenshots, which is the one thing I would do differently next time.*

## Cropped versions

Four frames were cropped to the screen bezel so the measurement panel is readable at web size. These are what the README and the site use; the full frames above are the originals.

| Cropped | From |
|---|---|
| `cropped-null-48kHz83.jpg` | `sweep-048kHz83-null-BEST.jpg` |
| `cropped-passband-1kHz.jpg` | `passband-1kHz-staircase.jpg` |
| `cropped-noise-1kHz-50pct.jpg` | `noise-1kHz-50pct.jpg` |
| `cropped-twotone-48kHz83.jpg` | `twotone-1kHz-plus-048kHz83-NULL.jpg` |
