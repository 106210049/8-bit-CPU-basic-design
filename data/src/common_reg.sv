// -------------------------------------------------------------------------
// Description: Common register that is used in various block
//

`default_nettype none  // turn off implicit data types

`begin_keywords "1800-2012"

module common_reg
  #(//---- PARAMETERS DECLARATION
      parameter pDATA_WIDTH = 8
  ) 
  (//---- PORT SIGNALS DECLARATION ---------------------------------------------
      input  logic                   iclk
    , input  logic                   irst_n

    , input  logic                   ien
    , input  logic [pDATA_WIDTH-1:0] idata
    , output logic [pDATA_WIDTH-1:0] odata
  );

  `ifndef SYNTHESIS
    timeunit 1ps;
    timeprecision 1ps;
  `endif

  //--------------------------------------------------------------------------//
  //   F u n c t i o n a l    L o g i c
  //--------------------------------------------------------------------------//
  always_ff @(posedge iclk or negedge irst_n) begin : sdata_proc
    if (!irst_n) begin
      odata <= '0;
    end else if (ien) begin
      odata <= idata;
    end
  end : sdata_proc

endmodule : common_reg

`end_keywords

`default_nettype wire  // restore implicit data types
