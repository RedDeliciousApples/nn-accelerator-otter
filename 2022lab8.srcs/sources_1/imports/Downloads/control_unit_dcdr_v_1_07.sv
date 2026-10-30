`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////
// Company: Ratner Surf Designs
// Engineer: James Ratner
// 
// Create Date: 01/29/2019 04:56:13 PM
// Design Name: 
// Module Name: CU_DCDR
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies:
// 
// Instantiation Template:
//
// CU_DCDR my_cu_dcdr(
//   .br_eq     (xxxx), 
//   .br_lt     (xxxx), 
//   .br_ltu    (xxxx),
//   .opcode    (xxxx),    
//   .func7     (xxxx),    
//   .func3     (xxxx),    
//   .ALU_FUN   (xxxx),
//   .PC_SEL    (xxxx),
//   .srcA_SEL  (xxxx),
//   .srcB_SEL  (xxxx), 
//   .RF_SEL    (xxxx)   );
//
// 
// Revision:
// Revision 1.00 - Created (02-01-2020) - from Paul, Joseph, & Celina
//          1.01 - (02-08-2020) - removed  else's; fixed assignments
//          1.02 - (02-25-2020) - made all assignments blocking
//          1.03 - (05-12-2020) - reduced func7 to one bit
//          1.04 - (05-31-2020) - removed misleading code
//          1.05 - (12-10-2020) - added comments
//          1.06 - (02-11-2021) - fixed formatting issues
//          1.07 - (12-26-2023) - changed signal names
//
// Additional Comments:
// 
///////////////////////////////////////////////////////////////////////////

module CU_DCDR(
   input br_eq, 
   input br_lt, 
   input br_ltu,
   input int_taken,
   input [6:0] opcode,   //-  ir[6:0]
   input func7,          //-  ir[30]
   input [2:0] func3,    //-  ir[14:12] 
   output logic [3:0] ALU_FUN,
   output logic [2:0] PC_SEL,
   output logic [1:0] srcA_SEL,
   output logic [2:0] srcB_SEL, 
   output logic [1:0] RF_SEL   );
    
   //- datatypes for RISC-V opcode types
   typedef enum logic [6:0] {
        LUI    = 7'b0110111,    // done
        AUIPC  = 7'b0010111,    // maybe done
        JAL    = 7'b1101111,    // done
        JALR   = 7'b1100111,    // done
        BRANCH = 7'b1100011,    // done
        LOAD   = 7'b0000011,    // done maybe
        STORE  = 7'b0100011,    // check if even need to check opcodes for this because the memory module looks at the store and load opcodes
        OP_IMM = 7'b0010011,    // done
        OP_RG3 = 7'b0110011,
        SYS    = 7'b1110011     
   } opcode_t;
   opcode_t OPCODE; //- define variable of new opcode type
    
   assign OPCODE = opcode_t'(opcode); //- Cast input enum 
	typedef enum logic [2:0] {
        CSRRW = 3'b001,
        CSRRS = 3'b010,
        CSRRC = 3'b011,
        MRET  = 3'b000
   } func3_t;
   func3_t csrfunc3;
   //- datatype for func3Symbols tied to values
   typedef enum logic [2:0] {
        //BRANCH labels
        BEQ  = 3'b000,
        BNE  = 3'b001,
        BLT  = 3'b100,
        BGE  = 3'b101,
        BLTU = 3'b110,
        BGEU = 3'b111
   } branch_func3_t; 
   branch_func3_t br_f3;
   
   // OP_IMM funct3 
   typedef enum logic [2:0] {
        ADDI  = 3'b000,
        SLLI  = 3'b001,     // check funct7
        SLTI  = 3'b010,
        SLTIU = 3'b011,
        XORI  = 3'b100,
        SRXI  = 3'b101,     // check funct7
        ORI   = 3'b110,
        ANDI  = 3'b111
   } op_imm_func3_t;
   op_imm_func3_t op_imm_f3;
   
   // OP_RG3 funct3 
   typedef enum logic [2:0] {
        ADD_SUB  = 3'b000,     // check funct7
        SLL      = 3'b001,
        SLT      = 3'b010,
        SLTU     = 3'b011,
        XOR      = 3'b100,
        SRX      = 3'b101,    // check funct7
        OR       = 3'b110,
        AND      = 3'b111
   } op_rg3_func3_t;
   op_rg3_func3_t op_rg3_f3;
       
   always_comb
   begin 
      //- schedule all values to avoid latch
        PC_SEL = 3'b000;  srcB_SEL = 3'b000;     RF_SEL = 2'b00; 
      srcA_SEL = 2'b00;   ALU_FUN  = 4'b0000;
	
	   // upadatinf funct3 
	   br_f3     = branch_func3_t'(func3);
	   op_imm_f3 = op_imm_func3_t'(func3);
	   op_rg3_f3 = op_rg3_func3_t'(func3);
	   csrfunc3 = func3_t'(func3);
	   	if (int_taken == 1'b1)
            PC_SEL = 3'b100;
        else begin 
       case(OPCODE)
          LUI:                      // good 
          begin                     //
            ALU_FUN = 4'b1001;     //
            srcA_SEL = 2'b01;       //
            RF_SEL = 2'b11;        //
          end                       //
          
          AUIPC:
          begin
             srcA_SEL = 2'b01;
             srcB_SEL = 3'b011;    // pc
             ALU_FUN  = 4'b0000;  // add
             RF_SEL   = 2'b11;
          end
			
          JAL:
          begin
		 	RF_SEL = 2'b00;
			PC_SEL = 3'b011; 
          end
         
         JALR:
         begin
            srcA_SEL = 2'b00;
            srcB_SEL = 3'b001;
            RF_SEL   = 2'b00;
            PC_SEL   = 3'b001;
         end
         
         BRANCH: begin   
            unique case (br_f3)
                BEQ:
                begin
                    if (br_eq == 1'b1)   PC_SEL = 3'b010;                       
                end 
                
                BNE:
                begin
                    if (br_eq == 1'b0)  PC_SEL = 3'b010;  
                end
                
                BLT:
                begin
                    if (br_lt == 1'b1)   PC_SEL = 3'b010;
                end 
                
                BGE:
                begin
                    if (br_lt == 1'b0)  PC_SEL = 3'b010;
                end 
                
                BLTU:
                begin
                    if (br_ltu == 1'b1)  PC_SEL = 3'b010;
                end
                
                BGEU:
                begin
                    if (br_ltu == 1'b0 ) PC_SEL = 3'b010;
                end
                default: PC_SEL = 3'b000;  // and use other top defaults
            endcase
         end       
        			
         LOAD:  // generic load func3 handeled by memory                     
         begin
           ALU_FUN = 4'b0000;
           srcA_SEL = 2'b00; 
           srcB_SEL = 3'b001; 
           RF_SEL   = 2'b10;            
		 end	
		
         STORE:  // generic store func3 handeled by memory
         begin
            ALU_FUN = 4'b0000; 
            srcA_SEL = 2'b00; 
            srcB_SEL = 3'b010; 
		 end	
			
         OP_IMM:
         begin
            srcB_SEL = 3'b001;
            RF_SEL   = 2'b11;
            unique case (op_imm_f3)
               ADDI: // instr: ADDI                 // good 
                  ALU_FUN = 4'b0000;   
               
               SLLI: 
                  ALU_FUN = 4'b0001;
               
               SLTI:
                  ALU_FUN = 4'b0010;
                  
               SLTIU:
                  ALU_FUN = 4'b0011;
                  
               XORI:
                  ALU_FUN = 4'b0100;
               
               SRXI:
               begin
                  if (func7 == 1'b0)       ALU_FUN = 4'b0101;   // SRLI
                  if (func7 == 1'b1)       ALU_FUN = 4'b1101;   // SRAI
               end
               
               ORI:
                  ALU_FUN = 4'b0110;
               
               ANDI:
                  ALU_FUN = 4'b0111;
					
               default: ;
            endcase
         end
         
         OP_RG3:
         begin
         srcA_SEL = 2'b00;
         srcB_SEL = 3'b000;
         RF_SEL   = 2'b11;
            unique case(op_rg3_f3)
               ADD_SUB: // instr: ADD
               begin                   // good 
                  if (func7 == 1'b0)      ALU_FUN = 4'b0000;  // ADD
                  if (func7 == 1'b1)      ALU_FUN = 4'b1000;  // SUB
               end
               
               SLL:
                  ALU_FUN = 4'b0001;      
                  
               SLT:
                  ALU_FUN = 4'b0010;
                        
               SLTU:
                  ALU_FUN = 4'b0011;   
                  
               XOR:
                  ALU_FUN = 4'b0100;
                        
               SRX:
               begin
                  if (func7 == 1'b0)     ALU_FUN = 4'b0101;  // srl
                  if (func7 == 1'b1)     ALU_FUN = 4'b1101;  // sra
               end 
                         
               OR:
                  ALU_FUN = 4'b0110; 
                      
               AND:
                  ALU_FUN = 4'b0111;     
     
               default: ;
            endcase
         end
         
         SYS:
         begin
         RF_SEL = 2'b00;
         PC_SEL = 3'b000;
         srcB_SEL = 3'b000;
         srcA_SEL = 2'b00;
            unique case (csrfunc3)
                CSRRW:
                begin
                    PC_SEL = 3'b000;
                    srcB_SEL = 3'b100;
                    RF_SEL = 2'b01; 
                    srcA_SEL = 2'b00;
                    ALU_FUN  = 4'b1001;
                end
                
                CSRRC:
                begin
                    srcB_SEL = 3'b100;
                    RF_SEL = 2'b01; 
                    srcA_SEL = 2'b10;
                    ALU_FUN  = 4'b0111;
                end
                
                CSRRS:
                begin
                    srcB_SEL = 3'b100;
                    RF_SEL = 2'b01; 
                    srcA_SEL = 2'b00;
                    ALU_FUN  = 4'b0110;
                end
                
                MRET:
                begin
                    PC_SEL = 3'b101;
                end
            endcase
         end
         
         default:
         begin
             PC_SEL = 3'b000; 
             srcB_SEL = 3'b000; 
             RF_SEL = 2'b00; 
             srcA_SEL = 2'b00; 
             ALU_FUN = 4'b0000;
         end
      endcase
      end
   end

endmodule