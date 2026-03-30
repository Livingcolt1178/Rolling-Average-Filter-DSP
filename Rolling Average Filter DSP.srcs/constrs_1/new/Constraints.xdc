##############################################################
# Engineer:     Nicholas Bramhall
# Project:      Rolling Average Filter DSP
# Target:       Spartan-7 XC7S15 (Spartan-Edge-Accelerator)
# Description:  Timing constraints for ADC->DSP->DAC pipeline.
#               System clock 50MHz. ADC1173 parallel input.
#               DAC7311 SPI output.
##############################################################

##############################################################
# SYSTEM CLOCK
# 50MHz = 20ns period. This is the master clock for the entire
# design — all three submodules run in the same clock domain.
##############################################################
create_clock -period 20.000 -name sys_clk -waveform {0.000 10.000} [get_ports clk]

set_property PACKAGE_PIN H4       [get_ports clk]
set_property IOSTANDARD  LVCMOS33 [get_ports clk]

##############################################################
# RESET
# Active low, connected to user pushbutton on D14.
##############################################################
set_property PACKAGE_PIN D14      [get_ports rst_n]
set_property IOSTANDARD  LVCMOS33 [get_ports rst_n]

##############################################################
# ADC1173 INPUT TIMING
# The ADC is clocked by ADC_clk, driven directly from sys_clk.
# t_OD = 28ns (CLK rise to data valid, worst case)
# t_OH = 15ns (output hold time, data stays valid this long)
#
# 28ns exceeds the 20ns clock period, so a multicycle path
# exception is applied below. The FIFO only writes on the
# strobe (every 16 cycles), giving data far more than 28ns
# to settle before it is captured.
##############################################################
set_input_delay -clock sys_clk -max 28.000 [get_ports {ADC_Din[*]}]
set_input_delay -clock sys_clk -min 15.000 [get_ports {ADC_Din[*]}]

set_property PACKAGE_PIN H12      [get_ports {ADC_Din[7]}]
set_property PACKAGE_PIN H11      [get_ports {ADC_Din[6]}]
set_property PACKAGE_PIN C11      [get_ports {ADC_Din[5]}]
set_property PACKAGE_PIN F12      [get_ports {ADC_Din[4]}]
set_property PACKAGE_PIN E12      [get_ports {ADC_Din[3]}]
set_property PACKAGE_PIN D12      [get_ports {ADC_Din[2]}]
set_property PACKAGE_PIN J2       [get_ports {ADC_Din[1]}]
set_property PACKAGE_PIN J3       [get_ports {ADC_Din[0]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {ADC_Din[*]}]

##############################################################
# MULTICYCLE PATH: ADC_Din -> FIFO
# Vivado defaults to one cycle for all paths. We tell it the
# FIFO write registers have two cycles to meet setup, giving
# 40ns total — enough margin for the 28ns t_OD.
##############################################################
set_multicycle_path -setup -from [get_ports {ADC_Din[*]}] -to [get_cells {adc_ctrl/fifo_reg[*][*]}] 2
set_multicycle_path -hold  -from [get_ports {ADC_Din[*]}] -to [get_cells {adc_ctrl/fifo_reg[*][*]}] 1

##############################################################
# ADC CONTROL OUTPUTS
# ADC_clk is sys_clk forwarded to the ADC for clocking.
# ADC_en_n is driven by the FIFO full flag — it changes at
# most once per several hundred cycles so timing analysis
# on it is not meaningful.
##############################################################
set_false_path -to [get_ports ADC_clk]
set_false_path -to [get_ports ADC_en_n]

set_property PACKAGE_PIN C5       [get_ports ADC_clk]
set_property IOSTANDARD  LVCMOS33 [get_ports ADC_clk]

set_property PACKAGE_PIN J4       [get_ports ADC_en_n]
set_property IOSTANDARD  LVCMOS33 [get_ports ADC_en_n]

##############################################################
# DAC7311 OUTPUT TIMING
# DAC_Dout and DAC_sync_n are registered outputs that the
# DAC latches on the falling edge of DAC_clk (sys_clk).
# t5 = 5ns data setup before falling SCLK edge
# t6 = 4.5ns data hold after falling SCLK edge
#
# DAC_clk is sys_clk forwarded directly to the DAC. Routing
# it through fabric adds unpredictable delay, so it is marked
# as a false path — the DAC and FPGA share the same clock
# source so no setup/hold relationship needs to be checked.
##############################################################
set_output_delay -clock sys_clk -max  5.000 [get_ports DAC_Dout]
set_output_delay -clock sys_clk -min -4.500 [get_ports DAC_Dout]

set_output_delay -clock sys_clk -max  5.000 [get_ports DAC_sync_n]
set_output_delay -clock sys_clk -min -4.500 [get_ports DAC_sync_n]

set_false_path -to [get_ports DAC_clk]

set_property PACKAGE_PIN L1       [get_ports DAC_Dout]
set_property IOSTANDARD  LVCMOS33 [get_ports DAC_Dout]

set_property PACKAGE_PIN N1       [get_ports DAC_sync_n]
set_property IOSTANDARD  LVCMOS33 [get_ports DAC_sync_n]

set_property PACKAGE_PIN M1       [get_ports DAC_clk]
set_property IOSTANDARD  LVCMOS33 [get_ports DAC_clk]