`timescale 1ns/1ps
`ifndef MEM_DEPTH
  `define MEM_DEPTH 65535
`endif

// memory_tb.sv
// ok so this is the tb for my memory.sv
//
// what im testing here:
// - address coming in is a full system address (base + offset)
// - inside memory.sv i do: address = addr_i - BASE_ADDR
// - memory is byte-addressable, but i read/write 32-bit words using addr, addr+1, addr+2, addr+3
// - write happens on posedge when write_en_i=1
// - read is combinational when read_en_i=1 (so no “1-cycle latency” stuff)
//
// so in the tb:
// - reset
// - write a word, then read it back (read is instant-ish so i just wait #1)
// - write/read a bunch sequentially
// - back-to-back write then read same address
// - boundary: first word and last safe word start (mem_depth is bytes so last start is mem_depth-3)
// - read+write both high: after posedge i should see the new data (because write happened)

module memory_tb;

  localparam int AWIDTH = 32;
  localparam int DWIDTH = 32;
  localparam logic [31:0] BASE_ADDR = 32'h0100_0000;
  localparam int CLK_PERIOD = 20; // 50MHz

  logic clk, rst;
  logic read_en, write_en;
  logic [AWIDTH-1:0] addr;
  logic [DWIDTH-1:0] data_in;
  logic [DWIDTH-1:0] data_out;
  logic data_vld;

  memory #(
    .AWIDTH(AWIDTH),
    .DWIDTH(DWIDTH),
    .BASE_ADDR(BASE_ADDR)
  ) dut (
    .clk        (clk),
    .rst        (rst),
    .addr_i     (addr),
    .data_i     (data_in),
    .read_en_i  (read_en),
    .write_en_i (write_en),
    .data_o     (data_out),
    .data_vld_o (data_vld)
  );

  // clock
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  task automatic do_reset;
    rst      = 1;
    read_en  = 0;
    write_en = 0;
    addr     = BASE_ADDR;
    data_in  = '0;
    repeat (2) @(posedge clk);
    rst = 0;
    @(posedge clk);
    $display("reset done");
  endtask

  // write a 32-bit word at a byte offset
  // (offset should be word-aligned and also <= MEM_DEPTH-3)
  task automatic write_word(input int unsigned offset, input logic [31:0] wdata);
    @(posedge clk);
    addr     <= BASE_ADDR + offset;
    data_in  <= wdata;
    write_en <= 1;
    read_en  <= 0;
    @(posedge clk);
    write_en <= 0;
  endtask

  // read is combinational, so i just wait #1 and check
  task automatic read_and_check(
    input string name,
    input int unsigned offset,
    input logic [31:0] exp
  );
    addr     <= BASE_ADDR + offset;
    read_en  <= 1;
    write_en <= 0;
    #1;

    if (data_out !== exp) begin
      $error("%s: mismatch offset=0x%0h addr=0x%0h exp=0x%08h got=0x%08h",
             name, offset, (BASE_ADDR + offset), exp, data_out);
    end else begin
      $display("pass: %s  offset=0x%0h data=0x%08h", name, offset, data_out);
    end

    read_en <= 0;
    #1;
  endtask

  initial begin
    $display("---- memory_tb start ----");
    do_reset();

    // 1) basic write then read
    write_word(32'h0000_00A0, 32'hDEAD_BEEF);
    read_and_check("basic w/r", 32'h0000_00A0, 32'hDEAD_BEEF);

    // 2) sequential words
    for (int i = 0; i < 16; i++) begin
      write_word(i*4, 32'(i*4));
    end
    for (int i = 0; i < 16; i++) begin
      read_and_check($sformatf("seq[%0d]", i), i*4, 32'(i*4));
    end

    // 3) back-to-back write then read same addr
    @(posedge clk);
    addr     <= BASE_ADDR + 32'h0000_00F0;
    data_in  <= 32'h1234_5678;
    write_en <= 1;
    read_en  <= 0;

    @(posedge clk);
    write_en <= 0;
    read_en  <= 1;
    #1;

    if (data_out !== 32'h1234_5678) $error("back-to-back failed exp=0x12345678 got=0x%08h", data_out);
    else $display("pass: back-to-back");

    read_en <= 0;

    // 4) boundary test
    // mem_depth is bytes, so last safe word starts at (MEM_DEPTH - 3)
    write_word(0, 32'hCAFE_F00D);
    write_word(`MEM_DEPTH-3, 32'hBEEF_FACE);
    read_and_check("boundary first", 0, 32'hCAFE_F00D);
    read_and_check("boundary last", `MEM_DEPTH-3, 32'hBEEF_FACE);

    // 5) read+write both high
    // after posedge the write happened, and since read is comb, it should show the new value
    write_word(32'h0000_00CC, 32'h1111_1111); // preload something
    addr     <= BASE_ADDR + 32'h0000_00CC;
    data_in  <= 32'hABAD_BABE;
    read_en  <= 1;
    write_en <= 1;

    @(posedge clk);
    #1;

    if (data_out !== 32'hABAD_BABE) $error("simul r/w failed exp=0xABADBABE got=0x%08h", data_out);
    else $display("pass: simul r/w");

    read_en  <= 0;
    write_en <= 0;

    $display("---- memory_tb done ----");
    $finish;
  end

endmodule