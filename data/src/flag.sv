// -------------------------------------------------------------------------
// Description:
//

`default_nettype none  // turn off implicit data types

`begin_keywords "1800-2012"

module flag
  import cpu_pkg::*;
  (//---- PORT SIGNALS DECLARATION ---------------------------------------------
      input  logic             iclk
    , input  logic             irst_n

    , input  logic             iclf
    , input  logic             ien
    , input  struct_alu_flag_t iflag
    , output struct_alu_flag_t oflag

    , input  logic             iforce_carry
    , output logic             ocarry

  );

  `ifndef SYNTHESIS
    timeunit 1ps;
    timeprecision 1ps;
  `endif

  //--------------------------------------------------------------------------//
  //   L o c a l    P a r a m e t e r s
  //--------------------------------------------------------------------------//

  //--------------------------------------------------------------------------//
  //   V a r i a b l e    D e c l a r a t i o n s
  //--------------------------------------------------------------------------//

  //--------------------------------------------------------------------------//
  //   F u n c t i o n a l    L o g i c
  //--------------------------------------------------------------------------//
  always_ff @(posedge iclk or negedge irst_n) begin : sdata_proc
    if (!irst_n) begin
      oflag <= '{default:0};
    end else if (iclf) begin
      oflag <= '{default:0};
    end else if (ien) begin
      oflag <= iflag;
    end
  end : sdata_proc

  assign ocarry = (iforce_carry) ? 1'b0 : oflag.carry;

endmodule : flag

`end_keywords

`default_nettype wire  // restore implicit data types
