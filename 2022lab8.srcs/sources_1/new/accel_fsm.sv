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

    );
    

    typedef enum logic [2:0] {
        S_IDLE      = 3'd0,
        S_CLR       = 3'd1,
        S_START     = 3'd2,
        S_WAITDONE  = 3'd3,
        S_WRITE     = 3'd4,
        S_NEXTADDR  = 3'd5,
        S_DONE      = 3'd6
    } state_t;

    state_t PS, NS;

    // State register
    always_ff @(posedge clk) begin
        if (rst) PS <= S_IDLE;
        else     PS <= NS;
    end

    // Next-state + outputs
    always_comb begin
        NS = PS;

        // defaults
        rom_clr  = 1'b0;
        rom_ce   = 1'b0;

        ram_clr  = 1'b0;
        ram_inc  = 1'b0;
        ram_we   = 1'b0;

        pc_start = 1'b0;
        max_ld   = 1'b0;

        done     = 1'b0;

        unique case (PS)

            // Wait for start
            S_IDLE: begin
                done = 1'b0;
                if (btn_go) NS = S_CLR;
            end

            // Clear counters/max ONCE
            S_CLR: begin
                rom_clr = 1'b1;
                ram_clr = 1'b1;
                NS      = S_START;
            end

            // Pulse prime checker start (1 clk_slow cycle)
            S_START: begin
                pc_start = 1'b1;
                NS       = S_WAITDONE;
            end

            // Wait for done from prime checker
            S_WAITDONE: begin
                if (pc_done) NS = S_WRITE;
            end

            // If prime: write to RAM and maybe load max
            S_WRITE: begin
                if (pc_prime) begin
                    ram_we  = 1'b1;
                    ram_inc = 1'b1;
                    if (gt) max_ld = 1'b1;
                end

                if (rom_rco) NS = S_DONE;
                else         NS = S_NEXTADDR;
            end

            // Increment ROM address
            S_NEXTADDR: begin
                rom_ce = 1'b1;
                NS     = S_START;
            end

            // Done state: wait for button to restart
            S_DONE: begin
                done = 1'b1;
                if (btn_go) NS = S_CLR;
            end

            default: NS = S_IDLE;

        endcase
    end
    
endmodule
