module Contorller (
input logic clk_i,          //clk
input logic rst_i,          //rst

input logic ADC_Dout,       //data from ADC
input logic DSP_Dout,       //data from DSP
input logic DSP_ready,      //lets the ADC know its ready for data

output logic ADC_en_n,      //turns on the ADC
output logic DSP_Din,       //Data being sent to the DSP
output logic DAC_Din,       //Data being sent to the DAC
output logic DAC_sync_n,    //busy when low, idling when High.

);
endmodule