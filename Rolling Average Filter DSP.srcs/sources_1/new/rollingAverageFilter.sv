`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:     Nicholas Bramhall
// Module Name:  rollingAverageFilter
// Project Name: Rolling Average Filter DSP
// Target:       Spartan-7
// Description:  N-tap rolling average filter. Maintains a running sum over a
//               shift register of N 8-bit samples. Output is the 12-bit sum
//               right-shifted by log2(N) (divide by N). O(1) per cycle: one add,
//               one subtract.
//////////////////////////////////////////////////////////////////////////////////
module rollingAverageFilter (
    input logic clk,
    input logic rst_n,

    input logic [7:0] filter_Din,      //The Data coming in from the ADC

    output logic [11:0] filter_Dout,   //The Data leaving to the DAC
    output logic filter_ready,          //Signal to let the ADC know its ready for more data.
    output logic data_valid             //Signal to let the DAC know that the data coming out is valid and can be latched for sending out.
    );
                          
    localparam N        = 64;           //number of taps, used for shifting to calculate average
    localparam LOG2_N   = $clog2(N);    //Don't change this, it is used to calculate the number of bits needed for the sum to prevent overflow, and for shifting to calculate the average.
    localparam SUM_BITS = 8 + LOG2_N;   //Dont' change this, it is used to calculate the number of bits needed for the sum to prevent overflow, and for shifting to calculate the average.

    logic [7:0] samples [N-1:0];                
    logic [SUM_BITS-1:0] sum;           //to increase taps past 64 taps, increase bit width to prevent overflow.
    logic [7:0] avg;

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            for(int i = 0; i < N; i++) begin   //to increase taps, increase the loop count for reset
                samples[i] <= 8'b0;            //reset the samples to 0 on reset
            end

        end else begin
            for(int i = N-1; i > 0; i--) begin
                samples[i] <= samples[i-1];
            end
            samples[0] <= filter_Din;           //shift in the new data, the oldest data will be overwritten.
        end
    end

    //========================================================
    // Rolling Average Calculation
    //========================================================
    always_comb begin
        if(!rst_n) begin
            sum = 0; 
        end else begin
            sum = '0;
            for(int i = 0; i < N; i++) begin
                sum += samples[i];
            end
        end
    end
    assign avg = sum >> LOG2_N; //divide the sum by the log2 of the number of taps to get the average, I.E, right shift by 6 for 64 taps.
    
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