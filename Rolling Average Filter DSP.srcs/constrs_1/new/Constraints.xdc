
# ADC Constraints
# ADC Enable
set_property PACKAGE_PIN J4       [get_ports A_OE_n]
set_property IOSTANDARD  LVCMOS33 [get_ports A_OE_n]

# ADC Data Bus [7:0]
set_property PACKAGE_PIN H12      [get_ports {ADC_Din[7]}]
set_property PACKAGE_PIN H11      [get_ports {ADC_DDin[6]}]
set_property PACKAGE_PIN C11      [get_ports {ADC_DDin[5]}]
set_property PACKAGE_PIN F12      [get_ports {ADC_DDin[4]}]
set_property PACKAGE_PIN E12      [get_ports {ADC_DDin[3]}]
set_property PACKAGE_PIN D12      [get_ports {ADC_DDin[2]}]
set_property PACKAGE_PIN J2       [get_ports {ADC_DDin[1]}]
set_property PACKAGE_PIN J3       [get_ports {ADC_DDin[0]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {ADC_DDin[*]}]


# DAC CONSTRAINTS
set_property PACKAGE_PIN N1       [get_ports DAC_sync_n]
set_property IOSTANDARD  LVCMOS33 [get_ports DAC_sync_n]

set_property PACKAGE_PIN M1       [get_ports DAC_clk]
set_property IOSTANDARD  LVCMOS33 [get_ports DAC_clk]

set_property PACKAGE_PIN L1       [get_ports DAC_dout]
set_property IOSTANDARD  LVCMOS33 [get_ports DAC_dout]
