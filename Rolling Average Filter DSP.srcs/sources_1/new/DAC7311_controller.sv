`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:     Nicholas Bramhall
// Module Name:  DAC7311_Controller
// Project Name: Rolling Average Filter DSP
// Target:       DAC7311
// Description:  Controller for the DAC7311. Accepts 12-bit parallel data,
//               serializes it into a 16-bit SPI frame, and clocks it out
//               MSB-first with SYNC framing.
//////////////////////////////////////////////////////////////////////////////////

module DAC7311_Controller (
    input logic clk,
    input logic rst_n,

    input logic [11:0] DAC_Din,     //The data coming in that has been processed
    input logic data_valid,         //signal to let the DAC know that the data coming in is valid and can be latched for sending out.
    
    output logic DAC_sync_n,        //works as an enable signal in that when low, dac is busy, when high, idling.
    output logic DAC_dout,          //Data out from the DAC
    output logic DAC_clk           //Clock signal for the DAC
    );

    logic [14:0] data_reg;  //register to hold the data being sent out to the DAC
    logic [3:0] bit_cnt;
    logic DAC_ready;        //flag to indicate the DAC is ready for new data, only allows new data to be latched when the previous data has finished sending out.
    assign DAC_clk = clk;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            DAC_ready <= 1; //Ready for data when reset
            data_reg <= 0; //Clear data register on reset
            DAC_sync_n <= 1; //Idle when reset
            DAC_dout <= 0;
            bit_cnt <= 0; //Reset bit counter
        end else begin 
            if (data_valid & DAC_ready) begin        //if the data coming in is valid and the DAC is ready, latch the data and start sending it out
                DAC_ready <= 0;                     //Not ready while sending data
                data_reg <= {1'b0, DAC_Din, 2'b11};  //1 control bits + 12 data bits + 2 dc bits prep before sending the data out
                DAC_dout <= 1'b0;                    //first controll bit;
                DAC_sync_n <= 0;                    //Set sync low to indicate we are busy
                bit_cnt <= 1;                       //Reset bit counter
            end else if (!DAC_ready) begin          //If not ready, we are in the process of sending data out
                DAC_dout <= data_reg[14];           
                data_reg <= data_reg << 1; //Shift the data left for the next bit
                bit_cnt <= bit_cnt + 1;             //Increment bit counter
                if (bit_cnt == 4'd15) begin            //Once all bits have been sent, we are done
                    DAC_ready <= 1;                 //Ready for new data
                    DAC_sync_n <= 1;                //Set sync high to indicate we are idle
                end
            end else begin
                DAC_sync_n <= 1; //Idle when ready
            end
        end
    end


endmodule