//////////////////////////////////////////////////////////////////////////////
// Description: Verify memory by writing into the array then read data out

`define CPU `TOP.u_dut.u_cpu

module vector;
  timeunit 1ps;
  timeprecision 1ps;
  import cpu_pkg::*;

  string message;
  int error;
  logic header_en;

  initial begin
    error = 0;
    header_en = '0;
    #(10*`TOP.CLK_PERIOD)
    `TOP.tsk_force_mem;

    #(`TOP.CLK_PERIOD)
    `TOP.ren = 1'b1;


    wait (`TOP.u_dut.u_cpu.rcurrent_sig.done)
    #(`TOP.CLK_PERIOD)
    `TOP.ren = 1'b0;

    #(10*`TOP.CLK_PERIOD) $finish;
  end

  always @(negedge `TOP.rclk) begin : smon_cpu_proc
    if (!header_en) begin
      $sformat(message, "IR       | State | DSEL       | flg | tmp | acc | air | dir | ame | dme | usr  | f_rb | r3       | r2       | r1       | r0       ");
      `display_info(message);
      header_en = '1;
    end
    if (!`CPU.rreg_sel_en) begin
      if (`CPU.rfsm_curstate.name()=="ST_E1") begin
        $sformat(message, "%8b | %5s | %-10s | %3d | %3d | %3d | %3d | %3d | %3d | %3d | %4b | %4b | %8b | %8b | %8b | %8b",
                          `CPU.idir_data,
                          `CPU.rfsm_curstate.name(),
                          `CPU.odata_sel.name(),
                          `CPU.oreg_en.flg_en ,
                          `CPU.oreg_en.tmp_en ,
                          `CPU.oreg_en.acc_en ,
                          `CPU.oreg_en.air_en ,
                          `CPU.oreg_en.dir_en ,
                          `CPU.oreg_en.ame_en ,
                          `CPU.oreg_en.dme_en ,
                          `CPU.oreg_en.usr_en,
                          `CPU.oforce_rb,
                          `TOP.u_dut.guser_reg[3].u_usr_reg.odata,
                          `TOP.u_dut.guser_reg[2].u_usr_reg.odata,
                          `TOP.u_dut.guser_reg[1].u_usr_reg.odata,
                          `TOP.u_dut.guser_reg[0].u_usr_reg.odata
        );
        `display_info(message);
//      $sformat(message, "CPU state %s", `CPU.rfsm_curstate.name());
//      `display_info(message);
//      $sformat(message, "DSEL %s", `CPU.odata_sel.name());
//      `display_info(message);
//      $sformat(message, "Reg En %p", `CPU.oreg_en);
//      `display_info(message);
//      $sformat(message, "ALU code %s, force add %b", `CPU.oalu_opcode.name(), `CPU.oforce_rb);
//      `display_info(message);
      end
    end
  end
endmodule
