`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/04/2026 10:16:38 AM
// Design Name: 
// Module Name: dot_doer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Computes dot product for specific neurons. 
//
// 
// Dependencies: MAC4 FSM, layer_sel = 1 means 196 accums, 0 means 8 accums
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//decideds what layer we are accumulatig
//adds bias
//clamps
//sends ready signal


module dot_doer(
    input logic layer_sel,
    input logic signed [17:0] mac4_result,
    input logic [4:0] shift_amt,
    input clk,
    input rst,
    input start_row,
    input add_en,
    input logic signed [31:0] bias,
    
    output logic neuron_value_ready,
    output logic signed [31:0] neuron_value
);
    
    logic signed [31:0] acc;
    logic signed [31:0] next_sum;
    logic signed [31:0] shifted;
    logic [7:0] group_count;
    logic [7:0] last_group;
    
    assign last_group = layer_sel ? 8'd195 : 8'd7; // count starts at 0
    assign next_sum = acc + {{14{mac4_result[17]}}, mac4_result};
    assign shifted  = next_sum >>> shift_amt;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            acc          <= 0;
            group_count  <= 0;
            neuron_value       <= 0;
            neuron_value_ready <= 0;
        end else begin
            neuron_value_ready <= 0;
    
            if (start_row) begin
                acc         <= bias; // start this row with its bias
                group_count <= 0;
            end else if (add_en) begin
                acc         <= next_sum;
                group_count <= group_count + 1'b1;
    
                if (group_count == last_group) begin
                    if (layer_sel) begin
                        // First layer: shift and clamp to 0..127
                        if (shifted < 0)
                            neuron_value <= 0;
                        else if (shifted > 127)
                            neuron_value <= 127;
                        else
                            neuron_value <= shifted;
                    end else begin
                        // Second layer: keep the full score
                        neuron_value <= next_sum;
                    end
    
                    neuron_value_ready <= 1;
                end
            end
        end
    end
    
    
    
endmodule
