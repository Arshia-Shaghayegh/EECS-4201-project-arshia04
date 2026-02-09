/*
 * Module: decode
 *
 * Description: Decode stage
 *
 * Inputs:
 * 1) clk
 * 2) rst signal
 * 3) insn_iruction ins_i
 * 4) program counter pc_i
 * Outputs:
 * 1) AWIDTH wide program counter pc_o
 * 2) DWIDTH wide insn_iruction output insn_o
 * 3) 5-bit wide destination register ID rd_o
 * 4) 5-bit wide source 1 register ID rs1_o
 * 5) 5-bit wide source 2 register ID rs2_o
 * 6) 7-bit wide funct7 funct7_o
 * 7) 3-bit wide funct3 funct3_o
 * 8) 32-bit wide immediate imm_o
 * 9) 5-bit wide shift amount shamt_o
 * 10) 7-bit width opcode_o
 */

`include "constants.svh"

module decode #(
    parameter int DWIDTH=32,
    parameter int AWIDTH=32
)(
	// inputs
	input logic clk,
	input logic rst,
	input logic [DWIDTH - 1:0] insn_i,
	input logic [DWIDTH - 1:0] pc_i,

    // outputs
    output logic [AWIDTH-1:0] pc_o,
    output logic [DWIDTH-1:0] insn_o,
    output logic [6:0] opcode_o,
    output logic [4:0] rd_o,
    output logic [4:0] rs1_o,
    output logic [4:0] rs2_o,
    output logic [6:0] funct7_o,
    output logic [2:0] funct3_o,
    output logic [4:0] shamt_o,
    output logic [DWIDTH-1:0] imm_o
);	

    /*
     * Process definitions to be filled by
     * student below...
     */

    // internal decoded fields
    logic [6:0] opcode;
    logic [4:0] rd, rs1, rs2, shamt;
    logic [2:0] funct3;
    logic [6:0] funct7;

    // pass-through probes (decode is combinational for now)
    assign insn_o   = insn_i;
    assign pc_o     = pc_i;

    // opcode is always the same bits
    assign opcode   = insn_i[6:0];
    assign opcode_o = opcode;

    // drive outputs from internal regs
    assign rd_o     = rd;
    assign rs1_o    = rs1;
    assign rs2_o    = rs2;
    assign funct3_o = funct3;
    assign funct7_o = funct7;
    assign shamt_o  = shamt;

    // per your project note: imm comes from igen, so decode's imm_o is dummy for now
    assign imm_o = '0;

    // decode
    always_comb begin
        // safe defaults
        rd    = '0;
        rs1   = '0;
        rs2   = '0;
        funct3= '0;
        funct7= '0;
        shamt = '0;

        // optional: on reset just zero everything (even though combinational)
        if (rst) begin
            rd    = '0;
            rs1   = '0;
            rs2   = '0;
            funct3= '0;
            funct7= '0;
            shamt = '0;
        end else begin
            unique case (opcode)

                // r-type (0110011): rd, rs1, rs2, funct3, funct7
                7'b011_0011: begin
                    rd     = insn_i[11:7];
                    funct3 = insn_i[14:12];
                    rs1    = insn_i[19:15];
                    rs2    = insn_i[24:20];
                    funct7 = insn_i[31:25];
                end

                // i-type alu (0010011): rd, rs1, funct3, imm in igen
                // shifts are special: shamt + funct7 matter
                7'b001_0011: begin
                    rd     = insn_i[11:7];
                    funct3 = insn_i[14:12];
                    rs1    = insn_i[19:15];

                    if (funct3 == 3'b001 || funct3 == 3'b101) begin
                        shamt  = insn_i[24:20];
                        funct7 = insn_i[31:25]; // distinguishes srli vs srai, etc.
                    end
                end

                // loads (0000011): rd, rs1, funct3
                7'b000_0011: begin
                    rd     = insn_i[11:7];
                    funct3 = insn_i[14:12];
                    rs1    = insn_i[19:15];
                end

                // stores (0100011): rs1, rs2, funct3 (no rd)
                7'b010_0011: begin
                    funct3 = insn_i[14:12];
                    rs1    = insn_i[19:15];
                    rs2    = insn_i[24:20];
                end

                // branches (1100011): rs1, rs2, funct3 (no rd)
                7'b110_0011: begin
                    funct3 = insn_i[14:12];
                    rs1    = insn_i[19:15];
                    rs2    = insn_i[24:20];
                end

                // jal (1101111): rd only
                7'b110_1111: begin
                    rd = insn_i[11:7];
                end

                // jalr (1100111): rd + rs1 (funct3 is fixed 000 in spec, we zero it)
                7'b110_0111: begin
                    rd  = insn_i[11:7];
                    rs1 = insn_i[19:15];
                end

                // lui (0110111): rd only
                7'b011_0111: begin
                    rd = insn_i[11:7];
                end

                // auipc (0010111): rd only
                7'b001_0111: begin
                    rd = insn_i[11:7];
                end

                default: begin
                    // leave defaults (all zeros)
                end
            endcase
        end
    end


endmodule : decode
