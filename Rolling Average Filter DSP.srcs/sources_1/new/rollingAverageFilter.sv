`timescale 1ns / 1ps
/*
    * File: rollingAverageFilter.sv
    * Project: Rolling Average Filter DSP
    * author: Nicholas Bramhall
    * date of Release : 4/15/2026
    * Description: This module is the DSP for the rolling average filter, it will take in the data from the ADC and output it to the DAC after processing. 
    The processing will be a rolling average filter that takes in 8 samples and outputs the average of those samples. 
    The input data will be 8 bits and the output data will be 12 bits.
    */
module DSP (
    input logic clk_i,              //Clock signal
    input logic rst_i,              //reset signal

    input logic [7:0] DSP_Din,      //The Data coming in from the ADC


    output logic [11:0] DSP_Dout,   //The Data leaving to the DAC
    output logic DSP_ready          //Signal to let the ADC know its ready for more data.
    );

    
endmodule