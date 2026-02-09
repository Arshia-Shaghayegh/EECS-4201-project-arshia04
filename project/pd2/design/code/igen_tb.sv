`timescale 1ns/1ps

// igen_tb.sv
// unit test for igen.sv (pd2)
//
// igen inputs: opcode_i, insn_i
// igen output: imm_o
//
// we just poke opcode + insn, wait #1, and check imm_o

module igen_tb;

  localparam int DWIDTH = 32;

  logic [6:0]        opcode_i;
  logic [DWIDTH-1:0] insn_i;
  logic [31:0]       imm_o;

  igen #(.DWIDTH(DWIDTH)) dut (
    .opcode_i(opcode_i),
    .insn_i  (insn_i),
    .imm_o   (imm_o)
  );

  // helper to build {funct7, rs2, rs1, funct3, rd, opcode}
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

  task automatic check_imm(
    input string name,
    input logic [6:0]  exp_opcode,
    input logic [31:0] exp_insn,
    input logic [31:0] exp_imm
  );
    opcode_i = exp_opcode;
    insn_i   = exp_insn;
    #1;

    if (imm_o !== exp_imm) begin
      $error("%s: imm mismatch. opcode=%b insn=%h exp=%h got=%h",
             name, exp_opcode, exp_insn, exp_imm, imm_o);
    end else begin
      $display("pass: %s", name);
    end
  endtask

  initial begin
    opcode_i = '0;
    insn_i   = '0;
    #1;

    // i-type addi +10
    check_imm("addi +10",
      7'b0010011,
      32'b000000001010_00010_000_00001_0010011,
      32'd10
    );

    // i-type addi -4 (0xffc sign-extended)
    check_imm("addi -4",
      7'b0010011,
      32'b111111111100_00010_000_00001_0010011,
      32'hffff_fffc
    );

    // loads are i-type immediates too
    check_imm("lw +8",
      7'b0000011,
      32'b000000001000_00001_010_00011_0000011,
      32'd8
    );

    // jalr is i-type immediate too
    check_imm("jalr -16",
      7'b1100111,
      32'b111111110000_00101_000_00001_1100111,
      32'hffff_fff0
    );

    // s-type store imm
    check_imm("sw +8",
      7'b0100011,
      32'b0000000_00101_00110_010_01000_0100011,
      32'd8
    );

    // b-type beq +16
    // note: branch imm has a 0 at bit0, so +16 is a clean test
    check_imm("beq +16",
      7'b1100011,
      32'h0020_8863,
      32'd16
    );

    // b-type beq -16
    check_imm("beq -16",
      7'b1100011,
      32'hFE20_88E3,
      32'hffff_fff0
    );

    // u-type lui
    check_imm("lui 0x12345",
      7'b0110111,
      32'b00010010001101000101_01010_0110111,
      32'h1234_5000
    );

    // u-type auipc
    check_imm("auipc 0xabcde",
      7'b0010111,
      {20'habcde, 5'd3, 7'b0010111},
      32'habcde_000
    );

    // j-type jal +16
    check_imm("jal +16",
      7'b1101111,
      32'h0100_00EF,
      32'd16
    );

    // j-type jal -16
    check_imm("jal -16",
      7'b1101111,
      32'hFF1F_F0EF,
      32'hffff_fff0
    );

    // shifts: your igen zero-extends insn[31:20] (12-bit chunk)
    check_imm("slli shamt=3",
      7'b0010011,
      mk_insn(7'h00, 5'd3, 5'd5, 3'b001, 5'd4, 7'b0010011),
      32'h0000_0003
    );

    check_imm("srli shamt=7",
      7'b0010011,
      mk_insn(7'h00, 5'd7, 5'd5, 3'b101, 5'd4, 7'b0010011),
      32'h0000_0007
    );

    // for srai, insn[31:20] = {7'h20, shamt} so it becomes 12'h407
    check_imm("srai shamt=7",
      7'b0010011,
      mk_insn(7'h20, 5'd7, 5'd5, 3'b101, 5'd4, 7'b0010011),
      32'h0000_0407
    );

    $display("done. igen looks good.");
    $finish;
  end

endmodule