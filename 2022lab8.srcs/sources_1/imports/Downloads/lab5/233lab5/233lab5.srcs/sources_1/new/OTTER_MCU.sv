module OTTER_MCU (
    input logic RST,
    input logic intr,
    input logic clk,
    input logic [31:0] iobus_in,
    output logic [31:0] iobus_out,
    output logic [31:0] iobus_addr,
    output logic iobus_wr
    );
    
    
    //###############
    // DECLARE INTERNAL SIGNALS OF MCU
    //###############
    
    // PC SIGNALS
    logic PC_WE;                                // from FSM, going into PC
    logic [2:0] PC_SEL;                         // from DCDR, going into PC
    logic [31:0] pc_out;                        // 32-bit PC output
    logic [31:0] pc_in;                         // 32-bit PC input (from 4x1 PC MUX)
    logic [15:2] pc_out_final;                  // 14-bit output from pc_out[15:2]
    logic reset;
    
    logic [31:0] jal, branch, jalr;             // jump instructions (4x1 PC MUX)
    
    logic [31:0] pc_out_plus_four;              // pc_out + 4
    assign pc_out_plus_four = pc_out + 32'd4;
    
    //PC MUX INTERRUPTS
    logic [31:0] mtvec;
    logic [31:0] mepc;
    
    //DECODER INTERRUPTS
    logic int_taken;
    //CSR STUFF
    logic csr_WE;
    logic mret_exec;
    logic mstatus_3;
    logic [31:0] csr_RD;
    logic intr_and;
    // ALU SIGNALS
    logic [31:0] ALU_srcA;                      // OP_1 of ALU
    logic [31:0] ALU_srcB;                      // OP_2 of ALU
    logic [1:0] srcA_SEL;                             // from DCDR, going into 2x1 ALU MUX
    logic [2:0] srcB_SEL;                       // from DCDR, going into 4x1 ALU MUX
    logic [3:0] ALU_FUN;                        // from DCDR, going into ALU
    logic [31:0] result;                        // output of ALU
    
    // REG_FILE SIGNALS
    logic RF_WE;                                // from FSM, going into REG_FILE
    logic [1:0] RF_SEL;                         // from DCDR, going into 4x1 REG_FILE MUX
    logic [31:0] w_data;                        // connect REG_FILE to 4x1 REG_FILE MUX
    logic [31:0] rs1;
    logic [31:0] not_rs1;                           // register 1value
    logic [31:0] rs2;                           // register 2 value
    
    // MEMORY 
    logic [31:0] MEMORY_DOUT2;                  // MEMORY DOUT2
    logic memRDEN1, memRDEN2, memWE2;           // from FSM, going into MEMORY
    logic [31:0] ir;                            // MEMORY DOUT1
    //Branch cond gen
    logic br_eq, br_lt, br_ltu;
    
    //################
    //CSR
    //################
      CSR  my_csr (
    .CLK        (clk),
    .RST        (reset),
    .MRET_EXEC  (mret_exec),
    .INT_TAKEN  (int_taken),
    .ADDR       (ir[31:20]),
    .PC         (pc_out),
    .WD         (result),
    .WR_EN      (csr_WE),
    .RD         (csr_RD),
    .CSR_MEPC   (mepc),
    .CSR_MTVEC  (mtvec),
    .CSR_MSTATUS_MIE (mstatus_3)    );
    //###############
    // INSTANTIATE PROGRAM COUNTER
    //###############
    
    // PROGRAM COUNTER (PC)
	reg_nb #(.n(32)) pc_reg (
       .data_in  (pc_in), 
       .ld       (PC_WE), 
       .clk      (clk), 
       .clr      (reset), 
       .data_out (pc_out) );

    // PC MUX (6 to 1 now to support interrupts)
    mux_8t1_nb  #(.n(32)) pc_mux  (
       .SEL   (PC_SEL), 
       .D0    (pc_out_plus_four), 
       .D1    (jalr), 
       .D2    (branch), 
       .D3    (jal),
       .D4    (mtvec),
       .D5    (mepc),
       .D6    (32'b0),
       .D7    (32'b0),
       .D_OUT (pc_in) 
    );
    
    assign pc_out_final = pc_out[15:2];
    
    //###############
    // IMMEDIATE GENERATOR
    //###############
    logic [31:0] I_type, J_type, B_type, U_type, S_type;
    assign U_type = {ir[31:12], 12'b0};                                         // connected to ALU 2x1 MUX (srcA)
    assign I_type = {{20{ir[31]}}, ir[31], ir[30:25], ir[24:20]};               // connected to BAG, ALU 4x1 MUX (srcB)
    assign S_type = {{20{ir[31]}}, ir[31], ir[30:25], ir[11:7]};                // connected to ALU 4x1 MUX (srcB)
    assign J_type = {{11{ir[31]}}, ir[31], ir[19:12], ir[20], ir[30:21], 1'b0}; // connected to BAG
    assign B_type = {{19{ir[31]}}, ir[31], ir[7], ir[30:25], ir[11:8], 1'b0};   // connected to BAG
    
    
    //###############
    // BRANCH ADDR GENERATOR (BAG)
    //###############
    assign jal = pc_out + (J_type);
    assign jalr = rs1 + (I_type);               
    assign branch = pc_out + (B_type);
    
    //###########
    // Branch Condition Generator
    //############
    
    always_comb begin
        br_eq = 1'b0;
        br_lt = 1'b0;
        br_ltu = 1'b0;
        
        if (rs1 == rs2) br_eq = 1'b1;
        if ($signed(rs1) < $signed(rs2)) br_lt = 1'b1;
        if (rs1 < rs2) br_ltu = 1'b1;
        
        
    end
    
    //###############
    // INSTANTIATE ARITHMETIC LOGIC UNIT (ALU)
    //###############
    ALU ALU (
        .OP_1(ALU_srcA),
        .OP_2(ALU_srcB),
        .RESULT(result),
        .ALU_FUN(ALU_FUN)
    );
    
    assign iobus_addr = result;
    assign not_rs1 = ~rs1;
    // ALU MUXes
    mux_4t1_nb #(.n(32)) alu_srcA_mux (
       .SEL(srcA_SEL),
       .D0(rs1),
       .D1(U_type),
       .D2(not_rs1),
       .D3(32'b0),
       .D_OUT(ALU_srcA)
    );
    
    mux_8t1_nb #(.n(32)) alu_srcB_mux (
        .SEL(srcB_SEL),
        .D0(rs2),
        .D1(I_type),
        .D2(S_type),
        .D3(pc_out), //should not be pc_out_plus_4
        .D4(csr_RD),
        .D5(32'b0),
        .D6(32'b0),
        .D7(32'b0),
        .D_OUT(ALU_srcB)
    );
    
    
    //###############
    // INSTANTIATE REG_FILE
    //###############
    RegFile REG_FILE (
        .w_data(w_data),
        .clk(clk),
        .en(RF_WE),
        .adr1(ir[19:15]),
        .adr2(ir[24:20]),
        .w_adr(ir[11:7]),
        .rs1(rs1),
        .rs2(rs2)
    );
    
    
    assign iobus_out = rs2;
    
    mux_4t1_nb #(.n(32)) reg_file_mux (
        .SEL(RF_SEL),
        .D0(pc_out_plus_four),
        .D1(csr_RD),
        .D2(MEMORY_DOUT2),
        .D3(result),
        .D_OUT(w_data)
    );
    assign intr_and = intr & mstatus_3;
    //###############
    // INSTANTIATE FSM AND DCDR
    //###############
    CU_FSM CU_FSM (
        .intr(intr_and),
        .clk(clk),
        .RST(RST),
        .opcode(ir[6:0]),
        .FUNC3(ir[14:12]),
        .PC_WE(PC_WE),
        .RF_WE(RF_WE),
        .memWE2(memWE2),
        .memRDEN1(memRDEN1),
        .memRDEN2(memRDEN2),
        .reset(reset),
        .csr_WE(csr_WE),
        .int_taken(int_taken),
        .mret_exec(mret_exec)
    );
    
    CU_DCDR CU_DCDR (
        .br_eq(br_eq),
        .br_lt(br_lt),
        .br_ltu(br_ltu),
        .int_taken(int_taken),
        .opcode(ir[6:0]),
        .func7(ir[30]),
        .func3(ir[14:12]),
        .ALU_FUN(ALU_FUN),
        .PC_SEL(PC_SEL),
        .srcA_SEL(srcA_SEL),
        .srcB_SEL(srcB_SEL),
        .RF_SEL(RF_SEL)
    );
    
    
 
  //###############
  // INSTANTIATE MEMORY
  //###############
  Memory OTTER_MEMORY ( 
    .MEM_CLK   (clk),            // clock
    .MEM_RDEN1 (memRDEN1),       // memRDEN1 (from FSM)
    .MEM_RDEN2 (memRDEN2),       // memRDEN2 (from FSM)
    .MEM_WE2   (memWE2),         // memWE2   (from FSM)
    .MEM_ADDR1 (pc_out_final),   // pc_out_final (from PC)
    .MEM_ADDR2 (result),         // ALU result
    .MEM_DIN2  (rs2),            // REG_FILE rs2
    .MEM_SIZE  (ir[13:12]),      // from memory output ir
    .MEM_SIGN  (ir[14]),         // from memory output ir
    .IO_IN     (iobus_in),       // outside world input (LEDs & buttons)
    .IO_WR     (iobus_wr),       // outside world output 
    .MEM_DOUT1 (ir),             // memory output 32-bit signal 
    .MEM_DOUT2 (MEMORY_DOUT2)    // memory output into 4x1 REG_FILE MUX (for store instructions??)
     ); 
  
endmodule