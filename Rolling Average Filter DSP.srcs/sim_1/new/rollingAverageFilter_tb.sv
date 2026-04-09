`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:     Nicholas Bramhall
// Module Name:  rollingAverageFilter_tb
// Project Name: Rolling Average Filter DSP
// Target:       rollingAverageFilter
// Description:  Testbench for the 4-tap rolling average filter. Verifies reset
//               behavior, steady-state average output, and correct 12-bit scaling
//               of the 8-bit input via right-shift division.
//////////////////////////////////////////////////////////////////////////////////

module rollingAverageFilter_tb;
    //inputs
    logic clk;
    logic rst_n;
    logic [7:0] filter_Din;

    //outputs
    logic [11:0] filter_Dout;
    logic filter_ready;

    //internal signals
    logic [7:0] samples [3:0];
    logic [9:0] sum;
    logic [7:0] avg;

    rollingAverageFilter dut (
        .clk(clk),
        .rst_n(rst_n),
        .filter_Din(filter_Din),
        .filter_Dout(filter_Dout),
        .filter_ready(filter_ready)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    task check_output(input string test_name, input logic [12:0] got, input logic [12:0] expected);
        if (got !== expected) begin
            $error("Test failed at time %t in test %s: Expected %h, Got %h", $time, test_name, expected, got);
        end else begin
            $display("Test passed at time %t in test %s: Expected %h, Got %h", $time, test_name, expected, got);
        end
    endtask

    initial begin
        //initialize signals
        rst_n = 0;
        filter_Din = 0;
        #10; // Wait for 10 ns
        rst_n = 1; // Deassert reset
        @(posedge clk); 
    
        //=========================================================
        // Test 1: Reset Functionality
        //=========================================================
        check_output("Test 1 - Reset Check", dut.samples[0], 0);
        check_output("Test 1 - Reset Check", dut.samples[1], 0);
        check_output("Test 1 - Reset Check", dut.samples[2], 0);
        check_output("Test 1 - Reset Check", dut.samples[3], 0);
        check_output("Test 1 - Reset Check", dut.sum, 0);
        check_output("Test 1 - Reset Check", dut.avg, 0);
        check_output("Test 1 - Reset Check", filter_Dout, 0);
        rst_n = 1; // Deassert reset
        
        //=========================================================
        // Test 2: Check Sum and Average and output Calculation
        //=========================================================
        @(posedge clk);
        filter_Din = 8'h01; // Shift in the first value
        @(posedge clk); 
        filter_Din = 8'h02; // Shift in the second value
        @(posedge clk); 
        filter_Din = 8'h03; // Shift in the third value
        @(posedge clk); 
        filter_Din = 8'h04; // Shift in the fourth value
        #1;
        check_output("Test 2 - Sample Check", dut.samples[0], 8'h04); // New value should be in samples[0]
        check_output("Test 2 - Sample Check", dut.samples[1], 8'h03); // Old value should have shifted to samples[1]
        check_output("Test 2 - Sample Check", dut.samples[2], 8'h02); // Old value should have shifted to samples[2]
        check_output("Test 2 - Sample Check", dut.samples[3], 8'h01); // Old value should have shifted to samples[3]
        check_output("Test 2 - Sum Check", dut.sum, 10); //1 + 2 + 3 + 4 = 10
        check_output("Test 2 - Average Check", dut.avg, 2); //10 / 4 = 2.5, truncated to 2        
        @(posedge clk);
        #1;
        check_output("Test 2 - Output Check", filter_Dout, 32); 


        //=========================================================
        // Test 3: Check rolling behavior
        //=========================================================
        rst_n = 0;
        filter_Din = 0;
        #10; // Wait for 10 ns
        rst_n = 1; // Deassert reset
        
        @(posedge clk);
        filter_Din = 8'h01; // Shift in the first value
        @(posedge clk); 
        filter_Din = 8'h02; // Shift in the second value
        @(posedge clk); 
        filter_Din = 8'h03; // Shift in the third value
        @(posedge clk); 
        filter_Din = 8'h04; // Shift in the fourth value
        @(posedge clk);
        filter_Din = 8'h05; // Shift in a new value to check the rolling behavior
        #1;

        check_output("Test 3 - Rolling Check", dut.samples[0], 8'h05); // New value should be in samples[0]
        check_output("Test 3 - Rolling Check", dut.samples[1], 8'h04); // Oldest value should have shifted out
        check_output("Test 3 - Rolling Check", dut.samples[2], 8'h03); // Old value should have shifted to samples[2]
        check_output("Test 3 - Rolling Check", dut.samples[3], 8'h02); // Old value should have shifted to samples[3]

        //=========================================================
        // Test 4: Check new calculations after rolling
        //=========================================================
        check_output("Test 4 - New Sum Check", dut.sum, 14); //5 + 4 + 3 + 2 = 14
        check_output("Test 4 - New Average Check", dut.avg, 3); //14 / 4 = 3.5, truncated to 3
        @(posedge clk);
        #1;
        check_output("Test 4 - New Output Check", filter_Dout, 48);
        
        //=========================================================
        //  test 5 check multiple rolls
        //=========================================================
        rst_n = 0;
        filter_Din = 0;
        #10; // Wait for 10 ns
        rst_n = 1; // Deassert reset
        
        @(posedge clk);
        filter_Din = 8'h01; // Shift in the first value
        @(posedge clk); 
        filter_Din = 8'h02; // Shift in the second value
        @(posedge clk); 
        filter_Din = 8'h03; // Shift in the third value
        @(posedge clk); 
        filter_Din = 8'h04; // Shift in the fourth value
        @(posedge clk);
        filter_Din = 8'h05; // Shift in a new value to check the rolling behavior
        @(posedge clk);
        filter_Din = 8'h06; 
        @(posedge clk);
        filter_Din = 8'h07;
        @(posedge clk);
        filter_Din = 8'h08;
        #1;

        check_output("Test 5 - Multiple Rolls Check", dut.samples[0], 8'h08); // New value should be in samples[0]
        check_output("Test 5 - Multiple Rolls Check", dut.samples[1], 8'h07); // New value should be in samples[1]
        check_output("Test 5 - Multiple Rolls Check", dut.samples[2], 8'h06); // New value should be in samples[2]
        check_output("Test 5 - Multiple Rolls Check", dut.samples[3], 8'h05); // New value should be in samples[3]
        check_output("Test 5 - Multiple Rolls Sum Check", dut.sum, 26); //8 + 7 + 6 + 5 = 26
        check_output("Test 5 - Multiple Rolls Average Check", dut.avg, 6); //26 / 4 = 6.5, truncated to 6
        @(posedge clk);
        #1;
        check_output("Test 5 - Multiple Rolls Output Check", filter_Dout, 96);

        $display("All tests completed.");
        $finish;

    end
endmodule
