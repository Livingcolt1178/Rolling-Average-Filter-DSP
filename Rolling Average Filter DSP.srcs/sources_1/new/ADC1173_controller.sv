`timescale 1ns / 1ps
/*
    * File: ADC1173_controller.sv
    * Project: Rolling Average Filter DSP
    * Author: Nicholas Bramhall
    * date of Release : 4/15/2026
    * Description: This module is the controller for the ADC1173, it will take in the data from the waveform generator and output it to the FPGA for DSP. 
    It will also handle the enable signal for the ADC and the reset signal for the ADC. The enable and reset are active low.
    The data coming in from the waveform generator will be 8 bits and the data going out to the FPGA will also be 8 bits.
*/

module ADC(
    input logic clk,             
    input logic rst_n,        

    input logic [7:0] ADC_Din,      //Data coming in from the waveform generator
    input logic ADC_en_n,           //Enable signal for the ADC, Active low

    output logic ADC_clk,           //Clock signal for the ADC
    output logic [7:0] ADC_Dout     //The Data leaving the ADC to the FPGA for DSP
    
    );

    // --------------------------------------------------------
    // Clock Divider 
    // divides the clock by 9 for every half period as the Dac needs 18 cycles for every 1 cycle of the ADC.
    // --------------------------------------------------------

    logic [3:0]counter;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ADC_clk <= 0;
            counter <= 0;
        end else begin
            if(counter == 8) begin
                ADC_clk <= ~ADC_clk;
                counter <= 0;
            end else begin
                counter <= counter + 1;
            end
        end
    end

    // --------------------------------------------------------
    // Data Handling
    // --------------------------------------------------------
    logic [7:0] buffer_reg [0:7];   //register to hold the last 8 samples for the rolling average filter
    logic [2:0] waddr;              //write address for the buffer register
    logic buf_full;                 //flag to indicate when the buffer is full for the first time

    always_ff @(posedge ADC_clk or negedge rst_n) begin
        if (!rst_n) begin
            ADC_Dout <= 8'h00;
            waddr    <= 3'd0;
            buf_full <= 1'b0;
            for (int i = 0; i < 8; i++) begin
                buffer_reg[i] <= 8'h00;
            end
        end else if (!ADC_en_n) begin

            // Always write new sample into circular buffer
            buffer_reg[waddr] <= ADC_Din;

            // Increment and wrap write pointer
            if (waddr == 3'd7) begin
                waddr    <= 3'd0;
                buf_full <= 1'b1;   // Buffer is full after first pass
            end else begin
                waddr <= waddr + 1;
            end

            // Only output once buffer has been filled once
            if (buf_full) begin
                // Output oldest sample (one ahead of write pointer)
                ADC_Dout <= buffer_reg[waddr];
            end else begin
                ADC_Dout <= 8'h00;
            end

        end else begin
            ADC_Dout <= 8'h00;  // ADC disabled — drive output to 0
        end
    end

endmodule
