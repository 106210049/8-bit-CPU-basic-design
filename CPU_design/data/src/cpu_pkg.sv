// -------------------------------------------------------------------------
// Description:
//

`default_nettype none  // turn off implicit data types

`begin_keywords "1800-2012"

package cpu_pkg;

  localparam pDATA_WIDTH = 8;
  localparam pADDR_WIDTH = 8;

  // ALU
  typedef enum logic [2:0] {
      ALU_OP_ADD
    , ALU_OP_SHL
    , ALU_OP_SHR
    , ALU_OP_CPR
    , ALU_OP_AND
    , ALU_OP_OR
    , ALU_OP_XOR
    , ALU_OP_NOT
  } enum_alu_opcode_t;

  // The flag indexes match with the instruction
  localparam pALU_FLAG_WIDTH = 4;
  typedef struct packed {
    logic carry ;
    logic zero  ;
    logic equal ; // a=b
    logic larger; // a>b
  } struct_alu_flag_t;

  // Register select port and index
  localparam pUSR_REG_NO = 4;

  typedef struct packed {
    logic                   flg_en;
    logic                   tmp_en;
    logic                   acc_en;
    logic                   air_en;
    logic                   dir_en;
    logic                   ame_en;
    logic                   dme_en;
    logic [pUSR_REG_NO-1:0] usr_en;
  } struct_reg_en_t;

  localparam pCPU_BUS_NO    = 7;
  localparam pCPU_BUS_WIDTH = 3;

  typedef struct packed {
    logic                  [pDATA_WIDTH-1:0] acc_data;
    logic                  [pDATA_WIDTH-1:0] air_data;
    logic                  [pDATA_WIDTH-1:0] dme_data;
    logic [pUSR_REG_NO-1:0][pDATA_WIDTH-1:0] usr_data;
  } struct_data_bus_t;

  typedef enum logic [2:0] {
      DSEL_USR_0 = 0
    , DSEL_USR_1 = 1
    , DSEL_USR_2 = 2
    , DSEL_USR_3 = 3
    , DSEL_DME   = 4
    , DSEL_AIR   = 5
    , DSEL_ACC   = 6
  } enum_dsel_t;

endpackage : cpu_pkg

`end_keywords

`default_nettype wire  // restore implicit data types
