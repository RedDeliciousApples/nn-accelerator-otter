`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly
// Engineer: Christian Saliba and Kai Hoag
// 
// Create Date: 11/03/2026 11:11:17 AM
// Design Name: 
// Module Name: mac4
// Project Name: nn-accel-otter
// Target Devices: Basys3 - Artix-7 XC7A35T-1CPG236C
// Tool Versions: Vivado 2026.2
// Description: 
// Four signed int8 x int8 multipliers and an adder tree over one packed word.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mac4 (
    input  logic [31:0]        x,
    input  logic [31:0]        w,
    output logic signed [17:0] result
);
    assign result = $signed(x[7:0])   * $signed(w[7:0])
                  + $signed(x[15:8])  * $signed(w[15:8])
                  + $signed(x[23:16]) * $signed(w[23:16])
                  + $signed(x[31:24]) * $signed(w[31:24]);
endmodule
