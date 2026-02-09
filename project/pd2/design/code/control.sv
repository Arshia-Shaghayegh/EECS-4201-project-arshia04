/*
 * Module: control
 *
 * Description: This module sets the control bits (control path) based on the decoded
 * instruction. Note that this is part of the decode stage but housed in a separate
 * module for better readability, debug and design purposes.
 *
 * Inputs:
 * 1) DWIDTH instruction ins_i
 * 2) 7-bit opcode opcode_i
 * 3) 7-bit funct7 funct7_i
 * 4) 3-bit funct3 funct3_i
 *
 * Outputs:
 * 1) 1-bit PC select pcsel_o
 * 2) 1-bit Immediate select immsel_o
 * 3) 1-bit register write en regwren_o
 * 4) 1-bit rs1 select rs1sel_o
 * 5) 1-bit rs2 select rs2sel_o
 * 6) k-bit ALU select alusel_o
 * 7) 1-bit memory read en memren_o
 * 8) 1-bit memory write en memwren_o
 * 9) 2-bit writeback sel wbsel_o
 */

`include "constants.svh"

module control #(
	parameter int DWIDTH=32
)(
	// inputs
    input logic [DWIDTH-1:0] insn_i,
    input logic [6:0] opcode_i,
    input logic [6:0] funct7_i,
    input logic [2:0] funct3_i,

    // outputs
    output logic pcsel_o,
    output logic immsel_o,
    output logic regwren_o,
    output logic rs1sel_o,
    output logic rs2sel_o,
    output logic memren_o,
    output logic memwren_o,
    output logic [1:0] wbsel_o,
    output logic [3:0] alusel_o
);

    /*
     * Process definitions to be filled by
     * student below...
     */

    // opcodes (rv32i)
    localparam logic [6:0] OPC_RTYPE  = 7'b011_0011;
    localparam logic [6:0] OPC_ITYPE  = 7'b001_0011;
    localparam logic [6:0] OPC_LOAD   = 7'b000_0011;
    localparam logic [6:0] OPC_STORE  = 7'b010_0011;
    localparam logic [6:0] OPC_BRANCH = 7'b110_0011;
    localparam logic [6:0] OPC_JAL    = 7'b110_1111;
    localparam logic [6:0] OPC_JALR   = 7'b110_0111;
    localparam logic [6:0] OPC_LUI    = 7'b011_0111;
    localparam logic [6:0] OPC_AUIPC  = 7'b001_0111;

    // writeback select (tweak later if your datapath uses different encoding)
    // 00 off, 01 alu, 10 mem, 11 pc+4
    localparam logic [1:0] WB_OFF = 2'b00;
    localparam logic [1:0] WB_ALU = 2'b01;
    localparam logic [1:0] WB_MEM = 2'b10;
    localparam logic [1:0] WB_PC4 = 2'b11;

    // alu select (same deal: match your alu to these later)
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

    // funct7 patterns used for the "alt" versions (sub / sra / srai)
    localparam logic [6:0] FUNCT7_STD = 7'h00;
    localparam logic [6:0] FUNCT7_ALT = 7'h20;

    always_comb begin : control_comb
        // default = safest "do nothing" state
        // if something is unknown, we’d rather do nothing than write memory by accident lol
        pcsel_o   = 1'b0;     // 0 means pc+4
        immsel_o  = 1'b0;     // 1 means we care about an immediate this instruction
        regwren_o = 1'b0;
        rs1sel_o  = 1'b0;     // 0 = rs1, 1 = pc (for stuff like auipc/jal target calc)
        rs2sel_o  = 1'b0;     // 0 = rs2, 1 = imm
        memren_o  = 1'b0;
        memwren_o = 1'b0;
        wbsel_o   = WB_OFF;
        alusel_o  = ALU_ADD;

        unique case (opcode_i)

            // r-type: rd = rs1 op rs2
            OPC_RTYPE: begin
                regwren_o = 1'b1;
                wbsel_o   = WB_ALU;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                immsel_o  = 1'b0;

                unique case (funct3_i)
                    3'h0: begin
                        if      (funct7_i == FUNCT7_STD) alusel_o = ALU_ADD; // add
                        else if (funct7_i == FUNCT7_ALT) alusel_o = ALU_SUB; // sub
                        else                              alusel_o = ALU_ADD;
                    end
                    3'h1: alusel_o = ALU_SLL;
                    3'h2: alusel_o = ALU_SLT;
                    3'h3: alusel_o = ALU_SLTU;
                    3'h4: alusel_o = ALU_XOR;
                    3'h5: begin
                        if      (funct7_i == FUNCT7_STD) alusel_o = ALU_SRL; // srl
                        else if (funct7_i == FUNCT7_ALT) alusel_o = ALU_SRA; // sra
                        else                              alusel_o = ALU_SRL;
                    end
                    3'h6: alusel_o = ALU_OR;
                    3'h7: alusel_o = ALU_AND;
                    default: alusel_o = ALU_ADD;
                endcase
            end

            // i-type alu: rd = rs1 op imm
            OPC_ITYPE: begin
                regwren_o = 1'b1;
                wbsel_o   = WB_ALU;

                immsel_o  = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b1;

                unique case (funct3_i)
                    3'h0: alusel_o = ALU_ADD;   // addi
                    3'h2: alusel_o = ALU_SLT;   // slti
                    3'h3: alusel_o = ALU_SLTU;  // sltiu
                    3'h4: alusel_o = ALU_XOR;   // xori
                    3'h6: alusel_o = ALU_OR;    // ori
                    3'h7: alusel_o = ALU_AND;   // andi
                    3'h1: alusel_o = ALU_SLL;   // slli (funct7 should be 0)
                    3'h5: begin                 // srli / srai decided by the high bits
                        if      (insn_i[31:25] == FUNCT7_STD) alusel_o = ALU_SRL;
                        else if (insn_i[31:25] == FUNCT7_ALT) alusel_o = ALU_SRA;
                        else                                   alusel_o = ALU_SRL;
                    end
                    default: alusel_o = ALU_ADD;
                endcase
            end

            // load: rd = mem[rs1 + imm]
            OPC_LOAD: begin
                regwren_o = 1'b1;
                wbsel_o   = WB_MEM;

                immsel_o  = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b1;

                memren_o  = 1'b1;
                alusel_o  = ALU_ADD; // address calc
            end

            // store: mem[rs1 + imm] = rs2
            OPC_STORE: begin
                regwren_o = 1'b0;
                wbsel_o   = WB_OFF;

                immsel_o  = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b1;

                memwren_o = 1'b1;
                alusel_o  = ALU_ADD; // address calc
            end

            // branch: we are not doing taken/not-taken yet
            // so for now do not force pcsel high (otherwise every branch becomes "always taken")
            // later we’ll change pcsel_o to something like (is_branch & branch_taken)
            OPC_BRANCH: begin
                regwren_o = 1'b0;
                wbsel_o   = WB_OFF;

                immsel_o  = 1'b1;

                // these are still useful for computing pc+imm when we get to branches
                rs1sel_o  = 1'b1;   // use pc as operand a
                rs2sel_o  = 1'b1;   // use imm as operand b
                alusel_o  = ALU_ADD;

                pcsel_o   = 1'b0;   // important: keep it 0 for now
            end

            // jal: rd = pc+4 ; pc = pc + imm
            OPC_JAL: begin
                regwren_o = 1'b1;
                wbsel_o   = WB_PC4;

                immsel_o  = 1'b1;
                rs1sel_o  = 1'b1;   // pc
                rs2sel_o  = 1'b1;   // imm
                alusel_o  = ALU_ADD;

                pcsel_o   = 1'b1;   // jump always redirects pc
            end

            // jalr: rd = pc+4 ; pc = rs1 + imm
            OPC_JALR: begin
                regwren_o = 1'b1;
                wbsel_o   = WB_PC4;

                immsel_o  = 1'b1;
                rs1sel_o  = 1'b0;   // rs1
                rs2sel_o  = 1'b1;   // imm
                alusel_o  = ALU_ADD;

                pcsel_o   = 1'b1;   // jalr always redirects pc
            end

            // lui: rd = imm<<12
            // typical trick: set rs1=x0 in decode so alu does 0 + imm
            OPC_LUI: begin
                regwren_o = 1'b1;
                wbsel_o   = WB_ALU;

                immsel_o  = 1'b1;
                rs1sel_o  = 1'b0;   // decode should make rs1 = x0 for lui
                rs2sel_o  = 1'b1;
                alusel_o  = ALU_ADD;

                pcsel_o   = 1'b0;
            end

            // auipc: rd = pc + (imm<<12)
            OPC_AUIPC: begin
                regwren_o = 1'b1;
                wbsel_o   = WB_ALU;

                immsel_o  = 1'b1;
                rs1sel_o  = 1'b1;   // pc
                rs2sel_o  = 1'b1;   // imm
                alusel_o  = ALU_ADD;

                pcsel_o   = 1'b0;   // pc still just goes +4 normally
            end

            default: begin
                // keep defaults
            end
        endcase
    end

endmodule : control
