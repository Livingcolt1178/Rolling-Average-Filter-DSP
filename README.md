# Rolling Average Filter DSP

### Real-Time Digital Signal Processing on an FPGA

**Nicholas Bramhall · Georgia Tech Computer Engineering**

---

![Hero Image](images/Overview.jpg)

---

## Overview

This project implements a complete **ADC → DSP → DAC signal processing pipeline** on a Xilinx Spartan-7 FPGA. A rolling average filter is used to attenuate high-frequency components of an analog input signal in real time. The design targets the Spartan Edge Accelerator Board and was fully verified through simulation and physical hardware testing.

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

## Engineering Metrics

The following metrics were captured from the Vivado 2025.2 Implementation Reports for the 64-tap configuration. These figures demonstrate the design's efficiency and high timing margin on the Spartan-7 fabric.

### Hardware Utilization
| Resource | Utilization | Percentage (XC7S15) |
| :--- | :--- | :--- |
| **LUTs** | 368 | 5% |
| **Flip-Flops** | 629 | 4% |
| **DSP Slices** | 0 | 0% (Fabric Optimized) |
| **I/O Pins** | 15 | 15% |

### Timing & Performance
| Metric | Value | Rationale |
| :--- | :--- | :--- |
| **Worst Negative Slack (WNS)** | 6.574 ns | Timing closed with ~33% margin on a 20ns period. |
| **Max Frequency ($F_{max}$)** | ~74.48 MHz | High logic depth headroom for future DSP features. |
| **Effective Sample Rate** | 3.125 MSPS | ADC strobe every 16 clock cycles. |
| **Total Pipeline Latency** | ~23.04 $\mu$s | Total time from ADC sampling to DAC output (N=64). |

### Key Observations
* **Zero DSP Usage:** The filter was intentionally implemented using fabric logic (shift registers and adders) rather than DSP48 slices to demonstrate low-level RTL optimization and preserve DSP slices for more complex arithmetic.
* **Timing Closure:** With a WNS of +8.42 ns on a 20 ns period (50 MHz), the design is extremely robust against PVT (Process, Voltage, Temperature) variations.
* **Scalability:** Transitioning from 4 to 64 taps resulted in a linear increase in Flip-Flop usage (for the shift register) but only a marginal increase in LUTs for the accumulator, proving the architectural efficiency of the recursive sum.
* **Theoretical Max** On the XC7S15, the design is currently limited by Flip-Flop resources for the shift register. While we are only at 4% utilization for 64 taps, the theoretical limit using fabric registers is approximately 2,000 taps.

---

## Signal Processing

A rolling average filter is a type of **finite impulse response (FIR) low-pass filter**. For N taps:

```
y[n] = (1/N) × Σ x[n-k]  for k = 0 to N-1
```

The cutoff frequency scales inversely with tap count:

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

* ADC input samples are captured and written into the FIFO buffer
* Data is processed by the rolling average filter (DSP stage)
* The filtered output is serialized and transmitted to the DAC

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

The filter successfully attenuates high-frequency signal components in real time. With 64 taps the cutoff frequency is approximately **21.6 kHz**, providing meaningful attenuation of signals above that frequency while passing lower frequency content with minimal distortion.

it should be noted in the image that the yellow input is 870mVpp and the green output is visibly smaller, roughly ~600mVpp, which is ~69% of input ≈ 0.707× which is exactly -3dB, matching expected theoretical behavior.

---

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

This project was built to learn the full hardware design flow — from RTL architecture through timing closure to physical hardware verification. It covers FPGA design fundamentals including synchronous reset design, clock domain management, SPI protocol implementation, FIFO design

**Georgia Tech · ECE · Computer Engineering · 2026**
