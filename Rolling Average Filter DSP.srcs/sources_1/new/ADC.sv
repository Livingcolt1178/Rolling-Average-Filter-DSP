`timescale 1ns / 1ps

module ADC(
    input logic clk_i,              //Clock for the ADC
    input logic rst_i,              //Reset signal for the ADC

    input logic [7:0] ADC_Din,      //Data cooming in from the waveform generator
    input logic ADC_en_n,           //Enable signal for the ADC, Active low

    output logic [7:0] ADC_Dout,    //The Data leaving the ADC to the FPGA for DSP
    
    );







endmodule
