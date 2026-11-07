`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: dot_doer_tb
// Description: Testbench for dot_doer, with mac4 in front of it so the test uses
//              real packed int8 words (x = image/hidden word, w = weight word).
//
// Flow of each test (see run_row):
//   1. set layer_sel / shift_amt / bias
//   2. pulse start_row for one clock   -> acc loads the bias
//   3. for each group: drive x_word / w_word, hold add_en for one clock
//   4. wait for neuron_value_ready, compare neuron_value with the expected value
//////////////////////////////////////////////////////////////////////////////////

module dot_doer_tb();

    // DUT inputs
    reg                layer_sel;     // 1 = layer 1 (196 groups, shift + clamp), 0 = layer 2 (8 groups, raw sum)
    reg  [4:0]         shift_amt;
    reg                clk;
    reg                rst;
    reg                start_row;
    reg                add_en;
    reg  signed [31:0] bias;

    // mac4 inputs (packed 4 x int8 each)
    reg  [31:0]        x_word;
    reg  [31:0]        w_word;

    // wires between mac4 and dot_doer, and DUT outputs
    wire signed [17:0] mac4_result;
    wire               neuron_value_ready;
    wire signed [31:0] neuron_value;

    integer errors = 0;

    mac4 my_mac4 (
        .x      (x_word),
        .w      (w_word),
        .result (mac4_result)
    );

    dot_doer dut (
        .layer_sel          (layer_sel),
        .mac4_result        (mac4_result),
        .shift_amt          (shift_amt),
        .clk                (clk),
        .rst                (rst),
        .start_row          (start_row),
        .add_en             (add_en),
        .bias               (bias),
        .neuron_value_ready (neuron_value_ready),
        .neuron_value       (neuron_value)
    );

    //- clock
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    //- Words to feed, index 0 first. Layer 1 uses 196 groups, layer 2 uses 8.
    reg [31:0] x_mem [0:195];
    reg [31:0] w_mem [0:195];

    integer g;

    // Fill the first n entries of both arrays with one repeated word each
    task fill(input integer n, input [31:0] w, input [31:0] x);
        integer j;
        begin
            for (j = 0; j < 196; j = j + 1) begin
                w_mem[j] = (j < n) ? w : 32'h0;
                x_mem[j] = (j < n) ? x : 32'h0;
            end
        end
    endtask

    // Run one row and check it. layer: 1 = layer 1 (196 groups), 0 = layer 2 (8 groups)
    task run_row(input layer, input [4:0] shift, input signed [31:0] bias_in,
                 input signed [31:0] expected, input [255:0] name);
        integer n;
        begin
            n = layer ? 196 : 8;
            layer_sel = layer;
            shift_amt = shift;
            bias      = bias_in;

            @(negedge clk);
            start_row = 1;
            @(negedge clk);
            start_row = 0;

            for (g = 0; g < n; g = g + 1) begin
                x_word = x_mem[g];
                w_word = w_mem[g];
                add_en = 1;
                @(negedge clk);          // one group per clock
            end
            add_en = 0;

            // neuron_value_ready is a registered pulse, high right after the last add
            if (neuron_value_ready !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL %0s: neuron_value_ready not high after the last group", name);
            end
            if (neuron_value !== expected) begin
                errors = errors + 1;
                $display("FAIL %0s: got %0d, expected %0d", name, neuron_value, expected);
            end else
                $display("PASS %0s: %0d", name, neuron_value);
        end
    endtask

    initial begin
        rst = 1;
        start_row = 0;
        add_en = 0;
        layer_sel = 1;
        shift_amt = 12;
        bias = 32'b0;
        x_word = 0;
        w_word = 0;
        fill(0, 0, 0);
        repeat (3) @(posedge clk);
        rst = 0;
        @(negedge clk);

        // layer 2 (8 groups, raw sum, bias included)
        // each group: 4 lanes of 1*2 = 8, so 8 groups = 64
        fill(8, 32'h01010101, 32'h02020202);
        run_row(1'b0, 5'd0, 32'sd100, 32'sd164, "L2 simple, 100+64");

        // negative weights: 4 lanes of -1*1 = -4 per group, 8 groups = -32
        fill(8, 32'hFFFFFFFF, 32'h01010101);
        run_row(1'b0, 5'd0, 32'sd10, -32'sd22, "L2 negative, 10-32");

        // large score, outside int8: 4 * 127 * 127 = 64516 per group, 8 groups = 516128
        fill(8, 32'h7F7F7F7F, 32'h7F7F7F7F);
        run_row(1'b0, 5'd0, 32'sd0, 32'sd516128, "L2 large, 516128");

        // layer 1 (196 groups, shift, clamp 0..127)
        // 8 per group * 196 = 1568, >>> 4 = 98 (in range)
        fill(196, 32'h01010101, 32'h02020202);
        run_row(1'b1, 5'd4, 32'sd0, 32'sd98, "L1 in range, 1568>>4");

        // clamp high: (5000 + 1568) >>> 4 = 410 -> 127
        run_row(1'b1, 5'd4, 32'sd5000, 32'sd127, "L1 clamp to 127");

        // clamp low: -4 per group * 196 = -784, >>> 4 = -49 -> 0
        fill(196, 32'hFFFFFFFF, 32'h01010101);
        run_row(1'b1, 5'd4, 32'sd0, 32'sd0, "L1 clamp to 0");

        $display("---- done, %0d errors ----", errors);
        $finish;
    end

endmodule
