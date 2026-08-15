# Rolling Average Filter DSP

### Real-Time Digital Signal Processing on an FPGA

**Nicholas Bramhall · Georgia Tech Computer Engineering**

---

![Hero Image](images/Overview.jpg)

---

> **Status: filter response not validated.** The pipeline runs on hardware, but a bug in the ADC handshake makes the 64-tap build behave as a 4-tap filter (~346 kHz cutoff instead of 21.6 kHz). Root cause is identified and documented in [Known Issues](#known-issues--current-status). Hardware retest is pending. The cutoff figures below are **design targets, not measurements**.

## Overview

This project implements a complete **ADC → DSP → DAC signal processing pipeline** on a Xilinx Spartan-7 FPGA. A rolling average filter is used to attenuate high-frequency components of an analog input signal in real time. The design targets the Spartan Edge Accelerator Board. It runs end to end on hardware, but the measured filter response does **not** match the design target — see [Known Issues](#known-issues--current-status) before using these numbers.

The pipeline captures analog samples via an onboard 8-bit ADC, processes them through a configurable N-tap rolling average filter, and reconstructs the filtered signal through an onboard 12-bit SPI DAC — all running at 50 MHz on a single clock domain.

---

## Key Features

- **Full RTL pipeline** — ADC capture → digital filtering → DAC reconstruction, end to end
- **Configurable tap count** — 4, 8, 16, 32, or 64 taps by changing a single parameter
- **Single clock domain** — all modules synchronous to 50 MHz PLL output, no CDC hazards
- **PLL lock-gated reset** — `internal_rst_n = rst_n & locked` prevents X-state initialization before the clock is stable
- **SPI DAC controller** — 16-bit MSB-first frame serializer with SYNC framing for DAC7311
- **8-entry FIFO** — decouples ADC sampling rate from filter consumption rate
- **Assertion-based testbench** — SVA properties verify FIFO integrity, filter math, and DAC frame correctness

---

## Architecture

The system implements a fully synchronous ADC → DSP → DAC signal processing pipeline operating on a single 50 MHz clock domain.

The input signal is sampled by the onboard ADC and presented on ADC_Din[7:0], sourced from an external waveform generator. These samples are first captured by the ADC1173_Controller module, where they are written into an 8-entry FIFO buffer to decouple ADC sampling timing from downstream processing.

Buffered samples are then forwarded to the central DSP block, the rollingAverageFilter module, where an N-tap moving average is computed using a shift-register-based accumulator. This stage performs real-time low-pass filtering of the incoming signal.

The filtered result is then passed to the DAC7311_Controller module, where it is serialized into a 16-bit SPI frame and synchronized using the DAC SYNC signal. The reconstructed analog output is driven through the onboard DAC and observed on an oscilloscope, completing the real-time closed-loop signal chain.

![schematic](images/schematic.png)

### Submodules

| Module                 | Description                                                                                                                                     |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `ADC1173_Controller`   | Captures 8-bit parallel samples every 16 clock cycles into an 8-entry FIFO. Drives `ADC_clk` and `ADC_en_n` to the physical ADC chip.           |
| `rollingAverageFilter` | Maintains a shift register of N samples. Computes a running sum and outputs a 12-bit average scaled to the DAC's full range.                    |
| `DAC7311_Controller`   | 3-state FSM (IDLE/LOAD/SEND). Serializes a 16-bit SPI frame MSB-first with SYNC framing at 50 MHz.                                              |
| `top_lvl`              | Wires all submodules together. Instantiates `clk_wiz_0` to divide the 100 MHz board oscillator to 50 MHz. Gates reset with PLL `locked` signal. |

---

## Signal Processing

A rolling average filter is a type of **finite impulse response (FIR) low-pass filter**. For N taps:

```
y[n] = (1/N) × Σ x[n-k]  for k = 0 to N-1
```

The cutoff frequency scales inversely with tap count. **These are design targets — the current build does not achieve them, see [Known Issues](#known-issues--current-status):**

```
f_c = 0.443 × f_sample / N
```

With a 50 MHz clock and a strobe every 16 cycles:

| Taps | f_sample  | Cutoff Frequency |
| ---- | --------- | ---------------- |
| 4    | 3.125 MHz | ~346 kHz         |
| 8    | 3.125 MHz | ~173 kHz         |
| 16   | 3.125 MHz | ~86 kHz          |
| 32   | 3.125 MHz | ~43 kHz          |
| 64   | 3.125 MHz | ~21.6 kHz        |

### Scaling Math

The ADC produces 8-bit samples. The DAC expects 12-bit values. The filter preserves full-scale accuracy across both converters:

```
sum  = Σ samples[i]        // up to 14 bits for 64-tap
avg  = sum >> log2(N)      // divide by N
Dout = avg << 4            // scale 8-bit average to 12-bit DAC range
```

The `<< 4` is correct and necessary: the ADC's LSB is 3.3/2^8 = 12.89 mV and the DAC's is 3.3/2^12 = 0.806 mV, a ratio of 16, so an 8-bit code must be scaled by 16 to reproduce the same voltage.

The problem is the order of operations. `(sum >> LOG2_N) << 4` truncates to 8 bits in the middle, and those bits do not come back on the left shift — so the average gets re-quantized onto whole ADC codes and the 12-bit DAC is driven in steps of 16. Averaging N dithered samples recovers about 0.5*log2(N) bits (3 bits at N=64), and this discards all of them. Worst-case error is 15 DAC codes, roughly 12 mV.

Doing the same divide and scale in one step keeps them:

```systemverilog
logic [SUM_BITS+3:0] scaled;
assign scaled      = {sum, 4'b0};                 // x16, the ADC/DAC LSB ratio
assign filter_Dout = scaled[SUM_BITS+3 : LOG2_N]; // /N, all 12 bits kept
```

This is algebraically the same operation — it reduces to `sum >> 2` at N = 64 and `sum << 2` at N = 4 — and it stays correct for any N, which a hardcoded bit-slice would not. When the input carries no sub-LSB information the two forms produce identical output, so this is never worse, only sometimes better.

---

## Repository Structure

```
├── Rolling Average Filter DSP.srcs/
│   ├── sources_1/new/
│   │   ├── top_lvl.sv               # Top-level integration
│   │   ├── ADC1173_Controller.sv    # ADC FIFO controller
│   │   ├── rollingAverageFilter.sv  # N-tap rolling average filter
│   │   └── DAC7311_Controller.sv    # SPI DAC serializer
│   ├── sim_1/
│   │   └── Top_lvl_tb.sv            # Assertion-based testbench
│   └── constrs_1/new/
│       └── Constraints.xdc          # Pin assignments and timing constraints
└── README.md
```

---

## Hardware

| Component          | Part                                        | Description                          |
| ------------------ | ------------------------------------------- | ------------------------------------ |
| FPGA Board         | Spartan Edge Accelerator (XC7S15-1FTGB196C) | Xilinx Spartan-7, 12,800 logic cells |
| ADC                | ADC1173                                     | 8-bit, parallel output, onboard      |
| DAC                | DAC7311IDCKR                                | 12-bit, SPI interface, onboard       |
| Oscilloscope       | Keysight DSOX3014A                          | 100 MHz, 4-channel                   |
| Waveform Generator | Keysight 33500B                             | Used to generate test input signals  |

### Pin Assignments

| Signal         | FPGA Pin                      | Description                        |
| -------------- | ----------------------------- | ---------------------------------- |
| `sys_clk`      | H4                            | 100 MHz board oscillator           |
| `rst_n`        | D14                           | Active-low reset (FPGA_RST button) |
| `ADC_Din[7:0]` | H12/H11/C11/F12/E12/D12/J2/J3 | 8-bit parallel ADC data            |
| `ADC_clk`      | C5                            | Forwarded 50 MHz clock to ADC      |
| `ADC_en_n`     | J4                            | Active-low ADC enable              |
| `DAC_Dout`     | L1                            | SPI data to DAC                    |
| `DAC_sync_n`   | N1                            | SPI SYNC frame signal              |
| `DAC_clk`      | M1                            | SPI clock to DAC                   |

---

## Timing Constraints

| Constraint                                              | Rationale                                        |
| ------------------------------------------------------- | ------------------------------------------------ |
| `create_clock -period 10.0 [sys_clk]`                   | 100 MHz input oscillator                         |
| `set_false_path` on `ADC_clk`, `ADC_en_n`               | Forwarded clock and quasi-static control signals |
| `set_false_path` on `DAC_clk`, `DAC_Dout`, `DAC_sync_n` | DAC latches on its own received clock            |
| `set_multicycle_path -setup 2` on ADC FIFO              | ADC1173 `t_OD = 28ns` exceeds 20ns period        |

---

## Simulation & Verification

The testbench uses **SystemVerilog Assertions (SVA)** to verify pipeline behavior automatically:

| Assertion                  | What It Checks                                      |
| -------------------------- | --------------------------------------------------- |
| `ADC_Write_Check`          | FIFO write data matches ADC input                   |
| `ADC_Read_Check`           | FIFO read data matches stored sample                |
| `filter_calculation_check` | Filter output matches expected rolling average math |
| `DAC_sync_check`           | SYNC goes low one cycle after valid data            |
| `DAC_start_bit_check`      | First transmitted bit is correct                    |
| `DAC_shift_reg_check`      | Shift register advances correctly each cycle        |

### Running Simulation in Vivado

1. Open project in Vivado
2. Add `SIMULATION` to **Simulation Settings → Verilog Defines** (bypasses clk_wiz model)
3. Click **Run Simulation → Run Behavioral Simulation**
4. Verify no assertion failures in the Tcl console

This waveform illustrates the end-to-end data flow through the system, starting from ADC acquisition and ending at DAC output.

The progression can be observed from bottom to top:

-ADC input samples are captured and written into the FIFO buffer
-Data is processed by the rolling average filter (DSP stage)
-The filtered output is serialized and transmitted to the DAC

This confirms correct functional integration across all three major subsystems.

![Waveform](images/Waveform.png)

---

## Key Design Decisions & Lessons Learned

**PLL lock-gated reset** — Synchronous reset flip-flops require a valid clock edge during reset. If `rst_n` deasserts before the PLL locks, registers stay in X state. Gating reset with `locked` (`internal_rst_n = rst_n & locked`) ensures the clock is stable before reset releases.

**Manual understanding** — SPI DAC framing behavior was sensitive to SYNC timing; incorrect deassertion prematurely terminated write cycles, requiring strict alignment with DAC sampling edge and indepth understanding of the manual, and the ability to read it and comprehend it.

**Simple to complex** — In the commit history you can see the original design was a 4 tap design. It was only after that this proved to work that I moved on to the 16 and 64 tap design. Then again I improved it my making it parameterizable so that by changing a single parameter(N in the rollingAverageFilter.sv file), it can be whatever tap count is desireable by the user.

**Testbenching** — In sim_1 its possible to see 4 testbenches despite the final product only using 1. This is because as I went module to module, I testbenched each module to make sure it works which gave confidence moving on that what I had done works properly. yet limitations in my methodology were also shown here, namely in the DAC as talked about in manual understanding. This highlights the need for more assertion based testing which is demonstrated in Top_lvl_tb.

---

## Results

![picture of oscilocope with a 22khz noisy signal using the 64 tap desing](images/22khz_64-tap.webp)

**This section previously claimed the filter worked. It does not, and the correction is more useful than the original claim.**

The image above was read as showing a −3 dB rolloff at the 22 kHz cutoff. It does not show that. Every measurement on the scope is on channel 1 — there is no `Pk-Pk(2)`, so the output amplitude was never actually recorded. The ~600 mVpp figure was estimated by eye from a trace sitting at a different vertical offset than the input, and it was wrong.

What the photo actually shows is the output ripple being just as large as the input ripple, because the filter was not attenuating anything at that frequency. See [Known Issues](#known-issues--current-status) for the root cause.

---

---

## Known Issues & Current Status

Found on 2026-08-15 after a reviewer pointed out that the filtered output looked as noisy as the input. It did. These are open; hardware retest is pending bench access.

### 1. `ADC_valid` never deasserts — the filter runs 16× too fast (blocking)

In `ADC1173_controller.sv`, `ADC_valid` is set on a FIFO read and never cleared:

```systemverilog
if(allow_read) begin
    ADC_Dout  <= fifo[raddr];
    raddr     <= raddr + 1;
    ADC_valid <= 1;        // no else — latches high permanently
end
```

It is a level, not a per-sample pulse. `rollingAverageFilter.sv` gates its shift register on that flag, so the window advances every 50 MHz clock while new samples only arrive every 16 cycles. Each sample is replicated 16 times, so a 64-tap window holds **4 distinct samples**.

The 64-tap build therefore behaves as a 4-tap filter: a ~346 kHz cutoff, not 21.6 kHz. At the 22 kHz test tone that is |H| = 0.9988 — about 0.01 dB, or no attenuation at all.

Fix: default `ADC_valid` low every cycle and raise it for one cycle on `allow_read`.

### 2. Clearing the sample window when `ADC_valid` is low (blocking, coupled to #1)

```systemverilog
end else begin
    samples[i] <= 0;    // wipes all N taps
end
```

Currently dead code, because #1 pins `ADC_valid` high. **Fixing #1 without also removing this makes the design worse** — the window would be cleared on the 15 idle cycles between samples, leaving `filter_Dout = filter_Din / 4` with no averaging at all. The two must be fixed together. The correct behaviour is to hold state, not clear it.

### 5. No reset synchronizer

`internal_rst_n = locked && rst_n` is combinational from an async pushbutton and is used as an async reset (`negedge rst_n`) in every module. Recovery/removal timing is unconstrained, so reset release can go metastable. Should be async-assert / sync-deassert.

### 6. Documentation and code disagree

`rollingAverageFilter.sv`'s header claims "O(1) per cycle: one add, one subtract." The implementation is a 64-deep combinational adder chain recomputed every cycle. Either implement the running sum (`sum <= sum + filter_Din - samples[N-1]`) or fix the comment. The running sum is also what would make the "scales to ~2,000 taps" claim defensible.

Minor: `data_valid` is permanently high after reset, so the DAC free-runs at 3.125 MHz rather than firing on new filter output. Same rate as the ADC but not phase-locked to it, so samples will occasionally be duplicated or dropped. Worth pulsing off `ADC_valid` once #1 is fixed.

Note on clocking, since it reads oddly at first: the board oscillator is fixed at 100 MHz, so `Constraints.xdc` correctly declares a 10 ns period on `sys_clk`, and the clocking wizard divides that to the 50 MHz the design actually runs on. The comment above the constraint describes the internal clock rather than the pin.

### What the verification missed

Two methodology failures, which are the part worth keeping:

**The testbench drove held constants.** A moving average of a constant returns that constant, so `filter_calculation_check` passes identically whether the filter works or is replaced by a wire. It proved the adder, not the filter. A swept-sine or multi-tone stimulus checked against a golden model would have caught this immediately.

**The bench test was run at the worst possible frequency.** At the −3 dB point the expected change is only a 30% reduction in ripple — invisible on a scope photo with the two channels at different vertical offsets. The first null at `f_s/N` = 48.8 kHz is where a working filter shows near-total cancellation and a broken one obviously does not. Testing at the null first, then filling in the curve, is the right order.

The planned retest is a single-tone sweep at 1, 5, 10, 21.6, 30, 40 and 48.8 kHz with `Pk-Pk` measured on **both** channels, plotted against the ideal sinc response.

## How To Build

### Prerequisites

- Xilinx Vivado 2025.2
- Spartan Edge Accelerator Board
- FAT32-formatted micro SD card

### Steps

1. Clone the repository

```bash
git clone https://github.com/Livingcolt1178/Rolling-Average-Filter-DSP
```

2. follow the steps in board's parent repostitory, https://github.com/SeeedDocument/Spartan-Edge-Accelerator-Board/tree/master, to program using either slave or JTAG. Make sure to swap the given test files to the sources from this repository. It may be neccesary after adding all the files to create a clocking wizard. This can be done through the IP heirarchy. Set the input clock to sys_clk, and set the rate of the output clock to 50mhz, do not change the name of the ouput clock.

3. create a circuit that makes a mixed AC signal. Make sure that the volage doesn't go below 0.0V and above 3.3V, other there could be possible damage to the ADC.

4. Once programmed, connect waveform generator/mixed AC signal to the **ADC input header pin** and oscilloscope to the **DAC output header pin**

---

## About

This project was built to learn the full hardware design flow — from RTL architecture through timing closure to bring-up on real hardware, including the part where you find out your verification methodology was not good enough to catch a real bug. It covers FPGA design fundamentals including synchronous reset design, clock domain management, SPI protocol implementation, FIFO design, and constraint-driven timing closure in Vivado.

**Georgia Tech · ECE · Computer Engineering · 2026**
