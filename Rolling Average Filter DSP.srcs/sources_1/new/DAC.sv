`timescale 1ns / 1ps
module DAC (
    input logic clk_i,              //clock signak
    input logic rst_i,              //reset signall

    input logic [11:0] DAC_Din,     //The data coming in that has been processed
    input logic DAC_sync_n,         //works as an enable signal in that when low, dac is busy, when high, idling.
    
    output logic dout,              //Data out from the DAC
    );


endmodule