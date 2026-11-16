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
        
        input logic clr_group,
        input logic inc_group,
        input logic clr_row,
        input logic inc_row,
        input logic set_layer2,
        
        output logic [31:0] mem_addr,
        output logic last_group,
        output logic last_row,
        output logic layer2,
        output logic [2:0] group_sel,
        output logic [4:0] row_sel
        
        
    );

    logic [7:0] group;
    logic [5:0] row;

    always_ff @(posedge clk) begin
        if (rst) begin
            group <= 0;
        end else if (clr_group) begin
            group <= 0;
        end else if (inc_group) begin
            group <= group + 1;
        end
    end

    //same, but for row
    always_ff @(posedge clk) begin
        if (rst) begin
            row <= 0;
        end else if (clr_row) begin
            row <= 0;
        end else if (inc_row) begin
            row <= row + 1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            layer2 <= 0;
        end else if (clr_row) begin
            layer2 <= set_layer2;
        end
    end

    assign last_group =  layer2 ? (group == 8'd7) : (group == 8'd195);
    assign last_row = layer2 ? (row == 6'd10) : (row == 6'd32);
    assign group_sel = group[2:0];
    assign row_sel = row[4:0];

    // addr_sel encoding, must match the FSM
    localparam logic [2:0] ADDR_SHIFT  = 3'd0;
    localparam logic [2:0] ADDR_BIAS   = 3'd1;
    localparam logic [2:0] ADDR_WEIGHT = 3'd2;
    localparam logic [2:0] ADDR_IMAGE  = 3'd3;
    localparam logic [2:0] ADDR_SCORE  = 3'd4;

    // counters widened to 32 bits, as byte offsets (one word = 4 bytes)
    logic [31:0] row_ext, group_ext;
    assign row_ext   = {26'b0, row};
    assign group_ext = {24'b0, group};

    always_comb begin
        case (addr_sel)
            // HIDDEN_SHIFT
            ADDR_SHIFT:  mem_addr = 32'hA3E8;

            // HIDDEN_B + 4n (layer 1) or OUTPUT_B + 4k (layer 2)
            ADDR_BIAS:   mem_addr = (layer2 ? 32'hA3C0 : 32'hA200) + (row_ext << 2);

            // layer 1: HIDDEN_W + n*784 + 4g    layer 2: OUTPUT_W + k*32 + 4g
            ADDR_WEIGHT: mem_addr = layer2 ? (32'hA280 + (row_ext << 5)      + (group_ext << 2))
                                           : (32'h4000 + (row_ext * 32'd784) + (group_ext << 2));

            // IMAGE + 4g (layer 1 only)
            ADDR_IMAGE:  mem_addr = 32'hA400 + (group_ext << 2);

            // SCORES + 4k (layer 2 only)
            ADDR_SCORE:  mem_addr = 32'hA800 + (row_ext << 2);

            default:     mem_addr = 32'b0;
        endcase
    end
endmodule
