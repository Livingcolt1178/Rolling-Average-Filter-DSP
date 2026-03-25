`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:     Nicholas Bramhall
// Module Name:  DAC7311_Controller_tb
// Project Name: Rolling Average Filter DSP
// Target:       ADC1173
// Description:  Testbench for the DAC7311 Controller. Tests output behavior, 
//               accepting data behavior and reset behavior.
//////////////////////////////////////////////////////////////////////////////////


module DAC7311_Controller_tb;
    //input signals
    logic clk;
    logic rst_n;
    logic [11:0] DAC_Din;
    logic data_valid;
    
    // output signals
    logic DAC_sync_n;
    logic DAC_dout;
    logic DAC_clk;
    logic DAC_ready;

    //internal signals
    logic [14:0] data_reg;
    logic [3:0] bit_cnt;
    
    //instantiation
    DAC7311_Controller dut (
    .clk(clk),
    .rst_n(rst_n),

    .DAC_Din(DAC_Din),
    .data_valid(data_valid),
    
    .DAC_sync_n(DAC_sync_n),
    .DAC_dout(DAC_dout),
    .DAC_clk(DAC_clk),
    .DAC_ready(DAC_ready)
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

    initial begin
        rst_n = 0;
        DAC_Din = 1;
        data_valid = 0;
        #10;
        rst_n = 1;
        @(posedge clk);

        //=========================================================
        // Test 1: Reset Functionality
        //=========================================================
        check_output("Test 1 - Reset Check", DAC_sync_n, 1);
        check_output("Test 1 - Reset Check", DAC_dout, 0);
        check_output("Test 1 - Reset Check", DAC_ready, 1);

        //=========================================================
        // Test 2: Check data latching and output behavior
        //=========================================================
        DAC_Din = 12'hABC; //Test data  = 1 0 1 0 | 1 0 1 1 | 1 1 0 0  
        data_valid = 1; //Indicate data is valid
        @(posedge clk);
        data_valid = 0;
        check_output("Test 2 - Data Latch Check", DAC_ready, 0); //Should not be ready while sending data
        check_output("Test 2 - Sync Check", DAC_sync_n, 0); //Should be busy while sending data
        // Check the first few bits being sent out
        check_output("Test 2 - bit 15 (PD1)", DAC_dout, 0);
        @(posedge clk);
        check_output("Test 2 - bit 14 (PD0)", DAC_dout, 0);
        @(posedge clk);
        check_output("Test 2 - bit 13 (D11)", DAC_dout, 1);
        @(posedge clk);
        check_output("Test 2 - bit 12 (D10)", DAC_dout, 0);
        @(posedge clk);
        check_output("Test 2 - bit 11 (D9)",  DAC_dout, 1);
        @(posedge clk);
        check_output("Test 2 - bit 10 (D8)",  DAC_dout, 0);
        @(posedge clk);
        check_output("Test 2 - bit 9  (D7)",  DAC_dout, 1);
        @(posedge clk);
        check_output("Test 2 - bit 8  (D6)",  DAC_dout, 0);
        @(posedge clk);
        check_output("Test 2 - bit 7  (D5)",  DAC_dout, 1);
        @(posedge clk);
        check_output("Test 2 - bit 6  (D4)",  DAC_dout, 1);
        @(posedge clk);
        check_output("Test 2 - bit 5  (D3)",  DAC_dout, 1);
        @(posedge clk);
        check_output("Test 2 - bit 4  (D2)",  DAC_dout, 1);
        @(posedge clk);
        check_output("Test 2 - bit 3  (D1)",  DAC_dout, 0);
        @(posedge clk);
        check_output("Test 2 - bit 2  (D0)",  DAC_dout, 0);
        @(posedge clk);
        check_output("Test 2 - bit 1  (dc)",  DAC_dout, 1);
        @(posedge clk);
        check_output("Test 2 - bit 0  (dc)",  DAC_dout, 1);
        @(posedge clk);
        //=========================================================
        // Test 3: Check that DAC_ready goes high after all bits are sent
        //=========================================================
        check_output("Test 3 - DAC Ready Check", DAC_ready, 1); //Should be ready after all bits are sent
        check_output("Test 3 - Sync Check", DAC_sync_n, 1); //Should be idle after all bits are sent

        //=========================================================
        // Test 4: Check that new data can be latched after previous data is sent
        //=========================================================
        DAC_Din = 12'h123; //New test data = 0 0 0 1 0 0 1 0 0 0 1 1
        data_valid = 1; //Indicate new data is valid
        @(posedge clk);
        data_valid = 0;
        check_output("Test 4 - Data Latch Check", DAC_ready, 0); //Should not be ready while sending data
        check_output("Test 4 - Sync Check", DAC_sync_n, 0); //Should be busy while sending data
        // Check the first few bits being sent out for the new data
        check_output("Test 4 - bit 15 (PD1)", DAC_dout, 0); //First control bit
        @(posedge clk);
        check_output("Test 4 - bit 14 (PD0)", DAC_dout, 0);
        @(posedge clk);
        check_output("Test 4 - bit 13 (D11)", DAC_dout, 0); //First data bit (MSB of DAC_Din)
        @(posedge clk);
        check_output("Test 4 - bit 12 (D10)", DAC_dout, 0); //Second data bit
        @(posedge clk);
        check_output("Test 4 - bit 11 (D9)", DAC_dout, 0); //Third data bit
        @(posedge clk);
        check_output("Test 4 - bit 10 (D8)", DAC_dout, 1); //Fourth data bit
        @(posedge clk);
        check_output("Test 4 - bit 9  (D7)", DAC_dout, 0); //Fifth data bit
        @(posedge clk);
        check_output("Test 4 - bit 8  (D6)", DAC_dout, 0);
        @(posedge clk);
        check_output("Test 4 - bit 7  (D5)", DAC_dout, 1);
        @(posedge clk);
        check_output("Test 4 - bit 6  (D4)", DAC_dout, 0);
        @(posedge clk);
        check_output("Test 4 - bit 5  (D3)", DAC_dout, 0);
        @(posedge clk);
        check_output("Test 4 - bit 4  (D2)", DAC_dout, 0); 
        @(posedge clk);
        check_output("Test 4 - bit 3  (D1)", DAC_dout, 1); 
        @(posedge clk);
        check_output("Test 4 - bit 2  (D0)", DAC_dout, 1); 
        @(posedge clk);
        check_output("Test 4 - bit 1  (dc)", DAC_dout, 1); //dc bit 1
        @(posedge clk);
        check_output("Test 4 - bit 0  (dc)", DAC_dout, 1); //dc bit 2
        @(posedge clk);
        check_output("Test 4 - DAC Ready Check", DAC_ready, 1); //Should be ready after all bits are sent
        check_output("Test 4 - Sync Check", DAC_sync_n, 1); //Should be idle after all bits are sent

         //=========================================================
        // Test 5: Check that DAC does not latch new data while busy
        //=========================================================
        DAC_Din = 12'hFFF;
        data_valid = 1;
        @(posedge clk);
        data_valid = 0;
        check_output("Test 5 - bit 15  (PD1)",  DAC_dout, 0);
        @(posedge clk);
        check_output("Test 5 - bit 14  (PD0)",  DAC_dout, 0);
        @(posedge clk);
        check_output("Test 5 - bit 13  (D11)",  DAC_dout, 1);
        @(posedge clk);
        // inject new data mid-transmission — should be ignored
        DAC_Din   = 12'hACB;
        data_valid = 1;
        @(posedge clk);
        data_valid = 0;
        check_output("Test 5 - bit 12 (D10)",  DAC_dout, 1);
        @(posedge clk);
        check_output("Test 5 - bit 11 (D9)",   DAC_dout, 1);
        @(posedge clk);
        check_output("Test 5 - bit 10 (D8)",   DAC_dout, 1);
        @(posedge clk);
        check_output("Test 5 - bit 9  (D7)",   DAC_dout, 1);
        @(posedge clk);
        check_output("Test 5 - bit 8  (D6)",   DAC_dout, 1);
        @(posedge clk);
        check_output("Test 5 - bit 7  (D5)",   DAC_dout, 1);
        @(posedge clk);
        check_output("Test 5 - bit 6  (D4)",   DAC_dout, 1);
        @(posedge clk);
        check_output("Test 5 - bit 5  (D3)",   DAC_dout, 1);
        @(posedge clk);
        check_output("Test 5 - bit 4  (D2)",   DAC_dout, 1);
        @(posedge clk);
        check_output("Test 5 - bit 3  (D1)",   DAC_dout, 1);
        @(posedge clk);
        check_output("Test 5 - bit 2  (D0)",   DAC_dout, 1);
        @(posedge clk);
        check_output("Test 5 - bit 1  (dc)",   DAC_dout, 1);
        @(posedge clk);
        check_output("Test 5 - bit 0  (dc)",   DAC_dout, 1);
        @(posedge clk);
        check_output("Test 5 - Post DAC_ready", DAC_ready,  1);
        check_output("Test 5 - Post sync idle", DAC_sync_n, 1);

        //=========================================================
        // Test 6: Check doesn't accept data if data is not valid
        //=========================================================
        DAC_Din = 12'h555; //New test data
        data_valid = 0; //Indicate data is not valid
        @(posedge clk);
        check_output("Test 6 - Valid Check", DAC_ready, 1); //Should still be ready since data is not valid
        check_output("Test 6 - Valid Check", DAC_sync_n, 1); //Should still be idle since data is not valid
        @(posedge clk);

        $finish;
    end
endmodule
