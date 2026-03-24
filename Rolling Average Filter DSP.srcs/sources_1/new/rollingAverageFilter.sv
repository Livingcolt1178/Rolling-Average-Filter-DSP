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
module rollingAverageFilter (
    input logic clk,
    input logic rst_n,

    input logic [7:0] filter_Din,      //The Data coming in from the ADC

    output logic [11:0] filter_Dout,   //The Data leaving to the DAC
    output logic filter_ready          //Signal to let the ADC know its ready for more data.
);
    logic [7:0] samples [3:0];
    logic [9:0] sum;
    logic [7:0] avg;

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            for(int i = 0; i < 4; i++) begin
                samples[i] <= 8'b0; //reset the samples to 0 on reset
            end
        end else begin
            samples[3] <= samples[2]; //shift in the new data, the oldest data will be overwritten.
            samples[2] <= samples[1]; //shift in the new data, the oldest data will be overwritten.
            samples[1] <= samples[0]; //shift in the new data, the oldest data will be overwritten.
            samples[0] <= filter_Din; //shift in the new data, the oldest data will be overwritten.
        end
    end
    //========================================================
    // Rolling Average Calculation
    //========================================================
    always_comb begin
        if(!rst_n) begin
            sum = 0; 
        end else begin
        sum = samples[0] + samples[1] + samples[2] + samples[3];
        end
    end
    assign avg = sum >> 2; //divide the sum by 4 to get the average, this is done by shifting right by 2 bits.
    
    always_ff @( posedge clk ) begin
        if(!rst_n) begin
            filter_Dout <= 0; //reset the average to 0 on reset
        end else begin
            filter_Dout <= avg << 4; 
        end
    end

    assign filter_ready = 1'b1; //Signal that the DSP is ready for more data

endmodule