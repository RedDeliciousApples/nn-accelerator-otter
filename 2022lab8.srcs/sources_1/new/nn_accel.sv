`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly
// Engineer: Christian Saliba and Kai Hoag
// 
// Create Date: 11/03/2026 11:00:17 AM
// Design Name: 
// Module Name: nn_accel
// Project Name: nn-accel-otter
// Target Devices: Basys3 - Artix-7 XC7A35T-1CPG236C
// Tool Versions: Vivado 2026.2
// Description: 
// Top level of the accelerator. Wires the MMIO registers, controller FSM,
// address generator, MAC and hidden registers, and drives memory data port 2.
// Dependencies: accel_mmio.sv, accel_fsm.sv, addr_gen.sv, mac4.sv, dot_doer.sv, hidden_regs.sv
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//                      +--------------------------+
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

    logic               start;
    logic               done;

    logic               last_group;
    logic               last_row;
    logic               layer2;
    logic               start_row;
    logic               add_en;
    logic               shift_ld;
    logic               w_ld;
    logic               hidden_we;
    logic [2:0]         addr_sel;
    logic               clr_group;
    logic               inc_group;
    logic               clr_row;
    logic               inc_row;
    logic               set_layer2;
    logic [2:0]         group_sel;
    logic [4:0]         row_sel;

    logic [31:0]        shift_reg;
    logic [31:0]        w_reg;
    logic [31:0]        x_word;
    logic [31:0]        neuron_out4;

    logic signed [17:0] mac4_result;
    logic signed [31:0] neuron_value;

    accel_mmio mmio (
        .clk     (clk),
        .rst     (rst),
        .io_addr (io_addr),
        .io_wr   (io_wr),
        .io_din  (io_din),
        .busy    (busy),
        .done    (done),
        .start   (start),
        .io_dout (io_dout)
    );

    accel_fsm fsm (
        .clk        (clk),
        .rst        (rst),
        .start      (start),
        .last_group (last_group),
        .last_row   (last_row),
        .layer2     (layer2),
        .busy       (busy),
        .done       (done),
        .start_row  (start_row),
        .add_en     (add_en),
        .mem_rden   (mem_rden),
        .mem_we     (mem_we),
        .addr_sel   (addr_sel),
        .shift_ld   (shift_ld),
        .w_ld       (w_ld),
        .hidden_we  (hidden_we),
        .clr_group  (clr_group),
        .inc_group  (inc_group),
        .clr_row    (clr_row),
        .inc_row    (inc_row),
        .set_layer2 (set_layer2)
    );

    addr_gen agen (
        .clk        (clk),
        .rst        (rst),
        .addr_sel   (addr_sel),
        .clr_group  (clr_group),
        .inc_group  (inc_group),
        .clr_row    (clr_row),
        .inc_row    (inc_row),
        .set_layer2 (set_layer2),
        .mem_addr   (mem_addr),
        .last_group (last_group),
        .last_row   (last_row),
        .layer2     (layer2),
        .group_sel  (group_sel),
        .row_sel    (row_sel)
    );

    mac4 mac (
        .x      (x_word),
        .w      (w_reg),
        .result (mac4_result)
    );

    dot_doer dd (
        .layer_sel          (~layer2),
        .mac4_result        (mac4_result),
        .shift_amt          (shift_reg[4:0]),
        .clk                (clk),
        .rst                (rst),
        .start_row          (start_row),
        .add_en             (add_en),
        .bias               (mem_dout),
        .neuron_value_ready (),
        .neuron_value       (neuron_value)
    );

    hidden_regs hregs (
        .clk           (clk),
        .rst           (rst),
        .start_ld      (hidden_we),
        .neuron_in     (neuron_value[7:0]),
        .neuron_in_sel (row_sel),
        .group_out_sel (group_sel),
        .neuron_out4   (neuron_out4)
    );

    always_ff @(posedge clk) begin
        if (rst)           shift_reg <= 32'b0;
        else if (shift_ld) shift_reg <= mem_dout;
    end

    always_ff @(posedge clk) begin
        if (rst)       w_reg <= 32'b0;
        else if (w_ld) w_reg <= mem_dout;
    end

    assign x_word  = layer2 ? neuron_out4 : mem_dout;
    assign mem_din = neuron_value;

endmodule
