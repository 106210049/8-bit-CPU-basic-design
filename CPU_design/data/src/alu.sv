// -------------------------------------------------------------------------
// Description:
//

`default_nettype none  // turn off implicit data types

`begin_keywords "1800-2012"

module alu
  import cpu_pkg::*;
  (//---- PORT SIGNALS DECLARATION ---------------------------------------------
      input  enum_alu_opcode_t       iopcode
    , input  logic                   icarry
    , input  logic [pDATA_WIDTH-1:0] ira
    , input  logic [pDATA_WIDTH-1:0] irb
    , output struct_alu_flag_t       oflag
    , output logic [pDATA_WIDTH-1:0] odata
  );

  `ifndef SYNTHESIS
    timeunit 1ps;
    timeprecision 1ps;
  `endif

  //--------------------------------------------------------------------------//
  //   F u n c t i o n a l    L o g i c
  //--------------------------------------------------------------------------//
  always_comb begin : calu_proc
    odata = '0;
    oflag = '{default:0};
    case (iopcode)
      ALU_OP_ADD : begin
        {oflag.carry, odata} = (pDATA_WIDTH+1)'(ira + irb + icarry);
      end
      ALU_OP_SHL : begin
        {oflag.carry, odata} = {ira, icarry};
      end
      ALU_OP_SHR : begin
        {odata, oflag.carry} = {icarry, ira};
      end
      ALU_OP_CPR : begin
        oflag.equal  = (ira==irb);
        oflag.larger = (ira>irb);
      end
      ALU_OP_AND : begin
        odata = (ira&irb);
      end
      ALU_OP_OR : begin
        odata = (ira|irb);
      end
      ALU_OP_XOR : begin
        odata = (ira^irb);
      end
      ALU_OP_NOT : begin
        odata = (~ira);
      end
    endcase
    oflag.zero = !(|odata);
  end : calu_proc

endmodule : alu

`end_keywords

`default_nettype wire  // restore implicit data types
