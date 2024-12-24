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
  output reg [31:0]    rs_pc,
  output reg [10:0]    rs_op, // {ins[30], ins[14:12], ins[6:0]}
  output reg [31:0]    rs_imm,
  output wire          rs_iQi,
  output wire [`ROB_R] rs_Qi,
  output wire          rs_iQj,
  output wire [`ROB_R] rs_Qj,
  output wire [`ROB_R] rs_Qdest,
  output wire [31:0]   rs_Vi,
  output wire [31:0]   rs_Vj,

  // with lsb
  input wire lsb_full,

  output reg is_lsb,
  output reg [10:0]    lsb_op, // {ins[30], ins[14:12], ins[6:0]}
  output reg [31:0]    lsb_imm,
  output wire          lsb_iQi,
  output wire [`ROB_R] lsb_Qi,
  output wire          lsb_iQj,
  output wire [`ROB_R] lsb_Qj,
  output wire [`ROB_R] lsb_Qdest,
  output wire [31:0]   lsb_Vi,
  output wire [31:0]   lsb_Vj,

  // with rob
  input wire rob_full,
  input wire [`ROB_R] rob_free_id,
  output reg r_is_ins,
  output reg [31:0] r_ins,
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
  wire [11:0] immI = ins[31:20];
  wire [31:0] immJAL = {{12{ins[31]}}, ins[19:12], ins[20], ins[30:21], 1'b0};
  wire [31:0] immJALR = {{20{ins[31]}}, ins[31:20]};
  wire [31:0] immB = {{20{ins[31]}}, ins[7], ins[30:25], ins[11:8], 1'b0};

  // instant wire to regfile
  assign get_id_1 = rs1;
  assign get_id_2 = rs2;

  assign rs_iQi = get_has_dep_1;
  assign rs_Qi = get_dep_1;
  assign rs_Vi = get_val_1;
  assign rs_iQj = get_has_dep_2;
  assign rs_Qj = get_dep_2;
  assign rs_Vj = get_val_2;

  assign lsb_iQi = get_has_dep_1;
  assign lsb_Qi = get_dep_1;
  assign lsb_Vi = get_val_1;
  assign lsb_iQj = get_has_dep_2;
  assign lsb_Qj = get_dep_2;
  assign lsb_Vj = get_val_2;

  assign rs_Qdest = rob_free_id;
  assign lsb_Qdest = rob_free_id;

  always @(posedge clk_in) begin : DECODE
    if (rst_in) begin
      is_rs <= 0;
      is_lsb <= 0;
      r_is_ins <= 0;
    end
    else if (!rdy_in) begin end
    else begin
      if (is_ins) begin
        
      end
    end
  end

endmodule