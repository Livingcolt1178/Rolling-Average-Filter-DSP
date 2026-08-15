`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:     Nicholas Bramhall
// Module Name:  rollingAverageFilter_ref_tb
// Description:  Self-checking testbench for the N-tap rolling average filter,
//               driven against an independent reference model.
//
//               The reference model below is written from the SPECIFICATION, not
//               from the DUT. That is the point. A model transcribed from the RTL
//               agrees with the RTL by construction and cannot catch a design bug.
//
//               Stimulus deliberately includes an impulse, steps and tones,
//               because a moving average of a held constant returns that constant
//               and so cannot distinguish a working filter from a wire.
//////////////////////////////////////////////////////////////////////////////////

module rollingAverageFilter_ref_tb;

    localparam int N          = 64;
    localparam int LOG2_N     = $clog2(N);
    localparam int ADC_BITS   = 8;
    localparam int DAC_BITS   = 12;
    localparam int SHIFT_UP   = DAC_BITS - ADC_BITS;   // x16, ADC/DAC LSB ratio
    localparam int SAMPLE_DIV = 16;                    // clocks per ADC sample

    logic clk = 0;
    logic rst_n;
    logic [ADC_BITS-1:0] filter_Din;
    logic ADC_valid;

    logic [DAC_BITS-1:0] filter_Dout;
    logic filter_ready;
    logic data_valid;

    int errors  = 0;
    int checks  = 0;

    always #10 clk = ~clk;                             // 50 MHz

    rollingAverageFilter dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .filter_Din (filter_Din),
        .ADC_valid  (ADC_valid),
        .filter_Dout(filter_Dout),
        .filter_ready(filter_ready),
        .data_valid (data_valid)
    );

    // =====================================================================
    // Reference model - from spec
    //   one sample per ADC sample period, not per clock
    //   Dout = (sum << 4) >> log2(N), applied as ONE operation so the
    //   average is not re-quantised onto whole ADC codes
    // =====================================================================
    logic [ADC_BITS-1:0]        ref_win [0:N-1];
    logic [ADC_BITS+LOG2_N-1:0] ref_sum;
    logic [DAC_BITS-1:0]        ref_out;

    function automatic void ref_reset();
        for (int i = 0; i < N; i++) ref_win[i] = '0;
        ref_sum = '0;
        ref_out = '0;
    endfunction

    function automatic logic [DAC_BITS-1:0] ref_step(input logic [ADC_BITS-1:0] s);
        logic [ADC_BITS+LOG2_N+SHIFT_UP-1:0] scaled;
        for (int i = N-1; i > 0; i--) ref_win[i] = ref_win[i-1];
        ref_win[0] = s;
        ref_sum = '0;
        for (int i = 0; i < N; i++) ref_sum += ref_win[i];
        scaled = ref_sum << SHIFT_UP;
        return scaled >> LOG2_N;
    endfunction

    // =====================================================================
    // Stimulus driver: one sample every SAMPLE_DIV clocks, valid is a PULSE
    // =====================================================================
    task automatic send(input logic [ADC_BITS-1:0] s);
        @(negedge clk);
        filter_Din = s;
        ADC_valid  = 1'b1;
        ref_out    = ref_step(s);
        @(negedge clk);
        ADC_valid  = 1'b0;
        @(posedge clk);                                // DUT registers output here
        #1;
        checks++;
        if (filter_Dout !== ref_out) begin
            errors++;
            if (errors <= 12)
                $display("  MISMATCH  t=%0t  in=%02h  dut=%03h  ref=%03h  (delta %0d)",
                         $time, s, filter_Dout, ref_out, $signed({1'b0,filter_Dout}) - $signed({1'b0,ref_out}));
        end
        repeat (SAMPLE_DIV - 3) @(negedge clk);        // idle between samples
    endtask

    task automatic run_block(input string name);
        $display("  [%s] cumulative errors = %0d / %0d checks", name, errors, checks);
    endtask

    initial begin
        rst_n = 0; filter_Din = '0; ADC_valid = 0;
        ref_reset();
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        $display("\n=== rollingAverageFilter vs reference model (N=%0d) ===\n", N);

        // 1. impulse - exposes the true window length
        repeat (4) send(8'h00);
        send(8'hFF);
        repeat (N + 6) send(8'h00);
        run_block("impulse");

        // 2. step - settling must take exactly N samples
        repeat (2*N) send(8'd200);
        repeat (2*N) send(8'd40);
        run_block("step");

        // 3. two-tone - 1 kHz passband rider on a 200 kHz stopband tone
        for (int i = 0; i < 600; i++) begin
            real t, v;
            t = i / 3.125e6;
            v = 1.65 + 0.8*$sin(2.0*3.14159265*1.0e3*t) + 0.4*$sin(2.0*3.14159265*200.0e3*t);
            send(adc_encode(v));
        end
        run_block("two-tone");

        // 4. dithered DC - sub-LSB content, exercises the scaling question
        for (int i = 0; i < 200; i++) begin
            real t, v;
            t = i / 3.125e6;
            v = 1.6120 + 0.004*$sin(2.0*3.14159265*97.0e3*t);
            send(adc_encode(v));
        end
        run_block("dithered DC");

        $display("\n--------------------------------------------------");
        if (errors == 0)
            $display("  PASS   %0d checks, 0 mismatches", checks);
        else
            $display("  FAIL   %0d mismatches out of %0d checks", errors, checks);
        $display("--------------------------------------------------\n");
        $finish;
    end

    function automatic logic [ADC_BITS-1:0] adc_encode(input real volts);
        int code;
        code = int'(volts / 3.3 * 256.0);
        if (code < 0)   code = 0;
        if (code > 255) code = 255;
        return code[ADC_BITS-1:0];
    endfunction

endmodule
