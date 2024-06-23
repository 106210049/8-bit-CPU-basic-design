// -------------------------------------------------------------------------
// Description:
//

`default_nettype none  // turn off implicit data types

`begin_keywords "1800-2012"

module cpu
  import cpu_pkg::*;
  (//---- PORT SIGNALS DECLARATION ---------------------------------------------
      input  logic                   iclk
    , input  logic                   irst_n
    , input  logic                   ien

    , input  logic [pDATA_WIDTH-1:0] idir_data
    , output struct_reg_en_t         oreg_en
    , output enum_dsel_t             odata_sel

    , input  struct_alu_flag_t       ialu_flag
    , output enum_alu_opcode_t       oalu_opcode
    , output logic                   oforce_rb

    , output logic                   oflag_clf
  );

  `ifndef SYNTHESIS
    timeunit 1ps;
    timeprecision 1ps;
  `endif

  //--------------------------------------------------------------------------//
  //   L o c a l    P a r a m e t e r s
  //--------------------------------------------------------------------------//
  localparam pDIR_CMD_WIDTH = 4;
  localparam pDIR_DAT_WIDTH = 4;

  // Notify the FSM need to jump to next state in the next cycle
  localparam pREG_NEXTST_CYCLE = 1'b1;

  localparam pIR_REG_SEL_WIDTH = 2;
  //--------------------------------------------------------------------------//
  //   V a r i a b l e    D e c l a r a t i o n s
  //--------------------------------------------------------------------------//
  logic rreg_sel_en; // 0-Select bus, 1-Enable capture

  typedef enum logic [2:0] {
      ST_IDLE
    , ST_F1
    , ST_F2
    , ST_F3
    , ST_E1
    , ST_E2
    , ST_E3
  } enum_state_t;
  enum_state_t rfsm_curstate, wfsm_nextstate;

  typedef struct packed {
    logic           done    ;
    logic           alu_add ;
    struct_reg_en_t reg_en  ;
    enum_dsel_t     data_sel;

    logic           flag_clf;
  } struct_signal_t;
  struct_signal_t rcurrent_sig, wnext_sig;

  typedef enum logic [3:0] {
      IR_ALU
    , IR_LD
    , IR_ST
    , IR_DATA
    , IR_JMPR
    , IR_JMP
    , IR_JFLAG
    , IR_CLF
    , IR_END
  } enum_ir_t;
  enum_ir_t wir_decode;

  logic [pDIR_CMD_WIDTH-1:0] wdir_cmd;
  logic [pDIR_DAT_WIDTH-1:0] wdir_dat;

  struct_alu_flag_t wflag_en;
  logic             wflag_ok;

  logic [pIR_REG_SEL_WIDTH-1:0] wra;
  logic [pIR_REG_SEL_WIDTH-1:0] wrb;
  //--------------------------------------------------------------------------//
  //   F u n c t i o n a l    L o g i c
  //--------------------------------------------------------------------------//
  assign wdir_dat = idir_data[0                 +: pDIR_DAT_WIDTH];
  assign wdir_cmd = idir_data[pDIR_DAT_WIDTH    +: pDIR_CMD_WIDTH];
  assign wrb      = idir_data[0                 +: pIR_REG_SEL_WIDTH];
  assign wra      = idir_data[pIR_REG_SEL_WIDTH +: pIR_REG_SEL_WIDTH];

  assign oflag_clf = rcurrent_sig.flag_clf;
  assign oreg_en   = rcurrent_sig.reg_en;
  assign odata_sel = rcurrent_sig.data_sel;

  // ALU operation
  assign oforce_rb = rcurrent_sig.alu_add;
  always_comb begin : calu_opcode_proc
    oalu_opcode = ALU_OP_ADD;
    if (!rcurrent_sig.alu_add) begin
      case (wdir_cmd)
        4'b1000: oalu_opcode = ALU_OP_ADD;
        4'b1001: oalu_opcode = ALU_OP_SHR;
        4'b1010: oalu_opcode = ALU_OP_SHL;
        4'b1011: oalu_opcode = ALU_OP_NOT;
        4'b1100: oalu_opcode = ALU_OP_AND;
        4'b1101: oalu_opcode = ALU_OP_OR ;
        4'b1110: oalu_opcode = ALU_OP_XOR;
        4'b1111: oalu_opcode = ALU_OP_CPR;
      endcase
    end
  end : calu_opcode_proc

  // Instruction decode
  // This block is not designed in the diagram
  // It can be part of the FSM code but separating it here makes the code easier to read
  always_comb begin : cir_decode_proc
    if (idir_data==8'b11001111) begin
      wir_decode = IR_END;
    end else begin
      unique case (wdir_cmd)
        4'b1???: wir_decode = IR_ALU  ;
        4'b0000: wir_decode = IR_LD   ;
        4'b0001: wir_decode = IR_ST   ;
        4'b0010: wir_decode = IR_DATA ;
        4'b0011: wir_decode = IR_JMPR ;
        4'b0100: wir_decode = IR_JMP  ;
        4'b0101: wir_decode = IR_JFLAG;
        4'b0110: wir_decode = IR_CLF  ;
        default: wir_decode = IR_ALU  ;
      endcase
    end
  end : cir_decode_proc

  // Flag check
  assign wflag_en = struct_alu_flag_t'(wdir_dat);
  assign wflag_ok = func_flag_chk(
      .iflag    ( ialu_flag )
    , .iflag_en ( wflag_en  )
  );

  // ---
  // FSM
  // ---
  always_ff @(posedge iclk or negedge irst_n) begin : sreg_sel_proc
    if (!irst_n) begin
      rreg_sel_en <= '0;
    end else if (ien) begin
      rreg_sel_en <= ~rreg_sel_en;
    end else begin
      rreg_sel_en <= '0;
    end
  end : sreg_sel_proc

  always_ff @(posedge iclk or negedge irst_n) begin : sfsm_proc
    if (!irst_n) begin
      rfsm_curstate <= ST_IDLE;
      rcurrent_sig  <= '{data_sel:DSEL_USR_0, default:0};
    end else if (ien) begin
      rfsm_curstate <= wfsm_nextstate;
      rcurrent_sig  <= wnext_sig;
    end else begin
      rfsm_curstate <= ST_IDLE;
      rcurrent_sig  <= '{data_sel:DSEL_USR_0, default:0};
    end
  end : sfsm_proc

  always_comb begin : cfsm_proc
    wfsm_nextstate = ST_IDLE;
    wnext_sig      = '{done:rcurrent_sig.done, data_sel:DSEL_USR_0, default:0};
    case (rfsm_curstate)
      ST_IDLE : begin
        wnext_sig.done = rcurrent_sig.done;

        // done only asserts if the program has been finished
        // Thus FSM won't run in the case
        if (!rcurrent_sig.done) begin
          // Only start run if next cyle is signal selection
          if (rreg_sel_en==pREG_NEXTST_CYCLE) begin
            wfsm_nextstate          = ST_F1;
            wnext_sig.data_sel      = DSEL_AIR;
            wnext_sig.alu_add       = 1'b1;
            wnext_sig.reg_en.acc_en = 1'b1;
            wnext_sig.reg_en.ame_en = 1'b1;
          end
        end
      end

      // Fetch
      ST_F1 : begin
        if (rreg_sel_en==pREG_NEXTST_CYCLE) begin
          wfsm_nextstate          = ST_F2;
          wnext_sig.data_sel      = DSEL_DME;
          wnext_sig.reg_en.dir_en = 1'b1;
        end else begin
          wfsm_nextstate = ST_F1;
        end
      end
      ST_F2 : begin
        if (rreg_sel_en==pREG_NEXTST_CYCLE) begin
          wfsm_nextstate          = ST_F3;
          wnext_sig.data_sel      = DSEL_ACC;
          wnext_sig.reg_en.air_en = 1'b1;
        end else begin
          wfsm_nextstate = ST_F2;
        end
      end
      ST_F3 : begin
        if (rreg_sel_en==pREG_NEXTST_CYCLE) begin
          wfsm_nextstate = ST_E1;

          case (wir_decode)
            IR_ALU : begin
              wnext_sig.data_sel      = enum_dsel_t'(wrb);
              wnext_sig.reg_en.tmp_en = 1'b1;
            end
            IR_LD, IR_ST : begin
              wnext_sig.data_sel      = enum_dsel_t'(wra);
              wnext_sig.reg_en.ame_en = 1'b1;
            end
            IR_DATA : begin
              wnext_sig.data_sel      = DSEL_AIR;
              wnext_sig.reg_en.ame_en = 1'b1;
              wnext_sig.alu_add       = 1'b1;
              wnext_sig.reg_en.acc_en = 1'b1;
            end
            IR_JMPR : begin
              wnext_sig.data_sel      = enum_dsel_t'(wrb);
              wnext_sig.reg_en.air_en = 1'b1;
            end
            IR_JMP : begin
              wnext_sig.data_sel      = DSEL_AIR;
              wnext_sig.reg_en.ame_en = 1'b1;
            end
            IR_JFLAG : begin
              wnext_sig.data_sel      = DSEL_AIR;
              wnext_sig.reg_en.ame_en = 1'b1;
              wnext_sig.alu_add       = 1'b1;
              wnext_sig.reg_en.acc_en = 1'b1;
            end
            IR_CLF : begin
              wnext_sig.flag_clf = 1'b1;
            end
            IR_END : begin
              wnext_sig.done = 1'b1;
            end
          endcase
        end else begin
          wfsm_nextstate = ST_F3;
        end
      end

      // Execute
      ST_E1 : begin
        wnext_sig.done = rcurrent_sig.done;

        if (rcurrent_sig.done) begin
          wfsm_nextstate = ST_IDLE;
        end else begin
          if (rreg_sel_en==pREG_NEXTST_CYCLE) begin
            wfsm_nextstate = ST_E2;

            case (wir_decode)
              IR_ALU : begin
                wnext_sig.data_sel      = enum_dsel_t'(wra);
                wnext_sig.reg_en.acc_en = 1'b1;
                wnext_sig.reg_en.flg_en = 1'b1;
              end
              IR_LD : begin
                wnext_sig.data_sel    = DSEL_DME;
                wnext_sig.reg_en[wrb] = 1'b1;
              end
              IR_ST : begin
                wnext_sig.data_sel      = enum_dsel_t'(wrb);
                wnext_sig.reg_en.dme_en = 1'b1;
              end
              IR_DATA : begin
                wnext_sig.data_sel    = DSEL_DME;
                wnext_sig.reg_en[wrb] = 1'b1;
              end
              IR_JMP : begin
                wnext_sig.data_sel      = DSEL_DME;
                wnext_sig.reg_en.air_en = 1'b1;
              end
              IR_JFLAG : begin
                if (wflag_ok) begin
                  wnext_sig.data_sel = DSEL_DME;
                end else begin
                  wnext_sig.data_sel = DSEL_ACC;
                end

                wnext_sig.reg_en.air_en = 1'b1;
              end
            endcase
          end else begin
            wfsm_nextstate = ST_E1;
          end
        end
      end
      ST_E2 : begin
        if (rreg_sel_en==pREG_NEXTST_CYCLE) begin
          wfsm_nextstate = ST_E3;

          case (wir_decode)
            IR_ALU : begin
              wnext_sig.data_sel    = DSEL_ACC;
              wnext_sig.reg_en[wrb] = 1'b1;
            end
            IR_DATA : begin
              wnext_sig.data_sel      = DSEL_ACC;
              wnext_sig.reg_en.air_en = 1'b1;
            end
          endcase
        end else begin
          wfsm_nextstate = ST_E2;
        end
      end
      ST_E3 : begin
        if (rreg_sel_en==pREG_NEXTST_CYCLE) begin
          wfsm_nextstate          = ST_F1;
          wnext_sig.data_sel      = DSEL_AIR;
          wnext_sig.alu_add       = 1'b1;
          wnext_sig.reg_en.acc_en = 1'b1;
          wnext_sig.reg_en.ame_en = 1'b1;
        end else begin
          wfsm_nextstate = ST_E3;
        end

      end
    endcase
  end : cfsm_proc

  function automatic logic func_flag_chk (
      input struct_alu_flag_t iflag
    , input struct_alu_flag_t iflag_en
  );
    int vflag_idx;

    func_flag_chk = 1'b1;

    for (vflag_idx=0; vflag_idx<pALU_FLAG_WIDTH; vflag_idx=vflag_idx+1) begin
      if (iflag_en[vflag_idx]) begin
        if (!iflag[vflag_idx]) begin
          func_flag_chk = 1'b0;
          return func_flag_chk;
        end
      end
    end

    return func_flag_chk;
  endfunction

endmodule : cpu

`end_keywords

`default_nettype wire  // restore implicit data types
