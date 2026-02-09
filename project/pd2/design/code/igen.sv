/*
 * Module: igen
 *
 * Description: Immediate value generator
 *
 * Inputs:
 * 1) opcode opcode_i
 * 2) input instruction insn_i
 * Outputs:
 * 2) 32-bit immediate value imm_o
 */

module igen #(
    parameter int DWIDTH=32
    )(
    input logic [6:0] opcode_i,
    input logic [DWIDTH-1:0] insn_i,
    output logic [31:0] imm_o
);
    /*
     * Process definitions to be filled by
     * student below...
     */

    // ok so imm_o is just the thing we compute here
    logic [DWIDTH-1:0] imm_reg;
    logic [2:0] funct3;

    assign funct3 = insn_i[14:12];
    assign imm_o  = imm_reg;

    function automatic logic [DWIDTH-1:0] imm_i_sext(input logic [DWIDTH-1:0] insn);
        // normal i-type (12-bit) sign extended
        return {{DWIDTH-12{insn[31]}}, insn[31:20]};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_s_sext(input logic [DWIDTH-1:0] insn);
        // store immediate is split, so we stitch it
        return {{DWIDTH-12{insn[31]}}, insn[31:25], insn[11:7]};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_b_sext(input logic [DWIDTH-1:0] insn);
        // branch is shuffled + ends with 0
        return {{DWIDTH-13{insn[31]}}, insn[31], insn[7], insn[30:25], insn[11:8], 1'b0};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_j_sext(input logic [DWIDTH-1:0] insn);
        // jal is also shuffled + ends with 0
        return {{DWIDTH-21{insn[31]}}, insn[31], insn[19:12], insn[20], insn[30:21], 1'b0};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_u(input logic [DWIDTH-1:0] insn);
        // u-type is upper 20 then 12 zeros
        return {insn[31:12], 12'b0};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_shift_zext(input logic [DWIDTH-1:0] insn);
        // for shifts we keep your idea: zero-extend the immediate chunk
        return {{DWIDTH-12{1'b0}}, insn[31:20]};
    endfunction

    always_comb begin : immgen
        imm_reg = 'd0;

        case (opcode_i)

            // jal (j-type)
            7'b110_1111: begin
                imm_reg = imm_j_sext(insn_i);
            end

            // stores (s-type)
            7'b010_0011: begin
                imm_reg = imm_s_sext(insn_i);
            end

            // lui / auipc (u-type)
            7'b011_0111,
            7'b001_0111: begin
                imm_reg = imm_u(insn_i);
            end

            // i-type alu ops
            7'b001_0011: begin
                case (funct3)
                    // addi, xori, ori, andi
                    3'h0, 3'h4, 3'h6, 3'h7: begin
                        imm_reg = imm_i_sext(insn_i);
                    end

                    // slli
                    3'h1: begin
                        if (insn_i[31:25] == 7'h00) imm_reg = imm_shift_zext(insn_i);
                        else                        imm_reg = 'd0;
                    end

                    // srli / srai
                    3'h5: begin
                        if ((insn_i[31:25] == 7'h00) || (insn_i[31:25] == 7'h20)) imm_reg = imm_shift_zext(insn_i);
                        else                                                         imm_reg = 'd0;
                    end

                    // slti / sltiu
                    3'h2, 3'h3: begin
                        imm_reg = imm_i_sext(insn_i);
                    end

                    default: begin
                        imm_reg = 'd0;
                    end
                endcase
            end

            // branches (b-type)
            7'b110_0011: begin
                imm_reg = imm_b_sext(insn_i);
            end

            // jalr (i-type)
            7'b110_0111: begin
                imm_reg = imm_i_sext(insn_i);
            end

            // loads (i-type)
            7'b000_0011: begin
                imm_reg = imm_i_sext(insn_i);
            end

            // r-type (no imm)
            7'b011_0011: begin
                imm_reg = 'd0;
            end

            default: begin
                imm_reg = 'd0;
            end
        endcase
    end

endmodule : igen
