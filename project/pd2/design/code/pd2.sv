/*
 * Module: pd2
 *
 * Description: Top level module that will contain sub-module instantiations.
 *
 * Inputs:
 * 1) clk
 * 2) reset signal
 */

module pd2 #(
    parameter int AWIDTH = 32,
    parameter int DWIDTH = 32)(
    input logic clk,
    input logic reset
);

 /*
  * Instantiate other submodules and
  * probes. To be filled by student...
  *
  */

  // fetch probes
  logic [AWIDTH-1:0] probe_f_pc;
  logic [DWIDTH-1:0] probe_f_insn;

  // decode probes
  logic [AWIDTH-1:0] probe_d_pc;
  logic [DWIDTH-1:0] probe_d_insn;
  logic [6:0]        probe_d_opcode;
  logic [4:0]        probe_d_rd;
  logic [4:0]        probe_d_rs1;
  logic [4:0]        probe_d_rs2;
  logic [6:0]        probe_d_funct7;
  logic [2:0]        probe_d_funct3;
  logic [4:0]        probe_d_shamt;

  // igen probe
  logic [DWIDTH-1:0] probe_imm;

  // control probes
  logic              probe_pcsel;
  logic              probe_immsel;
  logic              probe_regwren;
  logic              probe_rs1sel;
  logic              probe_rs2sel;
  logic              probe_memren;
  logic              probe_memwren;
  logic [1:0]        probe_wbsel;
  logic [3:0]        probe_alusel;

  // fetch (your fetch already contains the memory inside it, so no extra memory instance here)
  fetch #(
    .DWIDTH(DWIDTH),
    .AWIDTH(AWIDTH)
  ) u_fetch (
    .clk   (clk),
    .rst   (reset),
    .pc_o  (probe_f_pc),
    .insn_o(probe_f_insn)
  );

  // decode
  decode #(
    .DWIDTH(DWIDTH),
    .AWIDTH(AWIDTH)
  ) u_decode (
    .clk     (clk),
    .rst     (reset),
    .insn_i  (probe_f_insn),
    .pc_i    (probe_f_pc),

    .pc_o    (probe_d_pc),
    .insn_o  (probe_d_insn),
    .opcode_o(probe_d_opcode),
    .rd_o    (probe_d_rd),
    .rs1_o   (probe_d_rs1),
    .rs2_o   (probe_d_rs2),
    .funct7_o(probe_d_funct7),
    .funct3_o(probe_d_funct3),
    .shamt_o (probe_d_shamt),
    .imm_o   ()              // decode imm is dummy in your design
  );

  // immediate generator
  igen #(
    .DWIDTH(DWIDTH)
  ) u_igen (
    .opcode_i(probe_d_opcode),
    .insn_i  (probe_d_insn),
    .imm_o   (probe_imm)
  );

  // control (based on decoded fields)
  control #(
    .DWIDTH(DWIDTH)
  ) u_control (
    .insn_i   (probe_d_insn),
    .opcode_i (probe_d_opcode),
    .funct7_i (probe_d_funct7),
    .funct3_i (probe_d_funct3),

    .pcsel_o  (probe_pcsel),
    .immsel_o (probe_immsel),
    .regwren_o(probe_regwren),
    .rs1sel_o (probe_rs1sel),
    .rs2sel_o (probe_rs2sel),
    .memren_o (probe_memren),
    .memwren_o(probe_memwren),
    .wbsel_o  (probe_wbsel),
    .alusel_o (probe_alusel)
  );

  // next step later: datapath (regfile, alu, pc logic, data memory hookup, writeback mux, etc.)
  // for pd2 right now, having fetch->decode->igen/control all wired is the main goal.


endmodule : pd2
