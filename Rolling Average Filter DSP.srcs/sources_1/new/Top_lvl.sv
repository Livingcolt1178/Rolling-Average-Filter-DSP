//////////////////////////////////////////////////////////////////////////////////
// Engineer:     Nicholas Bramhall
// Module Name:  top_lvl
// Project Name: Rolling Average Filter DSP
// Target:       Spartan-7
// Description:  Top-level integration module. Wires together the ADC1173
//               controller, 16-tap rolling average filter, and DAC7311
//               controller into a complete ADC -> DSP -> DAC pipeline.
//////////////////////////////////////////////////////////////////////////////////
module top_lvl (
    input logic clk,
    input logic rst_n,
    
    input logic [7:0] ADC_Din,  //Data coming in from the waveform generator
    output logic ADC_clk,        //Clock signal for the ADC, used for debugging to make sure the clock is running and connected properly.
    output logic ADC_en_n,       //Enable signal for the ADC, Active low, allows sampling, used for debugging to make sure we are enabling the ADC properly.
    
    output logic DAC_Dout,       //Data coming out of the DAC to the oscilloscope
    output logic DAC_sync_n,    //works as an enable signal in that when low, dac is busy, when high, idling.
    output logic DAC_clk        //Clock signal for the DAC, used for debugging to make sure the clock is running and connected properly.
 
);
    //wires to connect the modules together
    logic rd_en;                //read enable signal, allows the filter to read the samples.
    logic sample_en;            //Enable signal for sampling, allows the ADC to take a sample every 16 cycles, for control over sampling when testing.

    logic [7:0] ADC_Dout;       //Data coming out of the ADC to the filter

    logic [11:0] filter_Dout;   //Data coming out of the filter to the DAC
    logic data_valid;           //signal to let the DAC know that the data coming in is valid

    assign sample_en = 1; //always enable sampling for now, we can use this to control sampling when testing.
    //instantiate ADC controller
    ADC1173_Controller adc_ctrl (
        .clk(clk),
        .rst_n(rst_n),

        .ADC_Din(ADC_Din),
        .rd_en(rd_en),
        .sample_en(sample_en),

        .ADC_en_n(ADC_en_n),
        .ADC_clk(ADC_clk),
        .ADC_Dout(ADC_Dout)
    );

    //instantiate Filter
    rollingAverageFilter filter(
        .clk(clk),
        .rst_n(rst_n),

        .filter_Din(ADC_Dout),

        .filter_Dout(filter_Dout),
        .filter_ready(rd_en),
        .data_valid(data_valid)
    );

    //instantiate DAC controller
    DAC7311_Controller dac_ctrl (
        .clk(clk),
        .rst_n(rst_n),

        .DAC_Din(filter_Dout),
        .data_valid(data_valid),

        .DAC_sync_n(DAC_sync_n),
        .DAC_Dout(DAC_Dout),
        .DAC_clk(DAC_clk)
    );

endmodule