//////////////////////////////////////////////////////////////////////////////
// Description: Verify memory by writing into the array then read data out

`define ALU `TOP.u_dut.u_alu

module vector;
  timeunit 1ps;
  timeprecision 1ps;
  import cpu_pkg::*;

  string message;
  int error;

  typedef struct {
    struct_alu_flag_t flag;
    logic [pDATA_WIDTH-1:0] data;
  } struct_alu_rsl_t;
  struct_alu_rsl_t  exp_alu_out;
  struct_alu_flag_t flag_sts;

  initial begin
    error = 0;
    #(10*`TOP.CLK_PERIOD)

    flag_sts = '{default:0};

    `display_info("ALU 255 ADD 1");
    alu_ctl (
        .opcode   (ALU_OP_ADD)
      , .ra       (8'd255    )
      , .rb       (8'd1      )
      , .force_add(1'b0      )
      , .flag_sts (flag_sts  )
      , .flag     (flag_sts  )
    );

    `display_info("ALU 3 SHR");
    alu_ctl (
        .opcode   (ALU_OP_SHR)
      , .ra       (8'd3      )
      , .rb       (8'd1      )
      , .force_add(1'b0      )
      , .flag_sts (flag_sts  )
      , .flag     (flag_sts  )
    );

    `display_info("ALU 5 force ADD");
    alu_ctl (
        .opcode   (ALU_OP_ADD)
      , .ra       (8'd5      )
      , .rb       (8'd5      )
      , .force_add(1'b1      )
      , .flag_sts (flag_sts  )
      , .flag     (flag_sts  )
    );

    #(10*`TOP.CLK_PERIOD) $finish;
  end

  task alu_ctl (
      input  enum_alu_opcode_t opcode
    , input  [pDATA_WIDTH-1:0] ra
    , input  [pDATA_WIDTH-1:0] rb
    , input  logic             force_add
    , input  struct_alu_flag_t flag_sts
    , output struct_alu_flag_t flag
  );
    @(posedge `TOP.rclk)
    #(`TOP.CLK_PERIOD-`TOP.CLK_DELAY)
    force `ALU.idata     = rb;
    force `ALU.itmp_en   = 1'b1;
    force `ALU.iforce_rb = force_add;
    #(`TOP.CLK_PERIOD)
    release `ALU.itmp_en;
    force `ALU.idata   = ra;
    force `ALU.iopcode = opcode;
    if (force_add) force `ALU.iflg_en = 1'b0;
    else           force `ALU.iflg_en = 1'b1;
    force `ALU.iacc_en = 1'b1;
    #(`TOP.CLK_PERIOD)
    release `ALU.idata;
    release `ALU.iopcode;
    release `ALU.iflg_en;
    release `ALU.iacc_en;
    release `ALU.iforce_rb;

    exp_alu_out = alu_cal (
        .opcode   ( opcode    )
      , .ra       ( ra        )
      , .rb       ( rb        )
      , .force_add( force_add )
      , .flag     ( flag_sts  )
    );
    if (!force_add) flag = exp_alu_out.flag;

    if (`ALU.odata!==exp_alu_out.data) begin
      $sformat(message, "wrong ALU out. Expected: %b data %b.", exp_alu_out.data, `ALU.odata);
      `display_err(message);
      error = error+1;
    end else begin
      $sformat(message, "sucess ALU out %b.", `ALU.odata);
      `display_info(message);
    end

    // Only compare flag if it is normal ALU operation
    if (!force_add) begin
      if (`ALU.oflag!==exp_alu_out.flag) begin
        $sformat(message, "wrong ALU flag. Expected: %p data %p.", exp_alu_out.flag, `ALU.oflag);
        `display_err(message);
        error = error+1;
      end else begin
        $sformat(message, "sucess ALU flag %p.", `ALU.oflag);
        `display_info(message);
      end
    end

  endtask : alu_ctl

  function struct_alu_rsl_t alu_cal (
      input enum_alu_opcode_t opcode
    , input [pDATA_WIDTH-1:0] ra
    , input [pDATA_WIDTH-1:0] rb
    , input logic             force_add
    , input struct_alu_flag_t flag
  );
    alu_cal = '{default:0};

    case (opcode)
      ALU_OP_ADD: begin
        if (force_add) begin
          {alu_cal.flag.carry, alu_cal.data} = pDATA_WIDTH'(ra)+1'b1;
        end else begin
          {alu_cal.flag.carry, alu_cal.data} = pDATA_WIDTH'(ra)+pDATA_WIDTH'(rb)+flag.carry;
        end
      end
      ALU_OP_SHL: begin
        {alu_cal.flag.carry, alu_cal.data}  = {ra, flag.carry};
      end
      ALU_OP_SHR: begin
        {alu_cal.data, alu_cal.flag.carry} = {flag.carry, ra};
      end
      ALU_OP_CPR: begin
        if (ra==rb) alu_cal.flag.equal = 1'b1;
        else if (ra>rb) alu_cal.flag.larger = 1'b1;
      end
      ALU_OP_AND: begin
        alu_cal.data = ra&rb;
      end
      ALU_OP_OR: begin
        alu_cal.data = ra|rb;
      end
      ALU_OP_XOR: begin
        alu_cal.data = ra^rb;
      end
      ALU_OP_NOT: begin
        alu_cal.data = ~ra;
      end
    endcase

    alu_cal.flag.zero = ~(|alu_cal.data);
  endfunction : alu_cal

endmodule
