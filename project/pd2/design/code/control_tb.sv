`timescale 1ns/1ps

// control_tb.sv
// quick unit test for control.sv
// we just poke opcode/funct3/funct7 (and sometimes insn[31:25]) and make sure outputs match.
// it's combinational, so there's no clock/reset drama here.

module control_tb;
  localparam int DWIDTH = 32;

  // dut inputs (what we drive)
  logic [DWIDTH-1:0] insn_i;
  logic [6:0]        opcode_i, funct7_i;
  logic [2:0]        funct3_i;

  // dut outputs (what we check)
  logic        pcsel_o;
  logic        immsel_o;
  logic        regwren_o;
  logic        rs1sel_o;
  logic        rs2sel_o;
  logic        memren_o;
  logic        memwren_o;
  logic [1:0]  wbsel_o;
  logic [3:0]  alusel_o;

  // plug in the real module
  control #(.DWIDTH(DWIDTH)) dut (
    .insn_i    (insn_i),
    .opcode_i  (opcode_i),
    .funct3_i  (funct3_i),
    .funct7_i  (funct7_i),
    .pcsel_o   (pcsel_o),
    .immsel_o  (immsel_o),
    .regwren_o (regwren_o),
    .rs1sel_o  (rs1sel_o),
    .rs2sel_o  (rs2sel_o),
    .memren_o  (memren_o),
    .memwren_o (memwren_o),
    .wbsel_o   (wbsel_o),
    .alusel_o  (alusel_o)
  );

  // these must match your control.sv encodings (if you change them there, change them here too)
  localparam logic [1:0] WB_OFF = 2'b00;
  localparam logic [1:0] WB_ALU = 2'b01;
  localparam logic [1:0] WB_MEM = 2'b10;
  localparam logic [1:0] WB_PC4 = 2'b11;

  localparam logic [3:0] ALU_ADD  = 4'h0;
  localparam logic [3:0] ALU_SUB  = 4'h1;
  localparam logic [3:0] ALU_AND  = 4'h2;
  localparam logic [3:0] ALU_OR   = 4'h3;
  localparam logic [3:0] ALU_XOR  = 4'h4;
  localparam logic [3:0] ALU_SLL  = 4'h5;
  localparam logic [3:0] ALU_SRL  = 4'h6;
  localparam logic [3:0] ALU_SRA  = 4'h7;
  localparam logic [3:0] ALU_SLT  = 4'h8;
  localparam logic [3:0] ALU_SLTU = 4'h9;

  // tiny helper so we don't manually concatenate 32-bit instructions 10 times
  // also: your srai/srli logic looks at insn_i[31:25], so this helps us set that cleanly
  function automatic logic [31:0] mk_insn(
    input logic [6:0] f7,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] f3,
    input logic [4:0] rd,
    input logic [6:0] opc
  );
    mk_insn = {f7, rs2, rs1, f3, rd, opc};
  endfunction

  // compare all outputs at once
  // if something is wrong, we want it to scream at us with a nice name
  task automatic check_ctrl(
    input string name,
    input logic exp_pcsel,
    input logic exp_immsel,
    input logic exp_regwren,
    input logic exp_rs1sel,
    input logic exp_rs2sel,
    input logic exp_memren,
    input logic exp_memwren,
    input logic [1:0] exp_wbsel,
    input logic [3:0] exp_alusel
  );
    bit ok = 1;

    if (pcsel_o   !== exp_pcsel)   begin $error("%s: pcsel   exp=%b got=%b", name, exp_pcsel, pcsel_o); ok=0; end
    if (immsel_o  !== exp_immsel)  begin $error("%s: immsel  exp=%b got=%b", name, exp_immsel, immsel_o); ok=0; end
    if (regwren_o !== exp_regwren) begin $error("%s: regwren exp=%b got=%b", name, exp_regwren, regwren_o); ok=0; end
    if (rs1sel_o  !== exp_rs1sel)  begin $error("%s: rs1sel  exp=%b got=%b", name, exp_rs1sel, rs1sel_o); ok=0; end
    if (rs2sel_o  !== exp_rs2sel)  begin $error("%s: rs2sel  exp=%b got=%b", name, exp_rs2sel, rs2sel_o); ok=0; end
    if (memren_o  !== exp_memren)  begin $error("%s: memren  exp=%b got=%b", name, exp_memren, memren_o); ok=0; end
    if (memwren_o !== exp_memwren) begin $error("%s: memwren exp=%b got=%b", name, exp_memwren, memwren_o); ok=0; end
    if (wbsel_o   !== exp_wbsel)   begin $error("%s: wbsel   exp=%b got=%b", name, exp_wbsel, wbsel_o); ok=0; end
    if (alusel_o  !== exp_alusel)  begin $error("%s: alusel  exp=%h got=%h", name, exp_alusel, alusel_o); ok=0; end

    if (ok) $display("pass: %s", name);
  endtask

  initial begin
    // r-type add: reg write, alu add, no imm, no mem
    opcode_i = 7'b0110011;
    funct3_i = 3'b000;
    funct7_i = 7'b0000000;
    insn_i   = mk_insn(funct7_i, 5'd2, 5'd1, funct3_i, 5'd3, opcode_i);
    #1;
    check_ctrl("r-type add", 0,0, 1, 0,0, 0,0, WB_ALU, ALU_ADD);

    // r-type sub: same but funct7=0x20
    funct7_i = 7'h20;
    insn_i   = mk_insn(funct7_i, 5'd2, 5'd1, funct3_i, 5'd3, opcode_i);
    #1;
    check_ctrl("r-type sub", 0,0, 1, 0,0, 0,0, WB_ALU, ALU_SUB);

    // i-type addi: reg write, rs2=imm, alu add
    opcode_i = 7'b0010011;
    funct3_i = 3'b000;
    funct7_i = 7'h00;
    insn_i   = mk_insn(funct7_i, 5'd2, 5'd1, funct3_i, 5'd3, opcode_i);
    #1;
    check_ctrl("i-type addi", 0,1, 1, 0,1, 0,0, WB_ALU, ALU_ADD);

    // srli vs srai: your control checks insn[31:25], not funct7_i, so we set that via mk_insn
    funct3_i = 3'b101;

    // srli -> insn[31:25] = 0
    insn_i = mk_insn(7'h00, 5'd2, 5'd1, funct3_i, 5'd3, opcode_i);
    #1;
    check_ctrl("i-type srli", 0,1, 1, 0,1, 0,0, WB_ALU, ALU_SRL);

    // srai -> insn[31:25] = 0x20
    insn_i = mk_insn(7'h20, 5'd2, 5'd1, funct3_i, 5'd3, opcode_i);
    #1;
    check_ctrl("i-type srai", 0,1, 1, 0,1, 0,0, WB_ALU, ALU_SRA);

    // load lw: mem read + reg writeback from mem
    opcode_i = 7'b0000011;
    funct3_i = 3'b010;
    funct7_i = 7'h00;
    insn_i   = mk_insn(funct7_i, 5'd0, 5'd1, funct3_i, 5'd3, opcode_i);
    #1;
    check_ctrl("load lw", 0,1, 1, 0,1, 1,0, WB_MEM, ALU_ADD);

    // store sw: mem write, no reg write
    // also yeah: your store uses rs2sel=1 (imm) because alu is doing address calc
    opcode_i = 7'b0100011;
    funct3_i = 3'b010;
    funct7_i = 7'h00;
    insn_i   = mk_insn(funct7_i, 5'd2, 5'd1, funct3_i, 5'd0, opcode_i);
    #1;
    check_ctrl("store sw", 0,1, 0, 0,1, 0,1, WB_OFF, ALU_ADD);

    // branch beq: in your pd2 you *don't* take branches yet, so pcsel stays 0
    // but you still set up pc + imm for later (rs1sel=pc, rs2sel=imm)
    opcode_i = 7'b1100011;
    funct3_i = 3'b000;
    funct7_i = 7'h00;
    insn_i   = mk_insn(funct7_i, 5'd2, 5'd1, funct3_i, 5'd0, opcode_i);
    #1;
    check_ctrl("branch beq (pd2 not-taken)", 0,1, 0, 1,1, 0,0, WB_OFF, ALU_ADD);

    // jal: always redirects pc + writes pc+4 to rd
    opcode_i = 7'b1101111;
    funct3_i = 3'b000;
    funct7_i = 7'h00;
    insn_i   = mk_insn(funct7_i, 5'd0, 5'd0, funct3_i, 5'd1, opcode_i);
    #1;
    check_ctrl("jal", 1,1, 1, 1,1, 0,0, WB_PC4, ALU_ADD);

    // jalr: redirects pc too, but target is rs1 + imm
    opcode_i = 7'b1100111;
    funct3_i = 3'b000;
    funct7_i = 7'h00;
    insn_i   = mk_insn(funct7_i, 5'd0, 5'd1, funct3_i, 5'd1, opcode_i);
    #1;
    check_ctrl("jalr", 1,1, 1, 0,1, 0,0, WB_PC4, ALU_ADD);

    // lui: decode should make rs1=x0 so alu does 0 + imm (same control settings here)
    opcode_i = 7'b0110111;
    funct3_i = 3'b000;
    funct7_i = 7'h00;
    insn_i   = mk_insn(funct7_i, 5'd0, 5'd0, funct3_i, 5'd1, opcode_i);
    #1;
    check_ctrl("lui", 0,1, 1, 0,1, 0,0, WB_ALU, ALU_ADD);

    // auipc: alu uses pc + imm, write to rd
    opcode_i = 7'b0010111;
    funct3_i = 3'b000;
    funct7_i = 7'h00;
    insn_i   = mk_insn(funct7_i, 5'd0, 5'd0, funct3_i, 5'd1, opcode_i);
    #1;
    check_ctrl("auipc", 0,1, 1, 1,1, 0,0, WB_ALU, ALU_ADD);

    $display("done. control looks good.");
    $finish;
  end

endmodule