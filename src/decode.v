// Instruction Decoder
`include "const.v"
module decode (
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // from insfetch
  input wire is_ins,
  input wire [31:0] ins_addr,
  input wire [31:0] ins,
  input wire pred_jmp,
  input wire [31:0] pred_another,

  // to insfetch
  output wire f_stall, // rob_rs_slb_full

  // with regfile
  output wire   [4:0] get_id_1,
  input wire   [31:0] get_val_1,
  input wire          get_has_dep_1,
  input wire [`ROB_R] get_dep_1,
  output wire   [4:0] get_id_2,
  input wire   [31:0] get_val_2,
  input wire          get_has_dep_2,
  input wire [`ROB_R] get_dep_2,

  // with rs
  input wire rs_full,

  output reg is_rs,
  output reg [31:0]   rs_pc,
  output reg [10:0]   rs_op, // {ins[30], ins[14:12], ins[6:0]}
  output reg [31:0]   rs_imm,
  output reg          rs_iQi,
  output reg [`ROB_R] rs_Qi,
  output reg          rs_iQj,
  output reg [`ROB_R] rs_Qj,
  output wire [`ROB_R]rs_Qdest,
  output reg [31:0]   rs_Vi,
  output reg [31:0]   rs_Vj,

  // with lsb
  input wire lsb_full,

  output reg is_lsb,
  output reg [9:0]    lsb_op, // {ins[14:12], ins[6:0]}
  output reg [31:0]   lsb_imm,
  output reg          lsb_iQi,
  output reg [`ROB_R] lsb_Qi,
  output reg          lsb_iQj,
  output reg [`ROB_R] lsb_Qj,
  output wire [`ROB_R]lsb_Qdest,
  output reg [31:0]   lsb_Vi,
  output reg [31:0]   lsb_Vj,

  // with rob
  input wire rob_full,
  input wire rob_clear,
  input wire [`ROB_R] rob_free_id,
  output reg r_is_ins,
  // output reg [31:0] r_ins,
  output reg [31:0] r_ins_pc,
  output reg r_ins_already_done, // jal jalr auipc lui
  output reg [31:0] r_ins_result, // jal jalr auipc lui
  output reg [4:0] r_ins_rd,
  output reg r_ins_pred_jmp,
  output reg [31:0] r_another_addr, // br, different from predicted
  output reg [1:0] r_ins_type
);

  assign f_stall = rs_full || lsb_full || rob_full;

  wire [6:0] op = ins[6:0];
  wire [4:0] rd = ins[11:7];
  wire [4:0] rs1 = ins[19:15];
  wire [4:0] rs2 = ins[24:20];
  wire [31:0] immIext = {{20{ins[31]}}, ins[31:20]};
  wire [31:0] immSext = {{20{ins[31]}}, ins[31:25], ins[11:7]};
  wire [31:0] immBext = {{20{ins[31]}}, ins[7], ins[30:25], ins[11:8], 1'b0};
  wire [31:0] immUext = {ins[31:12], 12'b0};

  // instant wire to regfile
  assign get_id_1 = rs1;
  assign get_id_2 = (op == `ojalr || op == `ori || op == `ol) ? 0 : rs2;

  assign rs_Qdest = rob_free_id;
  assign lsb_Qdest = rob_free_id;

  wire to_rs = op == `ojalr || op == `ob || op == `ori || op == `orr;
  wire to_lsb = op == `os || op == `ol;

  reg [31:0] last_addr;

  always @(posedge clk_in) begin : DECODE
    if (rst_in || rob_clear) begin
      is_rs <= 0;
      is_lsb <= 0;
      r_is_ins <= 0;
      last_addr <= 32'hffffffff;
    end
    else if (!rdy_in) begin end
    else begin
      if (is_ins && ins_addr != last_addr) begin
        last_addr <= ins_addr;

        rs_iQi <= !get_has_dep_1;
        rs_Qi <= get_dep_1;
        rs_Vi <= get_val_1;
        rs_iQj <= !get_has_dep_2;
        rs_Qj <= get_dep_2;
        rs_Vj <= get_val_2;

        lsb_iQi <= !get_has_dep_1;
        lsb_Qi <= get_dep_1;
        lsb_Vi <= get_val_1;
        lsb_iQj <= !get_has_dep_2;
        lsb_Qj <= get_dep_2;
        lsb_Vj <= get_val_2;

        is_rs <= to_rs;
        rs_pc <= ins_addr;
        rs_op <= {ins[30], ins[14:12], ins[6:0]};
        rs_imm <= immIext;
        // slli etc. is handled in alu
        // `orr, `ob have no imm
        // `ojalr is also this

        is_lsb <= to_lsb;
        lsb_op <= {ins[14:12], ins[6:0]};
        lsb_imm <= op == `ol ? immIext : immSext;

        r_is_ins <= 1;
        r_ins_pc <= ins_addr;
        r_ins_already_done <= op == `ojal || op == `ojalr
                           || op == `oauipc || op == `olui;
        // the done here just mean value to be in register is ready
        r_ins_result <= op == `olui ? immUext : op == `oauipc ? immUext + ins_addr : ins_addr + 4;
        r_ins_rd <= rd;
        r_ins_pred_jmp <= pred_jmp;
        r_another_addr <= pred_another;
        r_ins_type <= op == `os ? `Stype : op == `ob ? `Btype : (op == `ojal || op == `ojalr) ? `Jtype : `Rtype;
        // `Rtype : op == `orr || op == `ori || op == `ol || op == `olui || op == `oauipc
      end
      else begin
        is_rs <= 0;
        is_lsb <= 0;
        r_is_ins <= 0;
      end
    end
  end
endmodule