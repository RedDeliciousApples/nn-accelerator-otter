`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2026 01:16:15 PM
// Design Name: 
// Module Name: csr_test
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


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Ratner Surf Designs
// Engineer:  James Ratner
// 
// Create Date: 01/07/2020 12:59:51 PM
// Design Name: 
// Module Name: Ex6_6_testbench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Testbench file for Exp 6
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module csr_test(); 

   reg [15:0] switches; 
   reg [4:0] buttons;
   reg clk; 
   wire [15:0] leds; 
   wire [7:0] segs; 
   wire [3:0] an; 


CSR my_csr(
    .CLK        (clk),
    .RST        (reset),
    .MRET_EXEC  (mret_exec),
    .INT_TAKEN  (int_taken),
    .ADDR       (12'b0),
    .PC         (pc_out),
    .WD         (result),
    .WR_EN      (csr_WE),
    .RD         (csr_RD),
    .CSR_MEPC   (mepc),
    .CSR_MTVEC  (mtvec),
    .CSR_MSTATUS_MIE (mstatus_3) );

   
  //- Generate periodic clock signal    
   initial    
      begin       
         clk = 0;   //- init signal        
         forever  #10 clk = ~clk;    
      end                        
         
   initial        
   begin           
      buttons = 5'b01000;    
      switches = 16'h0000;
      #80;

      buttons = 5'b00000;    
      #80;
      buttons = 5'b01000;
      #80;
      buttons = 5'b10000;
      #20000;
      buttons = 5'b00000;
      #1500;
      $finish;
    end

endmodule

