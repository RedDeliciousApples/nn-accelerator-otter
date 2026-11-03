`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2026 11:00:17 AM
// Design Name: 
// Module Name: nn_accel
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
//                       +--------------------------+
//        clk --------->|                          |
//        rst --------->|                          |
//                      |                          |
//   io_addr[31:0] ---->|                          |----> io_dout[31:0]
//        io_wr ------->|                          |
//   io_din[31:0] ----->|        nn_accel          |----> busy
//                      |                          |
//   mem_dout[31:0] --->|                          |----> mem_addr[31:0]
//                      |                          |----> mem_rden
//                      |                          |----> mem_we
//                      |                          |----> mem_din[31:0]
//                      +--------------------------+
//        inputs (left)                outputs (right)
//////////////////////////////////////////////////////////////////////////////////


module nn_accel (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] io_addr,
    input  logic        io_wr,
    input  logic [31:0] io_din,
    output logic [31:0] io_dout,

    input  logic [31:0] mem_dout,
    output logic [31:0] mem_addr,
    output logic        mem_rden,
    output logic        mem_we,
    output logic [31:0] mem_din,
    output logic        busy
);
endmodule
