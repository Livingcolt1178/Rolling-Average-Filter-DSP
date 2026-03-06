`timescale 1ns / 1ps
/*
    * File: DAC7311_Controller.sv
    * Project: Rolling Average Filter DSP
    * Author: Nicholas Bramhall
    * date of Release : 4/15/2026
    * Description: This module is the controller for the DAC7311, it will take in the data from the DSP and output it to the DAC for conversion.
*/
module DAC (
    input logic clk,
    input logic rst_n,

    input logic [11:0] DAC_Din,     //The data coming in that has been processed
    input logic DAC_valid,          //signal to let the DAC know that the data coming in is valid and can be latched for sending out.
    
    output logic DAC_sync_n,         //works as an enable signal in that when low, dac is busy, when high, idling.
    output logic DAC_dout,              //Data out from the DAC
    output logic DAC_clk,            //Clock signal for the DAC
    output logic DAC_ready          //probe to let the filter know that the DAC is done sending out data and is now ready for more data.
    );

    // --------------------------------------------------------
    // FSM
    // ---------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        SEND
    } state_t;

    state_t state, next;
    always_comb @(posedge clk or negedge rst_n) begin
        case (state) 
            IDLE:       next = DAC_valid ? LOAD : IDLE; //stay in idle until the DAC has valid data to send, then move to load state to latch the data.
            LOAD:       next = SEND; //after loading the data, move to send state
            SEND:       next = IDLE; //after sending the data, go back to idle and wait for the next data to be loaded.
            default:    next = IDLE; //default case to avoid latches, should never be hit.
        endcase
    end

    // --------------------------------------------------------
    // Data handling
    // --------------------------------------------------------
    logic [3:0] raddr;                                     //read address for the frame being sent to the DAC, it starts at 0 and counts up to 15 as the bits are sent out. 
    logic [15:0] frame;                                     //the frame that will be sent to the DAC, 2 control bits, 12 data bits, 2 don't care bits.

    //---------------------------------------------------------
    // Combinational logic for the FSM and data handling
    // ---------------------------------------------------------
    assign DAC_clk      = (state == SEND) ? clk : 1'b0;     //DAC clock is the same as the system clock when in send state, otherwise it is low.
    assign DAC_sync_n   = (state == IDLE) ? 1'b1 : 1'b0;    //DAC is busy when in send state, otherwise it is idling.
    assign DAC_ready    = state == IDLE;                    //DAC is ready for new data when in idle state.
    assign DAC_dout     = frame[15 - raddr];                //DAC data out is the current bit of the frame being sent, it starts with the MSB and shifts down to the LSB.

    //---------------------------------------------------------
    // Sequential logic for the FSM and data handling
    // ---------------------------------------------------------
    always_ff @( posedge clk or negedge rst_n ) begin
        if(!rst_n) begin
            state <= IDLE;
            raddr <= 4'd0;
            frame <= 16'h0000;
        end else begin
            case (state)
                IDLE: begin
                    state <= next;
                end
                LOAD: begin
                    frame <= {2'b00, DAC_Din, 2'b00}; //latch the frame with the control bits, data bits, and don't care bits when in load state
                    state <= next;
                end
                SEND: begin
                    if(raddr == 4'd15) begin
                        raddr <= 4'd0; //reset the read address after sending the entire frame
                        state <= next;
                    end else begin
                        raddr <= raddr + 1; //increment the read address to shift through the frame being sent to the DAC.
                    end
                end
            endcase
        end
    end

endmodule