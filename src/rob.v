// Reorder Buffer
`include "const.v"
module rob (
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  output reg rob_clear,
  output wire rob_empty,
  output wire rob_full,

  // from decoder
  input wire is_ins,
  input wire [31:0] ins,
  input wire [31:0] ins_pc,
  // input wire [31:0] ins_pred_pc,
  input wire ins_already_done, // jal jalr auipc lui
  input wire ins_result,
  input wire [4:0] ins_rd,
  input wire ins_pred_jmp,
  input wire [1:0] ins_type,
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

  // stats : operation to do
  localparam Issu = 2'b00;
  localparam Exec = 2'b01;
  // localparam Wres = 2'b10;
  localparam Comt = 2'b10;

  reg busy[`ROB_A];
  reg [1:0] stat[`ROB_A];
  reg [1:0] type[`ROB_A];
  reg [31:0] val[`ROB_A];
  reg [4:0] rd[`ROB_A];
  reg pred_jmp[`ROB_A];
  reg [31:0] pc[`ROB_A];

  reg [`ROB_R] head;
  reg [`ROB_R] tail;
  wire [`ROB_R] nx_head = head + 1;
  wire [`ROB_R] nx_tail = tail + 1;
  wire [`ROB_R] nx_nx_tail = nx_tail + 1;
  assign rob_empty = head == tail;
  assign rob_full = nx_tail == head || nx_nx_tail  == head;

  assign rob_head_id = head;
  assign rob_free_id = tail;

  // to regfile
  // set value
  wire is_commit = busy[head] && stat[head] == Comt && type[head][1]; // rdy_in?
  assign set_id = is_commit ? rd[head] : 0;
  assign set_from_rob_id = head;
  assign set_val = val[head];
  // set dep
  wire is_set_dep = is_ins && ins_type[1];
  assign set_dep_id = is_set_dep ? ins_rd : 0;
  assign set_dep_Q = tail;
  // set decoder new value through regfile
  assign rob_avail_1 = stat[get_rob_id_1] == Comt || (rs_has_output && rs_rob_id == get_rob_id_1) || (lsb_has_output && lsb_rob_id == get_rob_id_1);
  assign rob_avail_2 = stat[get_rob_id_2] == Comt || (rs_has_output && rs_rob_id == get_rob_id_2) || (lsb_has_output && lsb_rob_id == get_rob_id_2);
  assign rob_val_1 = stat[get_rob_id_1] == Comt ? val[get_rob_id_1] : (rs_has_output && rs_rob_id == get_rob_id_1) ? rs_output : lsb_output;
  assign rob_val_2 = stat[get_rob_id_2] == Comt ? val[get_rob_id_2] : (rs_has_output && rs_rob_id == get_rob_id_2) ? rs_output : lsb_output;

  always @(posedge clk_in) begin : ROB
    integer i;
    if (rst_in) begin
    end
    else if (!rdy_in) begin end
    else begin

    end
  end
endmodule