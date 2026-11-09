`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/09/2026 10:22:29 AM
// Design Name: 
// Module Name: hidden_regs
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies:  
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module hidden_regs(
    input logic  clk,
    input logic  rst,
    input logic  start_ld,
    //write signals
    input [7:0]  neuron_in,
    input logic [4:0] neuron_in_sel,
    
    //read signals
    input logic [2:0] group_out_sel,
    output [31:0] neuron_out4
    );
    
    //hidden is a array of 32 8 bit arrays
    logic [7:0] hidden [0:31];
    always_ff @(posedge clk) 
    begin 
        if(rst)
        begin
            for (int i = 0; i < 32; i++) 
            begin
                hidden[i] <= 8'b0;
            end
        end
        else if(start_ld)
        begin
            hidden[neuron_in_sel] <= neuron_in;
        end
    end 
    
    assign neuron_out4 = {hidden[{group_out_sel,2'b11}], hidden[{group_out_sel,2'b10}],
                          hidden[{group_out_sel,2'b01}], hidden[{group_out_sel,2'b00}]};
endmodule
