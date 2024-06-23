// -------------------------------------------------------------------------
// Description:
//

`default_nettype none  // turn off implicit data types

`begin_keywords "1800-2012"

module cpu_top
  import cpu_pkg::*;
  (//---- PORT SIGNALS DECLARATION ---------------------------------------------
      input  logic iclk
    , input  logic irst_n
    , input  logic ien
  );

  `ifndef SYNTHESIS
    timeunit 1ps;
    timeprecision 1ps;
  `endif

  //--------------------------------------------------------------------------//
  //   L o c a l    P a r a m e t e r s
  //--------------------------------------------------------------------------//
  localparam pCPU_BUS_SRC_NO = 7;

  //--------------------------------------------------------------------------//
  //   V a r i a b l e    D e c l a r a t i o n s
  //--------------------------------------------------------------------------//
  struct_data_bus_t                            wcpu_bus_src;
  logic [pCPU_BUS_SRC_NO-1:0][pDATA_WIDTH-1:0] wcpu_bus_src_a;
  logic                      [pDATA_WIDTH-1:0] wcpu_bus;
  logic                      [pDATA_WIDTH-1:0] wdir_data;

  // CPU
  struct_reg_en_t         wreg_en;
  enum_dsel_t             wdata_sel;
  enum_alu_opcode_t       walu_opcode;
  logic                   wforce_rb;
  logic                   wflag_clf;

  // ALU
  struct_alu_flag_t       walu_flag;

  genvar gv_reg_idx;
  //--------------------------------------------------------------------------//
  //   F u n c t i o n a l    L o g i c
  //--------------------------------------------------------------------------//
  cpu u_cpu (
      .iclk        ( iclk        )
    , .irst_n      ( irst_n      )
    , .ien         ( ien         )
    , .idir_data   ( wdir_data   )
    , .oreg_en     ( wreg_en     )
    , .odata_sel   ( wdata_sel   )
    , .ialu_flag   ( walu_flag   )
    , .oalu_opcode ( walu_opcode )
    , .oforce_rb   ( wforce_rb   )
    , .oflag_clf   ( wflag_clf   )
  );

  // User
  generate
    for (gv_reg_idx=0; gv_reg_idx<pUSR_REG_NO; gv_reg_idx++) begin : guser_reg
      common_reg #(
          .pDATA_WIDTH ( pDATA_WIDTH )
      ) u_usr_reg (
          .iclk   ( iclk                     )
        , .irst_n ( irst_n                   )
        , .ien    ( wreg_en[gv_reg_idx]      )
        , .idata  ( wcpu_bus                 )
        , .odata  ( wcpu_bus_src.usr_data[gv_reg_idx] )
      );

    end
  endgenerate

  // Instruction
  common_reg #(
      .pDATA_WIDTH ( pDATA_WIDTH )
  ) u_dir_reg (
      .iclk   ( iclk           )
    , .irst_n ( irst_n         )
    , .ien    ( wreg_en.dir_en )
    , .idata  ( wcpu_bus       )
    , .odata  ( wdir_data      )
  );

  common_reg #(
      .pDATA_WIDTH ( pDATA_WIDTH )
  ) u_air_reg (
      .iclk   ( iclk                  )
    , .irst_n ( irst_n                )
    , .ien    ( wreg_en.air_en        )
    , .idata  ( wcpu_bus              )
    , .odata  ( wcpu_bus_src.air_data )
  );

  // ALU and MEM
  alu_wr u_alu  (
      .iclk      ( iclk                  )
    , .irst_n    ( irst_n                )
    , .iacc_en   ( wreg_en.acc_en        )
    , .itmp_en   ( wreg_en.tmp_en        )
    , .iflg_en   ( wreg_en.flg_en        )
    , .iclf      ( wflag_clf             )
    , .iforce_rb ( wforce_rb             )
    , .iopcode   ( walu_opcode           )
    , .idata     ( wcpu_bus              )
    , .oflag     ( walu_flag             )
    , .odata     ( wcpu_bus_src.acc_data )
  );

  memory_array u_mem (
      .iclk   ( iclk                  )
    , .irst_n ( irst_n                )
    , .iaen   ( wreg_en.ame_en        )
    , .iden   ( wreg_en.dme_en        )
    , .idata  ( wcpu_bus              )
    , .odata  ( wcpu_bus_src.dme_data )
  );

  // Data bus
  assign wcpu_bus_src_a = wcpu_bus_src;
  assign wcpu_bus = wcpu_bus_src_a[pCPU_BUS_WIDTH'(wdata_sel)];

endmodule : cpu_top

`end_keywords

`default_nettype wire  // restore implicit data types
