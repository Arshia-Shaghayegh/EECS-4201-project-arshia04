/*
 * -------- REPLACE THIS FILE WITH THE MEMORY MODULE DEVELOPED IN PD1 -----------
 * Module: memory
 *
 * Description: Byte-addressable memory implementation. Supports both read and write.
 *
 * Inputs:
 * 1) clk
 * 2) rst signal
 * 3) AWIDTH address addr_i
 * 4) DWIDTH data to write data_i
 * 5) read enable signal read_en_i
 * 6) write enable signal write_en_i
 *
 * Outputs:
 * 1) DWIDTH data output data_o
 * 2) data out valid signal data_vld_o
 */

`define MEM_DEPTH 65535     // 64 KB byte-addressable memory
`define LINE_COUNT 4096     // max number of 32-bit words to preload
`define MEM_PATH "program.hex"


module memory #(
  // parameters
  parameter int AWIDTH = 32,
  parameter int DWIDTH = 32,
  parameter logic [31:0] BASE_ADDR = 32'h01000000
) (
  // inputs
  input logic clk,
  input logic rst,
  input logic [AWIDTH-1:0] addr_i = BASE_ADDR,
  input logic [DWIDTH-1:0] data_i,
  input logic read_en_i,
  input logic write_en_i,
  // outputs
  output logic [DWIDTH-1:0] data_o,
  output logic data_vld_o
);

  logic [DWIDTH-1:0] temp_memory [0:`MEM_DEPTH];
  // Byte-addressable memory
  logic [7:0] main_memory [0:`MEM_DEPTH];  // Byte-addressable memory
  logic [AWIDTH-1:0] address;
  assign address = addr_i - BASE_ADDR;
  // data is valid whenever a read is requested (combinational read)
  always_comb begin
    if (rst) data_vld_o = 1'b0;
    else     data_vld_o = read_en_i;
  end

  initial begin
    $readmemh(`MEM_PATH, temp_memory);
    // Load data from temp_memory into main_memory
    for (int i = 0; i < `LINE_COUNT; i++) begin
      main_memory[4*i]     = temp_memory[i][7:0];
      main_memory[4*i + 1] = temp_memory[i][15:8];
      main_memory[4*i + 2] = temp_memory[i][23:16];
      main_memory[4*i + 3] = temp_memory[i][31:24];
    end
    $display("IMEMORY: Loaded %0d 32-bit words from %s", `LINE_COUNT, `MEM_PATH);
  end

  // Read logic
  always_comb begin
    if (read_en_i) begin
      data_o = {main_memory[address + 3], main_memory[address + 2],
                main_memory[address + 1], main_memory[address]};
    end
    else begin
      data_o = '0;
    end
  end

  // Write logic
  always @(posedge clk) begin
    if (write_en_i) begin
      main_memory[address] <= data_i[7:0];
      main_memory[address + 1] <= data_i[15:8];
      main_memory[address + 2] <= data_i[23:16];
      main_memory[address + 3] <= data_i[31:24];
    end
  end
endmodule : memory
