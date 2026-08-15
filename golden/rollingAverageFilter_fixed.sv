`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name:  rollingAverageFilter  (corrected)
// Changes vs current:
//   1. window HOLDS when ADC_valid is low (was: cleared every idle cycle)
//   2. divide and DAC scaling applied as one operation, parameterised in N
//////////////////////////////////////////////////////////////////////////////////
module rollingAverageFilter (
    input  logic clk,
    input  logic rst_n,
    input  logic [7:0] filter_Din,
    input  logic ADC_valid,
    output logic [11:0] filter_Dout,
    output logic filter_ready,
    output logic data_valid
    );

    localparam int N        = 64;
    localparam int LOG2_N   = $clog2(N);
    localparam int SUM_BITS = 8 + LOG2_N;
    localparam int SHIFT_UP = 4;                 // 12-bit DAC / 8-bit ADC

    logic [7:0]          samples [N-1:0];
    logic [SUM_BITS-1:0] partial [N:0];
    logic [SUM_BITS-1:0] sum;
    logic [SUM_BITS+SHIFT_UP-1:0] scaled;

    genvar i;
    generate
        for (i = 0; i < N; i++) begin : g_shift
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)          samples[i] <= 8'b0;
                else if (ADC_valid) begin
                    if (i == 0)      samples[0] <= filter_Din;
                    else             samples[i] <= samples[i-1];
                end
                // else: HOLD. clearing here destroys the window.
            end
        end
    endgenerate

    assign partial[0] = '0;
    generate
        for (i = 0; i < N; i++) begin : g_sum
            assign partial[i+1] = partial[i] + samples[i];
        end
    endgenerate
    assign sum = partial[N];

    // one-step divide-and-scale: (sum << 4) >> log2(N)
    assign scaled = sum << SHIFT_UP;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            filter_Dout <= '0;
            data_valid  <= 1'b0;
        end else begin
            filter_Dout <= scaled[SUM_BITS+SHIFT_UP-1 : LOG2_N];
            data_valid  <= 1'b1;
        end
    end

    assign filter_ready = 1'b1;
endmodule
