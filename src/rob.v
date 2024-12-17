// Reorder Buffer
`include "const.v"
module rob (
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  output wire rob_clear,
  output wire rob_empty,
  output wire rob_full,

  // from decoder
  input wire is_ins,
  input wire [31:0] ins,
  input wire [31:0] ins_pc,
  // input wire [31:0] ins_pred_jump,
  input wire ins_already_done, // jal jalr auipc lui
  input wire [4:0] ins_rd,
  input wire ins_pred_jmp,
  // free pos
  output wire [`ROB_R] rob_free_id,

  // from/to lsb
  output wire [`ROB_R] rob_head_id,
  input wire lsb_has_output,
  input wire [`ROB_R] lsb_rob_id,
  input wire [31:0] lsb_output,

  // from/to rs
  input wire rs_has_output,
  input wire [`ROB_R] rs_rob_id,
  input wire [31:0] rs_output,
  input wire [31:0] jalr_new_pc,

  // to regfile
  output wire [4:0] set_id,
  output wire [31:0] set_val,
  output wire [`ROB_R] set_from_rob_id,
  output wire [4:0] set_dep_id,
  output wire [`ROB_R] set_dep_Q,

  input wire [`ROB_R] get_rob_id_1,
  output wire rob_avail_1,
  output wire [31:0] rob_val_1,
  input wire [`ROB_R] get_rob_id_2,
  output wire rob_avail_2,
  output wire [31:0] rob_val_2
);

  reg busy[`ROB_A];
  reg ok[`ROB_A];
  reg [31:0] val[`ROB_A];
  reg [4:0] rd[`ROB_A];
  reg pred_jmp[`ROB_A];
  reg [31:0] pc[`ROB_A];

  reg [`ROB_R] head;
  reg [`ROB_R] tail;
  wire nx_head = head + 1;
  wire nx_tail = tail + 1;
  assign rob_empty = head == tail;
  assign rob_full = nx_tail == head || nx_tail + 1 == head;

  // to regfile

  always @(posedge clk_in) begin : ROB
    integer i;
    if (rst_in) begin
    end
    else if (!rdy_in) begin end
    else begin
    end
  end
endmodule