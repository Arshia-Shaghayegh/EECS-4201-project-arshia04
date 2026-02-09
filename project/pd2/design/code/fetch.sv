/*
 * Module: fetch
 *
 * Description: Fetch stage
 *
 * -------- REPLACE THIS FILE WITH THE MEMORY MODULE DEVELOPED IN PD1 -----------
 *
 * Inputs:
 * 1) clk
 * 2) rst signal
 *
 * Outputs:
 * 1) AWIDTH wide program counter pc_o
 * 2) DWIDTH wide instruction output insn_o
 */

module fetch #(
    parameter int DWIDTH=32,
    parameter int AWIDTH=32,
    parameter int BASEADDR=32'h01000000
    )(
	// inputs
	input logic clk,
	input logic rst,
	// outputs	
	output logic [AWIDTH - 1:0] pc_o,
    output logic [DWIDTH - 1:0] insn_o
);
/*
     * Process definitions to be filled by
     * student below...
     */

    // Program counter register
    logic [AWIDTH - 1:0] pc_q = BASEADDR;

    // Next-state logic and instruction placeholder
    always_comb begin
        pc_o   = pc_q;
        /*insn_o = '0; // replace with memory data once wired*/
        // insn_o comes from memory instance below
    end

    // PC update
    always_ff @(posedge clk) begin
        if (rst) begin
            pc_q <= BASEADDR;
        end
        else begin
            pc_q <= pc_q + 32'd4;
        end
    end
    // Instruction memory (read-only in fetch)
    memory #(
        .AWIDTH(AWIDTH),
        .DWIDTH(DWIDTH),
        .BASE_ADDR(BASEADDR)
    ) insn_mem (
        .clk       (clk),
        .rst       (rst),
        .addr_i    (pc_q),     // pc_q already holds BASEADDR-based address
        .data_i    ('0),
        .read_en_i (1'b1),
        .write_en_i(1'b0),
        .data_o    (insn_o),
        .data_vld_o()          // ignore valid for now
    );

endmodule : fetch

