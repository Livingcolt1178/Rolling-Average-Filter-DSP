`timescale 1ns / 1ps
module DSP (
    input logic clk_i,              //Clock signal
    input logic rst_i,              //reset signal

    input logic [7:0] DSP_Din,      //The Data coming in from the ADC


    output logic [11:0] DSP_Dout,   //The Data leaving to the DAC
    output logic DSP_ready          //Signal to let the ADC know its ready for more data.
    );

    
endmodule