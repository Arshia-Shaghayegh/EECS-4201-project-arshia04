`timescale 1ns/1ps

// decode_tb.sv
// unit test for decode.sv (pd2)
//
// decode.sv right now is basically combinational:
// - pc_o   = pc_i
// - insn_o = insn_i
// - opcode_o = insn_i[6:0]
// - rd/rs1/rs2/funct3/funct7/shamt decoded based on opcode
// - imm_o is dummy (always 0) because igen will handle immediates later
//
// so we:
// - drive insn_i + pc_i
// - wait #1
// - check outputs

module decode_tb;

  localparam int AWIDTH = 32;
  localparam int DWIDTH = 32;

  logic clk, rst;
  logic [DWIDTH-1:0] insn_i;
  logic [AWIDTH-1:0] pc_i;

  logic [AWIDTH-1:0] pc_o;
  logic [DWIDTH-1:0] insn_o;
  logic [6:0]        opcode_o, funct7_o;
  logic [4:0]        rd_o, rs1_o, rs2_o, shamt_o;
  logic [2:0]        funct3_o;
  logic [DWIDTH-1:0] imm_o;

  decode #(.DWIDTH(DWIDTH), .AWIDTH(AWIDTH)) dut (
    .clk     (clk),
    .rst     (rst),
    .insn_i  (insn_i),
    .pc_i    (pc_i),
    .pc_o    (pc_o),
    .insn_o  (insn_o),
    .opcode_o(opcode_o),
    .rd_o    (rd_o),
    .rs1_o   (rs1_o),
    .rs2_o   (rs2_o),
    .funct7_o(funct7_o),
    .funct3_o(funct3_o),
    .shamt_o (shamt_o),
    .imm_o   (imm_o)
  );

  // clock isn't required for current decode, but we keep it to match the module ports
  initial clk = 0;
  always #10 clk = ~clk;

  // helper to build insn = {funct7, rs2, rs1, funct3, rd, opcode}
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

  task automatic check_decode(
    input string name,
    input logic [31:0] exp_insn,
    input logic [31:0] exp_pc,
    input logic [6:0]  exp_opcode,
    input logic [4:0]  exp_rd,
    input logic [4:0]  exp_rs1,
    input logic [4:0]  exp_rs2,
    input logic [2:0]  exp_funct3,
    input logic [6:0]  exp_funct7,
    input logic [4:0]  exp_shamt,
    input logic [31:0] exp_imm
  );
    bit ok = 1;

    if (insn_o   !== exp_insn)   begin $error("%s: insn_o   exp=%h got=%h", name, exp_insn, insn_o); ok=0; end
    if (pc_o     !== exp_pc)     begin $error("%s: pc_o     exp=%h got=%h", name, exp_pc, pc_o); ok=0; end
    if (opcode_o !== exp_opcode) begin $error("%s: opcode   exp=%b got=%b", name, exp_opcode, opcode_o); ok=0; end
    if (rd_o     !== exp_rd)     begin $error("%s: rd      exp=%0d got=%0d", name, exp_rd, rd_o); ok=0; end
    if (rs1_o    !== exp_rs1)    begin $error("%s: rs1     exp=%0d got=%0d", name, exp_rs1, rs1_o); ok=0; end
    if (rs2_o    !== exp_rs2)    begin $error("%s: rs2     exp=%0d got=%0d", name, exp_rs2, rs2_o); ok=0; end
    if (funct3_o !== exp_funct3) begin $error("%s: funct3  exp=%b got=%b", name, exp_funct3, funct3_o); ok=0; end
    if (funct7_o !== exp_funct7) begin $error("%s: funct7  exp=%b got=%b", name, exp_funct7, funct7_o); ok=0; end
    if (shamt_o  !== exp_shamt)  begin $error("%s: shamt   exp=%0d got=%0d", name, exp_shamt, shamt_o); ok=0; end
    if (imm_o    !== exp_imm)    begin $error("%s: imm_o   exp=%h got=%h", name, exp_imm, imm_o); ok=0; end

    if (ok) $display("pass: %s", name);
  endtask

  initial begin
    rst    = 1;
    insn_i = '0;
    pc_i   = '0;
    #1;
    rst    = 0;

    // r-type add: rd/rs1/rs2/funct3/funct7
    insn_i = mk_insn(7'h00, 5'd3, 5'd2, 3'b000, 5'd1, 7'b0110011);
    pc_i   = 32'h0000_0000;
    #1;
    check_decode("R-type ADD", insn_i, pc_i, 7'b0110011, 5'd1, 5'd2, 5'd3, 3'b000, 7'h00, 5'd0, 32'h0);

    // i-type addi: rd/rs1/funct3 only (rs2/funct7/shamt stay 0 in your decode)
    insn_i = mk_insn(7'h00, 5'd10, 5'd6, 3'b000, 5'd5, 7'b0010011);
    pc_i   = 32'h0000_0004;
    #1;
    check_decode("I-type ADDI", insn_i, pc_i, 7'b0010011, 5'd5, 5'd6, 5'd0, 3'b000, 7'h00, 5'd0, 32'h0);

    // srli: funct3=101 -> decode should capture shamt + funct7
    insn_i = mk_insn(7'h00, 5'd4, 5'd9, 3'b101, 5'd8, 7'b0010011);
    pc_i   = 32'h0000_0008;
    #1;
    check_decode("I-type SRLI", insn_i, pc_i, 7'b0010011, 5'd8, 5'd9, 5'd0, 3'b101, 7'h00, 5'd4, 32'h0);

    // srai: funct7=0x20, shamt=7
    insn_i = mk_insn(7'h20, 5'd7, 5'd9, 3'b101, 5'd8, 7'b0010011);
    pc_i   = 32'h0000_000C;
    #1;
    check_decode("I-type SRAI", insn_i, pc_i, 7'b0010011, 5'd8, 5'd9, 5'd0, 3'b101, 7'h20, 5'd7, 32'h0);

    // load lw
    insn_i = mk_insn(7'h00, 5'd0, 5'd1, 3'b010, 5'd3, 7'b0000011);
    pc_i   = 32'h0000_0010;
    #1;
    check_decode("LOAD LW", insn_i, pc_i, 7'b0000011, 5'd3, 5'd1, 5'd0, 3'b010, 7'h00, 5'd0, 32'h0);

    // store sw
    insn_i = mk_insn(7'h00, 5'd7, 5'd8, 3'b010, 5'd0, 7'b0100011);
    pc_i   = 32'h0000_0014;
    #1;
    check_decode("STORE SW", insn_i, pc_i, 7'b0100011, 5'd0, 5'd8, 5'd7, 3'b010, 7'h00, 5'd0, 32'h0);

    // branch beq
    insn_i = mk_insn(7'h00, 5'd2, 5'd1, 3'b000, 5'd0, 7'b1100011);
    pc_i   = 32'h0000_0018;
    #1;
    check_decode("BRANCH BEQ", insn_i, pc_i, 7'b1100011, 5'd0, 5'd1, 5'd2, 3'b000, 7'h00, 5'd0, 32'h0);

    // jal: rd only in your decode
    insn_i = 32'h0000006F; // jal x0, 0
    pc_i   = 32'h0000_001C;
    #1;
    check_decode("JAL (rd only)", insn_i, pc_i, 7'b1101111, insn_i[11:7], 5'd0, 5'd0, 3'b000, 7'h00, 5'd0, 32'h0);

    // jalr: rd + rs1
    insn_i = mk_insn(7'h00, 5'd0, 5'd5, 3'b000, 5'd1, 7'b1100111);
    pc_i   = 32'h0000_0020;
    #1;
    check_decode("JALR (rd+rs1)", insn_i, pc_i, 7'b1100111, 5'd1, 5'd5, 5'd0, 3'b000, 7'h00, 5'd0, 32'h0);

    // lui: rd only
    insn_i = 32'b00010010001101000101_01010_0110111;
    pc_i   = 32'h0000_0024;
    #1;
    check_decode("LUI (rd only)", insn_i, pc_i, 7'b0110111, 5'd10, 5'd0, 5'd0, 3'b000, 7'h00, 5'd0, 32'h0);

    // auipc: rd only
    insn_i = mk_insn(7'h00, 5'd0, 5'd0, 3'b000, 5'd12, 7'b0010111);
    pc_i   = 32'h0000_0028;
    #1;
    check_decode("AUIPC (rd only)", insn_i, pc_i, 7'b0010111, 5'd12, 5'd0, 5'd0, 3'b000, 7'h00, 5'd0, 32'h0);

    $display("done. decode looks good.");
    $finish;
  end

endmodule