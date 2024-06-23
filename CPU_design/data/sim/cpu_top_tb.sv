//////////////////////////////////////////////////////////////////////////////
// Description: CPU testbench

`default_nettype none  // turn off implicit data types

`begin_keywords "1800-2012"

`define display_err(message)  $display("%m [ERROR]   %t %s %d: %s", $realtime, `__FILE__, `__LINE__, message)
`define display_warn(message) $display("%m [WARNING] %t %s %d: %s", $realtime, `__FILE__, `__LINE__, message)
`define display_info(message) $display("%m [INFO]    %t %s %d: %s", $realtime, `__FILE__, `__LINE__, message)

`ifndef RD_SEED
  `define RD_SEED 1
`endif

`define TOP cpu_top_tb

module cpu_top_tb;
  timeunit 1ps;
  timeprecision 1ps;
  import cpu_pkg::*;

  //--------------------------------------------------------------------------//
  //   L o c a l    P a r a m e t e r s
  //--------------------------------------------------------------------------//
  localparam pMEM_DEPTH = 2**pDATA_WIDTH;

  //--------------------------------------------------------------------------//
  //   V a r i a b l e    D e c l a r a t i o n s
  //--------------------------------------------------------------------------//
  string message;
  int seed;

  logic rclk;
  logic rrst_n;
  logic ren;

  //--------------------------------------------------------------------------//
  //   F u n c t i o n a l    L o g i c
  //--------------------------------------------------------------------------//
  parameter CLK_DELAY = 125;
  parameter CLK_WIDTH = 250;
  parameter CLK_PERIOD = 500;
  always begin
    #(CLK_DELAY) rclk = 1'b1;
    #(CLK_WIDTH) rclk = 1'b0;
    #(CLK_PERIOD-CLK_DELAY-CLK_WIDTH);
  end

  initial begin : init_PROC
    // Seed to create truly random
    // May need to force to a fixed value for debuging purpose
    seed = int'(`RD_SEED);
    $sformat(message, "Run seed: %d", seed);
    `display_info(message);

    rrst_n = '0;
    ren = '0;

    #(5*CLK_PERIOD) rrst_n = '1;
    #(100000*CLK_PERIOD) $finish;
  end : init_PROC

  cpu_top u_dut (
      .iclk  ( rclk   )
    , .irst_n( rrst_n )
    , .ien   ( ren    )
  );

  task tsk_force_mem;
    int db_idx;
    int fd;
    logic [pMEM_DEPTH-1:0][pDATA_WIDTH-1:0] memory;
    string line;
    fd = $fopen(`INSTRUCTION_DB_FILE, "r");
    if (!fd) begin
      $display("%m - [ERROR] Can't open the delay db file: %s",`INSTRUCTION_DB_FILE);
      $finish;
    end

    // Read database
    db_idx = 0;
    memory = '0;
    while (!$feof(fd)) begin
      $fgets(line, fd);
      if (line=="") begin
        break;
      end
      memory[db_idx] = line.atohex();
//      $display("%t %d %h", $realtime, db_idx, memory[db_idx]);
      db_idx = db_idx+1;
    end
    force u_dut.u_mem.rmemory_array = memory;
    release u_dut.u_mem.rmemory_array;
    $fclose(fd);

  endtask : tsk_force_mem

endmodule : cpu_top_tb

`end_keywords

`default_nettype wire  // restore implicit data types
