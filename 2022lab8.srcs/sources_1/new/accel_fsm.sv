`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/04/2026 11:49:21 AM
// Design Name: 
// Module Name: accel_fsm
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


module accel_fsm(
        input  logic       clk,
        input  logic       rst,
        input  logic       start,
        input  logic       last_group,   // final group of the row, valid in S_ADD
        input  logic       last_row,
        input  logic       layer2,       // 0 = layer 1, 1 = layer 2

        output logic       busy,
        output logic       done,
        output logic       start_row,
        output logic       add_en,
        output logic       mem_rden,
        output logic       mem_we,
        output logic [2:0] addr_sel,
        output logic       shift_ld,
        output logic       w_ld,
        output logic       hidden_we,

        output logic       clr_group,
        output logic       inc_group,
        output logic       clr_row,
        output logic       inc_row,
        output logic       set_layer2
        );

    // addr_sel encoding, must match the address generator
    localparam logic [2:0] ADDR_SHIFT  = 3'd0;
    localparam logic [2:0] ADDR_BIAS   = 3'd1;
    localparam logic [2:0] ADDR_WEIGHT = 3'd2;
    localparam logic [2:0] ADDR_IMAGE  = 3'd3;
    localparam logic [2:0] ADDR_SCORE  = 3'd4;

    typedef enum logic [3:0] {
        S_IDLE,
        S_SHIFT_ADDR,
        S_SHIFT_CAP,
        S_BIAS_ADDR,
        S_ROW_START,
        S_W_ADDR,
        S_X_ADDR,
        S_ADD,
        S_STORE,
        S_NEXT,
        S_DONE
    } state_t;

    state_t PS, NS;

    always_ff @(posedge clk) begin
        if (rst) PS <= S_IDLE;
        else     PS <= NS;
    end

    always_comb begin
        NS = PS;

        busy       = 1'b0;
        done       = 1'b0;
        start_row  = 1'b0;
        add_en     = 1'b0;
        mem_rden   = 1'b0;
        mem_we     = 1'b0;
        addr_sel   = ADDR_SHIFT;
        shift_ld   = 1'b0;
        w_ld       = 1'b0;
        hidden_we  = 1'b0;
        clr_group  = 1'b0;
        inc_group  = 1'b0;
        clr_row    = 1'b0;
        inc_row    = 1'b0;
        set_layer2 = 1'b0;

        unique case (PS)

            S_IDLE: begin
                clr_group = 1'b1;
                clr_row = 1'b1;
                if (start) begin
                    NS = S_SHIFT_ADDR;
                end
            end

            S_SHIFT_ADDR: begin
                busy = 1'b1;
                mem_rden = 1'b1;
                addr_sel = ADDR_SHIFT;
                NS = S_SHIFT_CAP;
            end

            S_SHIFT_CAP: begin
                busy = 1'b1;
                shift_ld = 1'b1;
                NS = S_BIAS_ADDR;
            end

            S_BIAS_ADDR: begin
                busy = 1'b1;
                mem_rden = 1'b1;
                addr_sel = ADDR_BIAS;
                NS = S_ROW_START;
            end

            S_ROW_START: begin
                busy = 1'b1;
                start_row = 1'b1;
                clr_group = 1'b1;
                NS = S_W_ADDR;
            end
            //ask for weight from memory
            S_W_ADDR: begin
                busy = 1'b1;
                mem_rden = 1'b1;
                addr_sel = ADDR_WEIGHT;
                NS = S_X_ADDR;
            end
            //1 cc later, it's here, so put it in the weight register
            S_X_ADDR: begin
                busy = 1'b1;
                w_ld = 1'b1;

                if (!layer2)begin
                    mem_rden = 1'b1;
                    addr_sel = ADDR_IMAGE;
                end

                NS = S_ADD;
            end

            S_ADD: begin
                busy = 1'b1;
                add_en = 1'b1;
                inc_group = 1'b1;

                if (last_group) begin
                    NS = S_STORE;
                end
                else begin
                    NS = S_W_ADDR;
                end
                
            end

            S_STORE: begin
                busy = 1'b1;
                inc_row = 1'b1;
                
                if (!layer2) begin
                    hidden_we = 1'b1;
                end
                else begin
                    hidden_we = 1'b0;
                    mem_we = 1'b1;
                    addr_sel = ADDR_SCORE;
                end

                NS = S_NEXT;
            end

            S_NEXT: begin
            end

            S_DONE: begin
            end

            default: NS = S_IDLE;

        endcase
    end

endmodule
