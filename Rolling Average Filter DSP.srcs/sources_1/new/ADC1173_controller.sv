`timescale 1ns / 1ps
/*
    * File: ADC1173_controller.sv
    * Project: Rolling Average Filter DSP
    * Author: Nicholas Bramhall
    * date of Release : 4/15/2026
    * Description: This module is the controller for the ADC1173, it will take in the data from the waveform generator and output it to the FPGA for filtering. 
    It will also handle the enable signal for the ADC and the reset signal for the ADC. The enable and reset are active low.
    The data coming in from the waveform generator will be 8 bits and the data going out to the FPGA will also be 8 bits.
*/

module ADC(
    input logic clk,             
    input logic rst_n,        

    input logic [7:0] ADC_Din,      //Data coming in from the waveform generator
    input logic rd_en,              //read enable signal, allows the filter to read the samples.
    input logic sample_en,          //Enable signal for sampling, allows the ADC to take a sample every 16 cycles, for control over sampling when testing.

    output logic ADC_en_n,          //Enable signal for the ADC, Active low, allows sampling
    output logic ADC_clk,           //Clock signal for the ADC
    output logic [7:0] ADC_Dout,    //The Data leaving the ADC to the FPGA for filter
    output logic fifo_empty,        //lets the filter know if we have data
    output logic fifo_full          //lets the filter know if we need to turn off the ADC
    );

    // --------------------------------------------------------
    // Sample strobe
    // flags for sampling every 16 cycles
    // --------------------------------------------------------

    logic [3:0]strob_counter;
    logic sample_strobe;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            strob_counter <= 0;
        end else begin
            if(strob_counter == 15) begin
                strob_counter <= 0;
            end else begin
                strob_counter <= strob_counter + 1;
            end
        end
    end
    assign sample_strobe = (strob_counter == 4'd15);

    assign ADC_clk = clk;

    // --------------------------------------------------------
    // Data Handling FIFO structure
    // --------------------------------------------------------
    logic [7:0] fifo [0:7];        //FIFO structure to hold the samples coming in from the ADC, it can hold up to 8 samples.
    logic [2:0] waddr;             //write address for the FIFO
    logic [2:0] raddr;             //read address for the FIFO
    logic [3:0] count;             //counter to keep track of how many samples are in the FIFO, 
    logic allow_read;             //flag to allow reading from the FIFO, only allows reading if the FIFO is not empty and read enable is high
    logic allow_write;            //flag to allow writing to the FIFO, only allows writing if
    
    assign fifo_full = (count == 4'd8);
    assign fifo_empty = (count == 4'd0);
    assign ADC_en_n = fifo_full; //if the FIFO is full, we need to turn off the ADC to prevent overflow, otherwise we can keep it on.
    assign allow_read = rd_en && !fifo_empty;
    assign allow_write = sample_strobe && !fifo_full && sample_en;

    always_ff @(posedge clk or negedge rst_n) begin : FIFO_Writing
        if(!rst_n) begin
            waddr <= 0;
            for (int i = 0; i < 8; i++)begin
                fifo[i] <= 8'h00;
            end
        end else begin
            if(allow_write) begin
                fifo[waddr] <= ADC_Din; //write the incoming data from the ADC to the FIFO at the current write address
                waddr <= waddr + 1; 
            end
        end
    end : FIFO_Writing

    always_ff @(posedge clk or negedge rst_n) begin : FIFO_Reading
        if(!rst_n) begin
            raddr <= 0;
            ADC_Dout <= 8'h00;
        end else begin 
            if(allow_read) begin
                ADC_Dout <= fifo[raddr];
                raddr <= raddr + 1; 
            end else begin
            ADC_Dout <= 8'h00;  // FIX: don't hold stale value
            end
        end
    end : FIFO_Reading

    always_ff @( posedge clk or negedge rst_n ) begin : FIFO_Counter
        if(!rst_n) begin
            count <= 0;
        end else begin
            case({(allow_read),(allow_write)}) //check if we are reading and not empty, and if we are writing and not full and ADC is enabled
                2'b01:   count <= count + 1;    //if write only, count adds one
                2'b10:   count <= count - 1;    //if read only, count subtracts one
                2'b11:   count <= count;        //if read and write at same time, count stays same
                default: count <= count;
            endcase
        end
    end : FIFO_Counter

endmodule
