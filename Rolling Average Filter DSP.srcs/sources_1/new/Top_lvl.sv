module top_lvl (
    input logic clk,
    input logic rst,
);

//data wires
logic ADC_Dout;
logic DSP_Din;

logic DSP_Dout; 
logic DAC_Din; 

//enable wires
logic ADC_en_n;
logic DAC_sync_n;
logic DSP_ready;

Controller u_ctrl (
    .clk_i      (clk),
    .rst_i      (rst),
    .ADC_Dout   (ADC_Dout),     //data from ADC
    .DSP_Dout   (DSP_Dout),     //data from DSP
    .DSP_ready  (DSP_ready),    //lets the ADC know its ready for data
    
    .ADC_en_n   (ADC_en_n),     //turns on the ADC
    .DSP_Din    (DSP_Din),      //Data being sent to the DSP
    .DAC_Din    (DAC_Din),      //Data being sent to the DAC
    .DAC_sync_n (DAC_sync_n)    //busy when low, idling when High.
);

ADC u_ADC(
    .clk_i      (clk),
    .rst_i      (rst),
    .ADC_Din    (),
    .ADC_en_n   (ADC_en_n),

    .ADC_Dout   (ADC_Dout)
);

DSP u_DSP(
    .clk_i      (clk),
    .rst_i      (rst),
    .DSP_Din    (DSP_Din),

    .DSP_Dout   (DSP_Dout),
    .DSP_ready  (DSP_ready)
);

DAC u_DAC(
    .clk_i      (clk),
    .rst_i      (rst),
    .DAC_Din    (DAC_Din),
    .DAC_sync_n (DAC_sync_n), //busy when low, idling when High.
    
    .dout       () 
);
endmodule