module Top_lvl_tb;
    //input signals
    logic clk;
    logic rst_n;
    logic [7:0] ADC_Din;



    logic ADC_clk;
    logic ADC_en_n;

    logic DAC_sync_n;
    logic DAC_Dout;
    logic DAC_clk;

    //instantiation
    top_lvl dut (
        .clk(clk),
        .rst_n(rst_n),

        .ADC_Din(ADC_Din),
        .ADC_clk(ADC_clk),
        .ADC_en_n(ADC_en_n),

        .DAC_sync_n(DAC_sync_n),
        .DAC_Dout(DAC_Dout),
        .DAC_clk(DAC_clk)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    task check_output(input string test_name, input logic [15:0] got, input logic [15:0] expected);
        if (got !== expected) begin
            $error("Test failed at time %t in test %s: Expected %h, Got %h", $time, test_name, expected, got);
        end else begin
            $display("Test passed at time %t in test %s: Expected %h, Got %h", $time, test_name, expected, got);
        end
    endtask

    task automatic DAC_output_check(output logic [11:0] DAC_output);
    logic [15:0] frame;
        @(negedge DAC_sync_n);
        for(int i =0; i < 16; i++) begin
            @(posedge clk);
            frame[15 - i] = DAC_Dout;
        end
        DAC_output = frame[13:2];
    endtask

    function automatic logic [11:0] expected_dout(input logic [7:0] val);
        logic [9:0] sum;
        logic [7:0] avg;
        sum = val + val + val + val;
        avg = sum >> 2;
        return {avg, 4'b0};
    endfunction

    property ADC_Write_Check;
        @(posedge clk) disable iff (!rst_n)
        (ADC_en_n == 0 && dut.adc_ctrl.allow_write)
        |-> (dut.adc_ctrl.fifo[$past(dut.adc_ctrl.waddr)] == (ADC_Din));
    endproperty

    property ADC_Read_Check;
        @(posedge clk) disable iff (!rst_n)
        (dut.adc_ctrl.allow_read)
        |-> (dut.adc_ctrl.ADC_Dout == $past(dut.adc_ctrl.fifo[dut.adc_ctrl.raddr]));
    endproperty

    property filter_calculation_check;
        @(posedge clk) disable iff (!rst_n)
        (dut.adc_ctrl.allow_read) |-> (dut.filter.filter_Dout == ((dut.filter.samples[0] + dut.filter.samples[1] + dut.filter.samples[2] + dut.filter.samples[3]) >> 2) << 4);
    endproperty

    property DAC_data_reg_check;
        @(posedge clk) disable iff (!rst_n)
        (dut.dac_ctrl.data_valid) |-> (dut.dac_ctrl.data_reg == {1'b0, dut.filter.filter_Dout, 2'b11});
    endproperty

    property DAC_sync_check;
        @(posedge clk) disable iff (!rst_n)
        (dut.dac_ctrl.data_valid && dut.dac_ctrl.DAC_ready)
        |-> ##1 (DAC_sync_n == 0);
    endproperty

    property DAC_start_bit_check;
        @(posedge clk) disable iff (!rst_n)
        (dut.dac_ctrl.data_valid && dut.dac_ctrl.DAC_ready)
        |-> ##1 (DAC_Dout == 0);
    endproperty

    property DAC_shift_reg_check;
        @(posedge clk) disable iff (!rst_n)
        (!dut.dac_ctrl.DAC_ready)
        |-> (dut.dac_ctrl.data_reg == $past(dut.dac_ctrl.data_reg) << 1);
    endproperty

    assert property (ADC_Write_Check)
        else $error("[%t] ADC Write to FIFO failed!", $time);

    assert property (ADC_Read_Check)
        else $error("[%t] ADC Read from FIFO failed!", $time);

    assert property (filter_calculation_check)
        else $error("[%t] Filter calculation is incorrect!", $time); //passes 100%

    assert property (DAC_data_reg_check)
        else $error("[%t] DAC data register is incorrect!", $time);

    assert property (DAC_sync_check)
        else $error("[%t] DAC SYNC signal is not correct!", $time); //so this is sayings its wrong but according to waveform and code its looks right, not sure what to do here.

    assert property (DAC_start_bit_check)
        else $error("[%t] DAC start bit is incorrect!", $time);    //same as sync check

    assert property (DAC_shift_reg_check)
        else $error("[%t] DAC shift register behavior is incorrect!", $time);

    logic [11:0] result;
    initial begin

        rst_n = 0;
        ADC_Din = 8'h00;
        #10;
        //=========================================================
        // Test 1: Reset Functionality
        //=========================================================
        check_output("Test 1 - Reset Check", ADC_en_n, 0);
        check_output("Test 1 - Reset Check", DAC_sync_n, 1);
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        assert (DAC_clk == clk) else $error("DAC clock is not connected to the system clock!");
        $display("Fifo_Full: %b", dut.adc_ctrl.fifo_full);
        //=========================================================
        // Test 2: constant 0xFF
        //=========================================================
        ADC_Din = 8'hFF;
        repeat(80) @(posedge clk);
        @(posedge DAC_sync_n);
        DAC_output_check(result);
        check_output("Test 2: constant 0xFF", result, expected_dout(8'hFF));

        //=========================================================
        // Test 3: constant 0x00
        //=========================================================
        ADC_Din = 8'h00;
        repeat(80) @(posedge clk);
        DAC_output_check(result);
        check_output("Test 3: constant 0x00", result, expected_dout(8'h00));

        //=========================================================
        // Test 4: Assertion Based Testing
        //=========================================================
        ADC_Din = 8'h0F;
        @(posedge clk);
        ADC_Din = 8'hF0;
        @(posedge clk);
        ADC_Din = 8'hAA;
        @(posedge clk);
        ADC_Din = 8'h55;
        @(posedge clk);
        ADC_Din = 8'h33;
        @(posedge clk);
        ADC_Din = 8'hCC;
        @(posedge clk);
        ADC_Din = 8'h78;
        @(posedge clk);
        ADC_Din = 8'h87;
        repeat(80) @(posedge clk);    
       
            $finish;
        end
endmodule