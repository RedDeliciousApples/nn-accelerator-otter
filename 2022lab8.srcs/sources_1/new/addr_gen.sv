`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/13/2026 11:22:36 AM
// Design Name: 
// Module Name: addr_gen
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


module addr_gen(
        input logic clk,
        input logic rst,
        input logic [2:0] addr_sel,
        
        input logic clr_grp,
        input logic inc_grp,
        input logic set_layer2,
        
        output logic [31:0] mem_addr,
        output logic last_group,
        output logic last_row,
        output logic layer2,
        output logic [2:0] group_sel,
        output logic [4:0] row_sel
        
        
    );
endmodule
