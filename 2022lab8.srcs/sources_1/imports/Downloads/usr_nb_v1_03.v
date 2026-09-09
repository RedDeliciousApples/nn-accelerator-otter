`timescale 1ns / 1ps
`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company:   Ratner Surf Designs
// Engineer:  James Ratner
// 
// Create Date: 07/04/2018 02:46:31 PM
// Design Name: 
// Module Name: usr_nb
// Project Name: 
// Target Devices: 
// Tool  Versions: 
// Description: Generic n-bit universial shift register 
//                    with a asynchronous positive logic reset. 
//
//
//      SEL  |  Operation   
//   -----------------------------------------------
//       00  |  Hold
//       01  |  Load         (input data_in)
//       10  |  Shift left   (input dbit on right)
//       11  |  Shift right  (input dbit on left)
//
//
// Instantiation Template: 
//
// usr_nb #(.n(16)) my_usr (
//     .data_in  (xxxx), 
//     .dbit     (xxxx), 
//     .sel      (xxxx), 
//     .clk      (xxxx), 
//     .clr      (xxxx), 
//     .data_out (xxxx)   );  
//
// Dependencies: 
// 
// Revision:
// Revision 1.00 (07-06-2018) - File Created 
//          1.01 (11-03-2019) - changed comments for clarity
//                                added explicit wire declarations
//          1.02 (11-24-2019) - added macros; made edits
//          1.03 (12-20-2020) - changed paramter location
//                               removed default
//        
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module usr_nb #(parameter n=8) ( 
    input  wire [n-1:0] data_in, 
    input  wire dbit,  
    input  wire clk,   
	input  wire clr,  
    input  wire [1:0] sel, 
    output reg [n-1:0] data_out  ); 

    
    always @(posedge clr, posedge clk)
    begin 
        if (clr == 1'b1)     // asynch +logic reset
           data_out <= 0;
        else 
           case (sel) 
              0: data_out <= data_out;                // hold value
              1: data_out <= data_in;                 // load
              2: data_out <= {data_out[n-2:0],dbit};  // shift left
              3: data_out <= {dbit,data_out[n-1:1]};  // shift right
              //default data_out <= 0; 
           endcase 
    end
    
endmodule

`default_nettype wire
