// Reorder Buffer
`include "const.v"
module rob (
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  output reg rob_clear,
  output wire rob_empty,
  output wire rob_full,
  output reg [31:0] new_pc,
  // output reg cancel_stuck,

  // from decoder
  input wire is_ins,
  // input wire [31:0] ins,
  input wire [31:0] ins_pc,
  // input wire [31:0] ins_pred_pc,
  input wire ins_already_done, // jal jalr auipc lui
  input wire [31:0] ins_result, // jal jalr auipc lui
  input wire [4:0] ins_rd,
  input wire ins_pred_jmp,
  input wire [31:0] another_addr, // br, different from predicted
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

  // to regfile
  output wire is_commit,
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
  output wire [31:0] rob_val_2,

  // to insfetch branch predictor
  output wire is_b_res,
  output wire [7:0] b_res_pc_part,
  output wire b_res_jmp
);

  // stats : 0 Issu/Exec, 1 Comt
  // localparam Issu = 2'b00;
  // localparam Exec = 2'b01;
  // localparam Wres = 2'b10;
  // localparam Comt = 2'b11;

  reg busy[`ROB_A];
  reg stat[`ROB_A];
  reg [1:0] type[`ROB_A];
  reg [31:0] val[`ROB_A];
  reg [4:0] rd[`ROB_A];
  reg pred_jmp[`ROB_A];
  reg [31:0] another_br[`ROB_A]; // either from jalr or from decoder branch
  reg [31:0] pc[`ROB_A];

  reg [`ROB_R] head;
  reg [`ROB_R] tail;
  wire [`ROB_R] nx_head = head + 1;
  wire [`ROB_R] nx_tail = tail + 1;
  wire [`ROB_R] nx_nx_tail = nx_tail + 1;
  assign rob_empty = head == tail && !busy[head];
  assign rob_full = (tail == head && busy[head]) || nx_tail == head || nx_nx_tail  == head || (nx_nx_tail + 1) % `ROB == head;

  assign rob_head_id = head;
  assign rob_free_id = tail;

  assign is_b_res = busy[head] && stat[head] && type[head] == `Btype;
  assign b_res_pc_part = pc[head][8:1];
  assign b_res_jmp = pred_jmp[head];

  // to regfile
  assign is_commit = rdy_in && busy[head] && stat[head];
  // set value
  wire is_change_reg = is_commit && type[head][0];
  // type[head][0] is a goofy shorthand for (type == R or J)
  assign set_id = is_change_reg ? rd[head] : 0;
  assign set_from_rob_id = head;
  assign set_val = val[head];
  // set dep
  wire is_set_dep = rdy_in && is_ins && ins_type[0];
  assign set_dep_id = is_set_dep ? ins_rd : 0;
  assign set_dep_Q = tail;
  // set decoder new value through regfile
  assign rob_avail_1 = stat[get_rob_id_1] || (rs_has_output && rs_rob_id == get_rob_id_1) || (lsb_has_output && lsb_rob_id == get_rob_id_1);
  assign rob_avail_2 = stat[get_rob_id_2] || (rs_has_output && rs_rob_id == get_rob_id_2) || (lsb_has_output && lsb_rob_id == get_rob_id_2);
  assign rob_val_1 = stat[get_rob_id_1] ? val[get_rob_id_1] : (rs_has_output && rs_rob_id == get_rob_id_1) ? rs_output : lsb_output;
  assign rob_val_2 = stat[get_rob_id_2] ? val[get_rob_id_2] : (rs_has_output && rs_rob_id == get_rob_id_2) ? rs_output : lsb_output;

  always @(posedge clk_in) begin : ROB
    integer i;
    if (!rdy_in) begin end
    else if (rst_in || rob_clear) begin
      rob_clear <= 0;
      new_pc <= 0;
      head <= 0;
      tail <= 0;
      for (i = 0; i < `ROB; i = i + 1) begin
        busy[i] <= 0;
        stat[i] <= 0;
        type[i] <= 0;
        val[i] <= 0;
        rd[i] <= 0;
        pred_jmp[i] <= 0;
        another_br[i] <= 0;
        pc[i] <= 0;
      end
    end
    else begin
      // write back
      if (rs_has_output) begin
        stat[rs_rob_id] <= 1;
        val[rs_rob_id] <= rs_output;
      end
      if (lsb_has_output) begin
        stat[lsb_rob_id] <= 1;
        val[lsb_rob_id] <= lsb_output;
      end
      // issue
      if (is_ins) begin
        if (busy[head] && tail == head) $display("rob facked!");
        tail <= nx_tail;
        busy[tail] <= 1;
        stat[tail] <= ins_already_done;
        type[tail] <= ins_type;
        val[tail] <= ins_result;
        rd[tail] <= ins_rd;
        pred_jmp[tail] <= ins_pred_jmp;
        another_br[tail] <= another_addr;
        pc[tail] <= ins_pc;
      end
      // commit
      if (is_commit) begin
        // $display("%0x", pc[head]);
        head <= nx_head;
        busy[head] <= 0;
        stat[head] <= 0;
        // if (pc[head][6:0] == `ojalr) begin
        //   // can optimize, directly from alu to insfetch!
        //   cancel_stuck <= 1;
        //   new_pc <= another_addr[head];
        // end
        if (type[head] == `Btype) begin
          if (val[head][0] != pred_jmp[head]) begin
            // bad pred
            rob_clear <= 1;
            new_pc <= another_br[head];
          end
        end
      end
    end
  end
endmodule