`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:     Nicholas Bramhall
// Module Name:  rollingAverageFilter
// Project Name: Rolling Average Filter DSP
// Target:       Spartan-7
// Description:  16-tap rolling average filter. Maintains a running sum over a
//               shift register of 16 8-bit samples. Output is the 12-bit sum
//               right-shifted by 4 (divide by 16). O(1) per cycle: one add,
//               one subtract.
//////////////////////////////////////////////////////////////////////////////////
module rollingAverageFilter (
    input logic clk,
    input logic rst_n,

    input logic [7:0] filter_Din,      //The Data coming in from the ADC

    output logic [11:0] filter_Dout,   //The Data leaving to the DAC
    output logic filter_ready          //Signal to let the ADC know its ready for more data.
    output logic data_valid            //Signal to let the DAC know that the data coming out is valid and can be latched for sending out.
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
            data_valid <= 0; //data is not valid on reset
        end else begin
            filter_Dout <= avg << 4; 
            data_valid <= 1; //Indicate that the data is valid and can be latched by the DAC
        end
    end

    assign filter_ready = 1'b1; //Signal that the DSP is ready for more data

endmodule