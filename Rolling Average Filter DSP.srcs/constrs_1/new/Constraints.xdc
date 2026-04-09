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
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports sys_clk]

set_property PACKAGE_PIN H4 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]

##############################################################
# RESET
# Active low, connected to user pushbutton on D14.
##############################################################
set_property PACKAGE_PIN D14 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property PACKAGE_PIN H12 [get_ports {ADC_Din[7]}]
set_property PACKAGE_PIN H11 [get_ports {ADC_Din[6]}]
set_property PACKAGE_PIN C11 [get_ports {ADC_Din[5]}]
set_property PACKAGE_PIN F12 [get_ports {ADC_Din[4]}]
set_property PACKAGE_PIN E12 [get_ports {ADC_Din[3]}]
set_property PACKAGE_PIN D12 [get_ports {ADC_Din[2]}]
set_property PACKAGE_PIN J2 [get_ports {ADC_Din[1]}]
set_property PACKAGE_PIN J3 [get_ports {ADC_Din[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_Din[*]}]

set_property PACKAGE_PIN C5 [get_ports ADC_clk]
set_property IOSTANDARD LVCMOS33 [get_ports ADC_clk]

set_property PACKAGE_PIN J4 [get_ports ADC_en_n]
set_property IOSTANDARD LVCMOS33 [get_ports ADC_en_n]

set_property PACKAGE_PIN L1 [get_ports DAC_Dout]
set_property IOSTANDARD LVCMOS33 [get_ports DAC_Dout]

set_property PACKAGE_PIN N1 [get_ports DAC_sync_n]
set_property IOSTANDARD LVCMOS33 [get_ports DAC_sync_n]

set_property PACKAGE_PIN M1 [get_ports DAC_clk]
set_property IOSTANDARD LVCMOS33 [get_ports DAC_clk]