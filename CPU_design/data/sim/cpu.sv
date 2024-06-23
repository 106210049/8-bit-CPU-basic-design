//////////////////////////////////////////////////////////////////////////////
// Description: Verify memory by writing into the array then read data out

`define CPU `TOP.u_dut.u_cpu

module vector;
  timeunit 1ps;
  timeprecision 1ps;
  import cpu_pkg::*;

  string message;
  int error;

  struct_alu_flag_t flag_sts;

  // Command table
  // CMD   Length [7:3]   RA RB
  // ADD   1      1 0 0 0 RA  RB  ADD RA and RB then put result into RB
  // SHR   1      1 0 0 1 RA  RB  SHIFT RA LEFT them put result into RB
  // SHL   1      1 0 1 0 RA  RB  SHIFT RA RIGHT them put result into RB
  // NOT   1      1 0 1 1 RA  RB  NOT RA then put result into RB
  // AND   1      1 1 0 0 RA  RB  AND RA with RB then put result into RB
  // OR    1      1 1 0 1 RA  RB  OR RA with RB then put result into RB
  // XOR   1      1 1 1 0 RA  RB  XOR RA with RB then put result into RB
  // CMP   1      1 1 1 1 RA  RB  COMPARE RA with RB
  // LD    1      0 0 0 0 RA  RB  LOAD from RAM address in RA to register RB
  // ST    1      0 0 0 1 RA  RB  STORE RB to RAM address in RA
  // DATA  2      0 0 1 0 NA  RB  LOAD 8 bits in next address into RB
  // JMPR  1      0 0 1 1 NA  RB  JUMP TO address in RB
  // JMP   2      0 1 0 0 NA  NA  JUMP TO address in next byte
  // JZ    2      0 1 0 1 00  01  JUMP IF answer is zero
  // JE    2      0 1 0 1 00  10  JUMP IF A equals B
  // JA    2      0 1 0 1 01  00  JUMP IF A is larger than B
  // JC    2      0 1 0 1 10  00  JUMP IF CARRY is on
  // JCA   2      0 1 0 1 11  00  JUMP IF CARRY or A larger
  // JCE   2      0 1 0 1 10  10  JUMP IF CARRY or A equal B
  // JCZ   2      0 1 0 1 10  01  JUMP IF CARRY or answer is zero
  // JAE   2      0 1 0 1 01  10  JUMP IF A is larger or equal to B
  // JAZ   2      0 1 0 1 01  01  JUMP IF A is larger or answer is zero
  // JEZ   2      0 1 0 1 00  11  JUMP IF A equals B or answer is zero
  // JCAE  2      0 1 0 1 11  10  JUMP IF CARRY or A larger or equal to B
  // JCAZ  2      0 1 0 1 11  01  JUMP IF CARRY or A larger or zero
  // JCEZ  2      0 1 0 1 10  11  JUMP IF CARRY or A equals B or zero
  // JAEZ  2      0 1 0 1 01  11  JUMP IF A larger or equal to B or zero
  // JCAEZ 2      0 1 0 1 11  11  JUMP IF CARRY or A larger or equal or zero
  // CLF   1      0 1 1 0 NA  NA  CLEAR ALL FLAGS
  // END   1      1 1 0 0 11  11  END

  typedef struct packed {
    logic carry;
    logic larger;
    logic equal;
    logic zero;
  } struct_flag_t;

  typedef enum logic [7:0] {
      INST_ADD  = 8'b10000000
    , INST_SHR  = 8'b10010000
    , INST_SHL  = 8'b10100000
    , INST_NOT  = 8'b10110000
    , INST_AND  = 8'b11000000
    , INST_OR   = 8'b11010000
    , INST_XOR  = 8'b11100000
    , INST_CMP  = 8'b11110000
    , INST_LD   = 8'b00000000
    , INST_ST   = 8'b00010000
    , INST_DATA = 8'b00100000
    , INST_JMPR = 8'b00110000
    , INST_JMP  = 8'b01000000
    , INST_J    = 8'b01010000
    , INST_CLF  = 8'b01100000
    , INST_END  = 8'b11001111
  } cpu_cmd;

  initial begin
    error = 0;
    #(10*`TOP.CLK_PERIOD)

    `display_warn("Current version of this vector just display signals' values without verifying any function");

    flag_sts = '{default:0};

    task_cpu_ctl (
        .cmd (INST_ADD)
      , .ra  (2'b00   )
      , .rb  (2'b01   )
    );

    task_cpu_ctl (
        .cmd      (INST_J)
      , .flag     ('{default:0, zero:1})
      , .alu_flag ('{default:0, zero:1})
    );

    task_cpu_ctl (
        .cmd      (INST_J)
      , .flag     ('{default:0, zero:1, carry:1})
      , .alu_flag ('{default:0, zero:1})
    );

    #(10*`TOP.CLK_PERIOD) $finish;
  end

  task task_cpu_ctl (
      input cpu_cmd       cmd
    , input logic [1:0]   ra       = '0
    , input logic [1:0]   rb       = '0
    , input struct_flag_t flag     = '{default:0}
    , input struct_flag_t alu_flag = '{default:0}
  );
    logic [pDATA_WIDTH-1:0] cmd_cvt;
    int phase_no;

    $sformat(message, "CPU cmd %s", cmd.name());
    `display_info(message);
    $sformat(message, "RA %d RB %d", ra, rb);
    `display_info(message);
    $sformat(message, "Flags %p", flag);
    `display_info(message);

    phase_no = 1;
    if (
         (cmd==INST_DATA)
      || (cmd==INST_JMP)
      || (cmd==INST_J)
    ) begin
      phase_no = 2;
    end

    cmd_cvt = pDATA_WIDTH'(cmd);
    if (cmd==INST_J) begin
      cmd_cvt = cmd_cvt | pDATA_WIDTH'(flag);
    end else if (
         (cmd==INST_DATA)
      || (cmd==INST_JMPR)
    ) begin
      cmd_cvt = cmd_cvt | pDATA_WIDTH'(rb);
    end else if (
         (cmd==INST_LD)
      || (cmd==INST_ST)
      || (cmd_cvt[pDATA_WIDTH-1])
    ) begin
      cmd_cvt = cmd_cvt | pDATA_WIDTH'({ra, rb});
    end

    @(posedge `TOP.rclk)
    #(`TOP.CLK_PERIOD-`TOP.CLK_DELAY)
    force `CPU.ien = 1'b1;
    force `CPU.idir_data = cmd_cvt;
    force `CPU.ialu_flag = alu_flag;

    wait (`CPU.rfsm_curstate.name() == "ST_E3")
    #(2*`TOP.CLK_PERIOD-`TOP.CLK_DELAY)
    release `CPU.ien;
    release `CPU.idir_data;
    release `CPU.ialu_flag;

  endtask

  always @(negedge `TOP.rclk) begin : smon_cpu_proc
    if (|`CPU.oreg_en) begin
      $sformat(message, "CPU state %s", `CPU.rfsm_curstate.name());
      `display_info(message);
      $sformat(message, "DSEL %s", `CPU.odata_sel.name());
      `display_info(message);
      $sformat(message, "Reg En %p", `CPU.oreg_en);
      `display_info(message);
      $sformat(message, "ALU code %s, force add %b", `CPU.oalu_opcode.name(), `CPU.oforce_rb);
      `display_info(message);
    end
  end

endmodule
