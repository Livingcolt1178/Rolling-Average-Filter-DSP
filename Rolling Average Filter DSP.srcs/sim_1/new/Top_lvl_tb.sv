module Top_lvl_tb;
    //input signals
    logic clk;
    logic rst_n;
    logic [7:0] ADC_Din;
    
    // output signals
    logic ADC_clk;
    logic ADC_en_n;
    logic [7:0] ADC_Dout;

    logic DAC_sync_n;
    logic DAC_dout;
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
        avg = sum  >> 2; 
        return avg << 4;
    endfunction

    logic [11:0] result;
    logic [7:0] tb_samples [0:3];
    logic [7:0] sine_lut [0:63];

    initial begin
        for (int i = 0; i < 64; i++) begin
            sine_lut[i] = 8'(128 + integer'(127.0 * $sin(2.0 * 3.14159265 * i / 64)));
        end
    end

    initial begin
        rst_n = 0;
        ADC_Din = 8'h00;
        #10;
        rst_n = 1;
        @(posedge clk);

        //=========================================================
        // Test 1: Reset Functionality
        //=========================================================
        check_output("Test 1 - Reset Check", ADC_en_n, 1);
        check_output("Test 1 - Reset Check", ADC_Dout, 8'h00);
        check_output("Test 1 - Reset Check", DAC_sync_n, 1);
        check_output("Test 1 - Reset Check", DAC_dout, 0);
        check_output("Test 1 - Reset Check", DAC_clk, 0);

        //=========================================================
        // Test 2: constant 0xFF
        //=========================================================
        ADC_Din = 8'hFF;
        repeat(20) @(posedge clk);
        capture_dac_frame(result);
        check("Test 2: constant 0xFF", result, expected_dout(8'hFF));


        //========================================================
        // Test 3: sinualsodal Testing
        //=======================================================
        // Shift register mirroring the filter's internal state

            // Feed one full sine cycle
            for (int i = 0; i < 64; i++) begin
                ADC_Din = sine_lut[i];
                
                // Update TB-side shift register (mirrors RTL)
                tb_samples[3] = tb_samples[2];
                tb_samples[2] = tb_samples[1];
                tb_samples[1] = tb_samples[0];
                tb_samples[0] = sine_lut[i];
                
                // Wait for strobe (every 16 cycles)
                repeat(16) @(posedge clk);

                // Capture and check DAC output
                capture_dac_frame(result);
                check($sformatf("Sine sample %0d", i), result, compute_expected(tb_samples));
            end
        end
endmodule