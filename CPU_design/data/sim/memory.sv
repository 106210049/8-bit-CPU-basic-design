//////////////////////////////////////////////////////////////////////////////
// Description: Verify memory by writing into the array then read data out

`define MEMORY `TOP.u_dut.u_mem

module vector;
  timeunit 1ps;
  timeprecision 1ps;
  import cpu_pkg::*;

  localparam pRAND_NO = 16;

  string message;
  int error;

  int rand_idx;
  class packet;
    randc bit [pADDR_WIDTH-1:0] addr;
    rand  bit [pDATA_WIDTH-1:0] data; 
  endclass
  packet pkt;
  typedef struct {
    bit [pADDR_WIDTH-1:0] addr;
    bit [pDATA_WIDTH-1:0] data; 
  } rand_mem_t;
  rand_mem_t rand_mem_a [];

  initial begin
    pkt = new();
    rand_mem_a = new[pRAND_NO];
    error = 0;
    #(10*`TOP.CLK_PERIOD)

    // Randomize value & write into memory
    pkt.srandom(`TOP.seed);
    for (rand_idx=0;rand_idx<pRAND_NO;rand_idx=rand_idx+1) begin
      pkt.randomize();
      rand_mem_a[rand_idx].addr = pkt.addr;
      rand_mem_a[rand_idx].data = pkt.data;
      mem_write(
         .addr(rand_mem_a[rand_idx].addr)
        ,.data(rand_mem_a[rand_idx].data)
      );
    end
    for (rand_idx=0;rand_idx<pRAND_NO;rand_idx=rand_idx+1) begin
      mem_read(
         .addr(rand_mem_a[rand_idx].addr)
        ,.data(rand_mem_a[rand_idx].data)
      );
    end

    if (error==0) begin
      `display_info("Test PASSED");
    end else begin
      $sformat(message, "Test FAILED with %d error(s)", error);
      `display_err(message);
    end

    #(10*`TOP.CLK_PERIOD) $finish;
  end

  task mem_write (
      logic [pADDR_WIDTH-1:0] addr
    , logic [pDATA_WIDTH-1:0] data
  );
    @(posedge `TOP.rclk)
    #(`TOP.CLK_PERIOD-`TOP.CLK_DELAY)
    force `MEMORY.idata = addr;
    force `MEMORY.iaen  = 1'b1;
    #(`TOP.CLK_PERIOD)
    release `MEMORY.iaen;
    force `MEMORY.idata = data;
    force `MEMORY.iden  = 1'b1;
    #(`TOP.CLK_PERIOD)
    release `MEMORY.iden;
    release `MEMORY.idata;

    $sformat(message, "write memory %b. Address %d", data, addr);
    `display_info(message);
  endtask : mem_write

  task mem_read (
      logic [pADDR_WIDTH-1:0] addr
    , logic [pDATA_WIDTH-1:0] data
  );
    @(posedge `TOP.rclk)
    #(`TOP.CLK_PERIOD-`TOP.CLK_DELAY)
    force `MEMORY.idata = addr;
    force `MEMORY.iaen  = 1'b1;
    #(`TOP.CLK_PERIOD)
    release `MEMORY.iaen;
    release `MEMORY.idata;

    if (`MEMORY.odata!==data) begin
      $sformat(message, "wrong memory out. Expected: %b data %b. Address %d", data, `MEMORY.odata, addr);
      `display_err(message);
      error = error+1;
    end else begin
      $sformat(message, "sucess read memory %b. Address %d", data, addr);
      `display_info(message);
    end
  endtask : mem_read
endmodule
