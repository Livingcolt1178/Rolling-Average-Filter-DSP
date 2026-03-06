`timescale 1ns / 1ps
/*
    * File: DAC7311_Controller.sv
    * Project: Rolling Average Filter DSP
    * Author: Nicholas Bramhall
    * date of Release : 4/15/2026
    * Description: This module is the controller for the DAC7311, it will take in the data from the DSP and output it to the DAC for conversion.
*/
module DAC (
    input logic clk_i,              //clock signak
    input logic rst_i,              //reset signall

    input logic [11:0] DAC_Din,     //The data coming in that has been processed
    input logic DAC_sync_n,         //works as an enable signal in that when low, dac is busy, when high, idling.
    
    output logic dout,              //Data out from the DAC
    );


endmodule