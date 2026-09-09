`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly
// Engineer: 
// 
// Create Date: 01/24/2026 10:45:46 AM
// Design Name: 
// Module Name: alu
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: alu for OTTER implementing 9 assembly instructions (note: lui doesn't shift by 12 in here, it shifts somewhere else)
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ALU(
    input logic [31:0] OP_1,
    input logic [31:0] OP_2,
    input logic [3:0] ALU_FUN,
    output logic [31:0] RESULT
    );
    always_comb
    case (ALU_FUN)
        4'b0000: RESULT = OP_1 + OP_2; //add
        
        4'b1000: RESULT  = OP_1 - OP_2; //sub
        
        4'b0110: RESULT = OP_1 | OP_2; // or
        
        4'b0111: RESULT = OP_1 & OP_2; //and
        
        4'b0100: RESULT = OP_1 ^ OP_2; //xor
        
        4'b0101: RESULT = OP_1 >> OP_2[4:0]; //srl
        
        4'b0001: RESULT = OP_1 << OP_2[4:0]; //sll
        
        4'b1101: RESULT = $signed(OP_1) >>> $signed(OP_2[4:0]); //sra
        
        4'b0010: RESULT = ($signed(OP_1) < $signed(OP_2)) ? 1 : 0; //slt
        
        4'b0011: RESULT = (OP_1 < OP_2) ? 1 : 0; //sltu
        
        4'b1001: RESULT = OP_1;
        
        default: RESULT = -559038737;
    endcase
    
endmodule



