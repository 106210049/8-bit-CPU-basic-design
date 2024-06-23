// -------------------------------------------------------------------------
// Description: Store command and data for the program
//

`default_nettype none  // turn off implicit data types

`begin_keywords "1800-2012"

module memory_array
  import cpu_pkg::*;
  (//---- PORT SIGNALS DECLARATION ---------------------------------------------
      input  logic                   iclk
    , input  logic                   irst_n

    , input  logic                   iaen
    , input  logic                   iden
    , input  logic [pDATA_WIDTH-1:0] idata
    , output logic [pDATA_WIDTH-1:0] odata

  );

  `ifndef SYNTHESIS
    timeunit 1ps;
    timeprecision 1ps;
  `endif

  //--------------------------------------------------------------------------//
  //   L o c a l    P a r a m e t e r s
  //--------------------------------------------------------------------------//
  localparam pMEM_DEPTH = 2**pADDR_WIDTH;

  //--------------------------------------------------------------------------//
  //   V a r i a b l e    D e c l a r a t i o n s
  //--------------------------------------------------------------------------//
  logic                 [pADDR_WIDTH-1:0] waddr;
  logic [pMEM_DEPTH-1:0][pDATA_WIDTH-1:0] rmemory_array;

  //--------------------------------------------------------------------------//
  //   F u n c t i o n a l    L o g i c
  //--------------------------------------------------------------------------//
  assign odata = rmemory_array[waddr];

  common_reg #(
      .pDATA_WIDTH(pDATA_WIDTH)
  ) u_addr (
      .iclk   ( iclk   )
    , .irst_n ( irst_n )
    , .ien    ( iaen   )
    , .idata  ( idata  )
    , .odata  ( waddr  )
  );

  always_ff @(posedge iclk or negedge irst_n) begin : smemory_array_proc
    if (!irst_n) begin
      rmemory_array <= '0;
    end else if (iden) begin
      rmemory_array[waddr] <= idata;
    end
  end : smemory_array_proc

endmodule : memory_array

`end_keywords

`default_nettype wire  // restore implicit data types
