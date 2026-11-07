`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/07/2026 03:25:33 PM
// Design Name: 
// Module Name: accel_mmio
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
// Ports
//- From the CPU side: clk, rst, io_addr, io_wr, io_din.
//- To the CPU side: io_dout.
//- To the FSM: start, a one-cycle pulse.
//- From the FSM: busy and done.
//////////////////////////////////////////////////////////////////////////////////


module accel_mmio(
        input logic clk,
        input logic rst,
        input logic [31:0] io_addr,
        input logic io_wr,
        input logic [31:0] io_din,
        input logic busy,
        input logic done,
        
        output logic start,
        output logic [31:0] io_dout
    );
    
     localparam logic [31:0] CTRL_ADDR = 32'h11010000;
     localparam logic [31:0] STATUS_ADDR = 32'h11010004;
     logic done_flag = 1'b0;
     logic start_seen = 1'b0;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            start <= 1'b0; start_seen <= 1'b0;
        end
        else begin
            start <= 1'b0;
            if (io_wr && io_addr == CTRL_ADDR && io_din[0] && !busy) begin
                start <= 1'b1;
                start_seen <= 1'b1;
            end
            else if (busy) begin
                start_seen <= 1'b0;
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if (rst)done_flag <= 1'b0;
        else begin
            if (done && !start) begin
                done_flag <= 1;
            end 
            else if (start) begin
                done_flag <= 0;
            end
        end
    end
    
    always_comb begin
        io_dout = 32'b0;
        if (io_addr == STATUS_ADDR)
            io_dout = {30'b0, done_flag, busy | start_seen};
        else io_dout = 32'b0;
    end
    
    
endmodule
