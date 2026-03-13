`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:     Nicholas Bramhall
// Module Name:  ADC1173_tb
// Project Name: Rolling Average Filter DSP
// Target:       ADC1173
// Description:  Testbench for the ADC1173 controller. Tests FIFO write, read,
//               overflow protection, ordering, and reset behaviour.
//////////////////////////////////////////////////////////////////////////////////


module ADC1173_tb;

//Signals
    logic clk;
    logic rst_n;
    logic [7:0] ADC_Din;
    logic ADC_en_n;
    logic rd_en;
    logic sample_en;

    logic ADC_clk;
    logic [7:0] ADC_Dout;
    logic fifo_empty;
    logic fifo_full;

    logic [7:0] data; //wire to capture the output data from the FIFO for checking
    int i; //integer for loop iteration
    
    // Instantiate the ADC1173 controller
    ADC dut (
        .clk(clk),
        .rst_n(rst_n),
        .ADC_Din(ADC_Din),
        .rd_en(rd_en),
        .sample_en(sample_en),
        .ADC_en_n(ADC_en_n),
        .ADC_clk(ADC_clk),
        .ADC_Dout(ADC_Dout),
        .fifo_empty(fifo_empty),
        .fifo_full(fifo_full)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    task check_output(input string test_name, input logic [7:0] got, input logic [7:0] expected);
        if (got !== expected) begin
            $error("Test failed at time %t in test %s: Expected %h, Got %h", $time, test_name, expected, got);
        end else begin
            $display("Test passed at time %t in test %s: Expected %h, Got %h", $time, test_name, expected, got);
        end
    endtask

    task wait_for_strobe(input int count);
        repeat(count) begin
            @(posedge clk);
            while (dut.strob_counter !== 4'd15) begin
                @(posedge clk);
            end
        end
        @(posedge clk);
    endtask

    task read_from_fifo();
        rd_en = 1;
        @(posedge clk);
        rd_en = 0;
        data = ADC_Dout; // Capture the output data from the FIFO
        @(posedge clk);
    endtask

    initial begin
        // Initialize signals
        rst_n = 0;
        ADC_Din = 8'h00;
        rd_en = 0;
        sample_en = 0;
        repeat (4) @(posedge clk); // Wait for a few clock cycles
        rst_n = 1; // Release reset
        @(posedge clk);

        //=========================================================
        // Test 1: Reset Functionality
        //=========================================================
            $display("Starting Test 1: Reset Functionality");

            //checks
            check_output("Reset Test - FIFO Empty", fifo_empty, 1);
            check_output("Reset Test - FIFO Full", fifo_full, 0);
            check_output("Reset Test - ADC Enable", ADC_en_n, 0);

        //==========================================================
        // Test 2: Single Write
        //==========================================================
            $display("\n--- TEST 2: Single Write ---");

            //test
            ADC_Din = 8'hA5; // Write a sample value to the ADC input
            sample_en = 1; // Enable sampling
            wait_for_strobe(1); // Wait for the sample strobe to write the data
            sample_en = 0; // Disable sampling to prevent further writes

            //checks
            check_output("Single Write Test - FIFO Empty", fifo_empty, 0);
            check_output("Single Write Test - FIFO Full", fifo_full, 0);
            check_output("Single Write Test - ADC Enable", ADC_en_n, 0); 
            @(posedge clk);

        //==========================================================
        // Test 3: Single Read
        //==========================================================
            $display("\n--- TEST 3: Single Read ---");

            //test
            read_from_fifo(); // Read the sample value from the FIFO

            //checks
            check_output("Single Read Test - Data Read", data, 8'hA5); // Check if the data read from the FIFO is correct
            check_output("Single Read Test - FIFO Empty", fifo_empty, 1);
            check_output("Single Read Test - FIFO Full", fifo_full, 0);
            check_output("Single Read Test - ADC Enable", ADC_en_n, 0); 
            @(posedge clk);

        //==========================================================
        // Test 4: Read from empty FIFO
        //==========================================================
            $display("\n--- TEST 4: Read from Empty FIFO ---");

            //test
            read_from_fifo(); // Attempt to read from the empty FIFO

            //checks
            check_output("Read from Empty FIFO Test - Data Read", data, 8'h00); // Check if the data read is 0x00 
            check_output("Read from Empty FIFO Test - FIFO Empty", fifo_empty, 1);
            check_output("Read from Empty FIFO Test - FIFO Full", fifo_full, 0);
            check_output("Read from Empty FIFO Test - ADC Enable", ADC_en_n, 0); 
            @(posedge clk);

        //==========================================================
        // Test 5: Fill FIFO
        //==========================================================
            $display("\n--- TEST 5: Fill FIFO ---");

            //test
            sample_en = 1; // Enable sampling to allow writes to the FIFO
            for (int i = 0; i < 8; i++) begin
                ADC_Din = i; // Write values 0 to 7 into the FIFO
                wait_for_strobe(1); // Wait for the sample strobe to write the data
            end
            sample_en = 0; // Disable sampling to prevent further writes

            //checks
            check_output("Fill FIFO Test - FIFO Full", fifo_full, 1);
            check_output("Fill FIFO Test - ADC Enable", ADC_en_n, 1); // ADC should be disabled when FIFO is full
            @(posedge clk);

        //==========================================================
        // Test 6: Write to full FIFO
        //==========================================================
            $display("\n--- TEST 6: Verify contents unchanged after overflow ---");

            //test
            sample_en = 1; // Enable sampling to allow writes to the FIFO
            ADC_Din = 8'hFF; // Attempt to write a new value to the full FIFO
            wait_for_strobe(1); // Wait for the sample strobe to attempt the write
            sample_en = 0; // Ensure sampling is disabled to prevent further writes

            //checks
            check_output("Write to Full FIFO Test - FIFO Full", fifo_full, 1);
            check_output("Write to Full FIFO Test - ADC Enable", ADC_en_n, 1); 
            @(posedge clk);


        //==========================================================
        // Test 7: Read all from full FIFO
        //==========================================================
            $display("\n--- TEST 7: Read all from Full FIFO (checks order too) ---");

            //test
            for (i = 0; i < 8; i++) begin
                read_from_fifo(); // Read all values from the FIFO
                check_output($sformatf("Read from Full FIFO Test - Data Read %0d", i), data, i); // Check if the data read from the FIFO is correct
            end

            //checks
            check_output("Read from Full FIFO Test - FIFO Empty", fifo_empty, 1);
            check_output("Read from Full FIFO Test - FIFO Full", fifo_full, 0);
            check_output("Read from Full FIFO Test - ADC Enable", ADC_en_n, 0); 
            @(posedge clk);
        
        //==========================================================
        // Test Bench DONE!
        //==========================================================
        $display("\n--- All tests completed ---");
        $finish; // Stop the simulation
    end
endmodule
