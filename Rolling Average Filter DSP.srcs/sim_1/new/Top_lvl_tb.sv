`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:     Nicholas Bramhall
// Module Name:  Top_lvl_tb
// Project Name: Rolling Average Filter DSP
// Target:       Spartan-7 XC7S15 (Spartan-Edge-Accelerator)
// Description:  Assertion-based top-level testbench for the ADC->DSP->DAC
//               pipeline. Verifies reset behavior, constant input responses,
//               midscale linearity, and mixed-input assertion coverage across
//               the ADC FIFO, rolling average filter, and DAC SPI controller.
//
// Tests:
//   1. Reset — verifies ADC_en_n, DAC_sync_n, and DAC_clk after reset
//   2. Constant 0xFF — all N taps filled, output should be 0xFF0
//   3. Constant 0x00 — all N taps filled, output should be 0x000
//   4. Midscale 0x80 — output should be 0x800
//   5. Mixed input — assertion coverage across varied ADC values
//
// Notes:
//   - Set N and LOG2_N to match rollingAverageFilter.sv tap count
//   - Add SIMULATION define in Vivado sim settings to bypass clk_wiz
//////////////////////////////////////////////////////////////////////////////////
module Top_lvl_tb;

    //================================================================
    // Parameters — match these to the DUT
    //================================================================
    localparam N        = 64;
    localparam LOG2_N   = $clog2(N);
    localparam CLK_HALF = 5; // 100MHz = 10ns period

    //================================================================
    // Signals
    //================================================================
    logic        clk;
    logic        rst_n;
    logic [7:0]  ADC_Din;
    logic        ADC_clk;
    logic        ADC_en_n;
    logic        DAC_sync_n;
    logic        DAC_Dout;
    logic        DAC_clk;

    //================================================================
    // DUT Instantiation
    //================================================================
    top_lvl dut (
        .sys_clk    (clk),
        .rst_n      (rst_n),
        .ADC_Din    (ADC_Din),
        .ADC_clk    (ADC_clk),
        .ADC_en_n   (ADC_en_n),
        .DAC_sync_n (DAC_sync_n),
        .DAC_Dout   (DAC_Dout),
        .DAC_clk    (DAC_clk)
    );

    //================================================================
    // Clock Generation — 100MHz
    //================================================================
    initial clk = 0;
    always #CLK_HALF clk = ~clk;

    //================================================================
    // Tasks and Functions
    //================================================================

    // Apply and release reset cleanly
    task apply_reset();
        rst_n = 0;
        repeat(20) @(posedge clk);
        @(negedge clk); // release on negedge for clean setup time
        rst_n = 1;
        repeat(5) @(posedge clk);
    endtask

    // Check output value with pass/fail message
    task check_output(
        input string       test_name,
        input logic [15:0] got,
        input logic [15:0] expected
    );
        if (got !== expected)
            $error("[%0t] FAIL %s: Expected 0x%h, Got 0x%h",
                   $time, test_name, expected, got);
        else
            $display("[%0t] PASS %s: 0x%h", $time, test_name, got);
    endtask

    // Capture one DAC SPI frame and return the 12-bit data field
    task automatic DAC_output_check(output logic [11:0] DAC_output);
        logic [15:0] frame;
        @(negedge DAC_sync_n);
        #1; // settle — first bit already driven combinatorially
        for (int i = 0; i < 16; i++) begin
            @(posedge clk);
            #1; // settle after clock edge
            frame[15 - i] = DAC_Dout;
        end
        DAC_output = frame[13:2]; // bits [13:2] = 12-bit data field
    endtask

    // Expected DAC output for a constant ADC input
    // Accounts for N-tap average and 12-bit scaling
    function automatic logic [11:0] expected_dout(input logic [7:0] val);
        logic [14:0] sum;
        logic [7:0]  avg;
        sum = val * N;           // all N taps hold same value
        avg = sum >> LOG2_N;     // divide by N
        return {avg, 4'b0};      // scale to 12-bit
    endfunction

    //================================================================
    // Assertions
    //================================================================

    // ADC FIFO write captures correct data
    property ADC_Write_Check;
        @(posedge dut.clk) disable iff (!dut.internal_rst_n)
        (ADC_en_n == 0 && dut.adc_ctrl.allow_write)
        |-> (dut.adc_ctrl.fifo[(dut.adc_ctrl.waddr)] == ADC_Din);
    endproperty

    // ADC FIFO read outputs correct data
    property ADC_Read_Check;
        @(posedge dut.clk) disable iff (!dut.internal_rst_n)
        (dut.adc_ctrl.allow_read)
        |-> (dut.adc_ctrl.ADC_Dout ==
            (dut.adc_ctrl.fifo[dut.adc_ctrl.raddr]));
    endproperty

    // Filter output matches rolling average math using N taps
    property filter_calculation_check;
        logic [14:0] expected_sum;
        @(posedge dut.clk) disable iff (!dut.internal_rst_n)
        (dut.adc_ctrl.allow_read)
        |-> (dut.filter.filter_Dout ==
             (dut.filter.sum >> LOG2_N) << 4);
    endproperty

    // DAC data register loaded correctly
    property DAC_data_reg_check;
        @(posedge dut.clk) disable iff (!dut.internal_rst_n)
        (dut.dac_ctrl.DAC_start)
        |-> ##1 (dut.dac_ctrl.data_reg ==
                 {1'b0, $past(dut.filter.filter_Dout), 2'b11});
    endproperty

    // SYNC goes low one cycle after DAC starts
    property DAC_sync_check;
        @(posedge dut.clk) disable iff (!dut.internal_rst_n)
        (dut.dac_ctrl.DAC_start)
        |-> ##1 (DAC_sync_n == 0);
    endproperty

    // First transmitted bit is 0 (control bit)
    property DAC_start_bit_check;
        @(posedge dut.clk) disable iff (!dut.internal_rst_n)
        (dut.dac_ctrl.DAC_start)
        |-> ##1 (DAC_Dout == 0);
    endproperty

    // Shift register advances every cycle while transmitting
    property DAC_shift_reg_check;
        @(posedge dut.clk) disable iff (!dut.internal_rst_n)
        (!dut.dac_ctrl.DAC_ready)
        |-> (dut.dac_ctrl.data_reg ==
             $past(dut.dac_ctrl.data_reg) << 1);
    endproperty

    assert property (ADC_Write_Check)
        else $error("[%0t] ADC Write to FIFO failed!", $time);

    assert property (ADC_Read_Check)
        else $error("[%0t] ADC Read from FIFO failed!", $time);

    assert property (filter_calculation_check)
        else $error("[%0t] Filter calculation incorrect!", $time);

    assert property (DAC_data_reg_check)
        else $error("[%0t] DAC data register incorrect!", $time);

    assert property (DAC_sync_check)
        else $error("[%0t] DAC SYNC incorrect!", $time);

    assert property (DAC_start_bit_check)
        else $error("[%0t] DAC start bit incorrect!", $time);       //working

    assert property (DAC_shift_reg_check)
        else $error("[%0t] DAC shift register incorrect!", $time);

    //================================================================
    // Stimulus
    //================================================================
    logic [11:0] result;

    initial begin
        ADC_Din = 8'h00;

        //============================================================
        // Test 1: Reset Functionality
        // Verify all outputs are in correct reset state
        //============================================================
        apply_reset();
        $display("\n--- Test 1: Reset Check ---");
        check_output("ADC_en_n after reset",  {15'b0, ADC_en_n},  16'h0000);
        check_output("DAC_sync_n after reset", {15'b0, DAC_sync_n}, 16'h0001);
        assert (DAC_clk == clk)
            else $error("DAC_clk not connected to system clock!");
        $display("FIFO count after reset: %0d", dut.adc_ctrl.count);

        //============================================================
        // Test 2: Constant 0xFF input
        // All N taps fill with 0xFF — output should be 0xFF0
        // Wait long enough for all 64 taps to fill
        //============================================================
        $display("\n--- Test 2: Constant 0xFF ---");
        apply_reset();
        ADC_Din = 8'hFF;
        // N taps × 16 cycles per sample + margin
        repeat(N * 16 + 80) @(posedge clk);
        DAC_output_check(result);
        check_output("Constant 0xFF", result, expected_dout(8'hFF));

        //============================================================
        // Test 3: Constant 0x00 input
        // All taps fill with 0x00 — output should be 0x000
        //============================================================
        $display("\n--- Test 3: Constant 0x00 ---");
        apply_reset();
        ADC_Din = 8'h00;
        repeat(N * 16 + 80) @(posedge clk);
        DAC_output_check(result);
        check_output("Constant 0x00", result, expected_dout(8'h00));

        //============================================================
        // Test 4: Constant 0x80 midscale
        // Output should be 0x800 (midscale DAC)
        //============================================================
        $display("\n--- Test 4: Midscale 0x80 ---");
        apply_reset();
        ADC_Din = 8'h80;
        repeat(N * 16 + 80) @(posedge clk);
        DAC_output_check(result);
        check_output("Midscale 0x80", result, expected_dout(8'h80));

        //============================================================
        // Test 5: Assertion-based mixed input
        // Feed varied values spaced 16 cycles apart so each
        // value is actually captured by the ADC strobe
        //============================================================
        $display("\n--- Test 5: Mixed Input Assertion Check ---");
        apply_reset();

        begin
            logic [7:0] test_vals [7:0];
            test_vals[0] = 8'h0F;
            test_vals[1] = 8'hF0;
            test_vals[2] = 8'hAA;
            test_vals[3] = 8'h55;
            test_vals[4] = 8'h33;
            test_vals[5] = 8'hCC;
            test_vals[6] = 8'h78;
            test_vals[7] = 8'h87;

            for (int i = 0; i < 8; i++) begin
                ADC_Din = test_vals[i];
                repeat(16) @(posedge clk);
            end
        end

        repeat(N * 16 + 80) @(posedge clk);
        $display("\n--- All tests complete ---");
        $finish;
    end

endmodule