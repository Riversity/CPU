// Reservation Station
`include "const.v"
`include "alu.v"
module rs (
  // RS_SIZE = 16
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // from ROB
  input wire rob_clear,

  // from decoder
  input wire is_dc,
  input wire [31:0]   dc_pc,
  input wire [10:0]   dc_op, // {ins[30], ins[14:12], ins[6:0]}
  input wire [31:0]   dc_imm,
  input wire          dc_iQi,
  input wire [`ROB_R] dc_Qi,
  input wire          dc_iQj,
  input wire [`ROB_R] dc_Qj,
  input wire [`ROB_R] dc_Qdest,
  input wire [31:0]   dc_Vi,
  input wire [31:0]   dc_Vj,

  output wire rs_full,

  // from lsb, update Q
  input wire is_lsb,
  input wire [`ROB_R] lsb_rob_id,
  input wire [31:0] lsb_res,

  // to rob
  output wire rs_has_output,
  output wire [`ROB_R] rs_rob_id, // last output used to update current input Q
  output wire [31:0] rs_output,
  output wire has_jalr_new_pc, // cancel_stuck
  output wire [31:0] jalr_new_pc
);

  reg          busy[`RS_A];
  reg [31:0]   pc  [`RS_A];
  reg [10:0]   op  [`RS_A];
  reg [31:0]   imm [`RS_A];
  reg          iQ1 [`RS_A]; // iQ == 1 <=> Q == -1 <=> no dependency
  reg [`ROB_R] Q1  [`RS_A];
  reg          iQ2 [`RS_A]; // iQ == 1 <=> Q == -1 <=> no dependency
  reg [`ROB_R] Q2  [`RS_A];
  reg [31:0]   V1  [`RS_A];
  reg [31:0]   V2  [`RS_A];
  reg [`ROB_R] Qdes[`RS_A];

  wire         exec[`RS_A];

  generate
    genvar i;
    for (i = 0; i < `RS; i = i + 1) begin
      assign exec[i] = busy[i] == 1 && iQ1[i] == 1 && iQ2[i] == 1;
    end
  endgenerate

  wire [4:0] first_empty = (busy[0] == 0) ? 0 : (busy[1] == 0) ? 1 : (busy[2] == 0) ? 2 : (busy[3] == 0) ? 3 :
                           (busy[4] == 0) ? 4 : (busy[5] == 0) ? 5 : (busy[6] == 0) ? 6 : (busy[7] == 0) ? 7 :
                           (busy[8] == 0) ? 8 : (busy[9] == 0) ? 9 : (busy[10] == 0) ? 10 : (busy[11] == 0) ? 11 :
                           (busy[12] == 0) ? 12 : (busy[13] == 0) ? 13 : (busy[14] == 0) ? 14 : (busy[15] == 0) ? 15 : 16;
  wire [4:0] first_avail = exec[0] ? 0 : exec[1] ? 1 : exec[2] ? 2 : exec[3] ? 3 :
                           exec[4] ? 4 : exec[5] ? 5 : exec[6] ? 6 : exec[7] ? 7 :
                           exec[8] ? 8 : exec[9] ? 9 : exec[10] ? 10 : exec[11] ? 11 :
                           exec[12] ? 12 : exec[13] ? 13 : exec[14] ? 14 : exec[15] ? 15 : 16;
  assign rs_full = first_empty == `RS;
  wire is_work = first_avail != `RS;
  wire [3:0] pos = first_avail;

  alu calc (
    .clk_in(clk_in),
    .yes(is_work),
    .op(op[pos]),
    .v1(V1[pos]),
    .v2(V2[pos]),
    .pc(pc[pos]),
    .imm(imm[pos]),
    .in_rob_id(Qdes[pos]),
    .has_output(rs_has_output),
    .rob_id(rs_rob_id),
    .value(rs_output),
    .has_new_pc(has_jalr_new_pc),
    .new_pc(jalr_new_pc)
  );

  always @(posedge clk_in) begin : RS
    integer i;
    if (rst_in || rob_clear) begin
      for (i = 0; i < `RS; i = i + 1) begin
        busy[i] <= 0;
      end
    end
    else if (!rdy_in) begin end
    else begin
      // insert
      if (is_dc) begin // guaranteed !rs_full
        busy[first_empty] <= 1;
        pc[first_empty] <= dc_pc;
        op[first_empty] <= dc_op;
        imm[first_empty] <= dc_imm;
        Q1[first_empty] <= dc_Qi;
        Q2[first_empty] <= dc_Qj;
        // consider output of this cycle
        iQ1[first_empty] <= dc_iQi || (rs_has_output && rs_rob_id == dc_Qi) || (is_lsb && lsb_rob_id == dc_Qi);
        iQ2[first_empty] <= dc_iQj || (rs_has_output && rs_rob_id == dc_Qj) || (is_lsb && lsb_rob_id == dc_Qj);
        V1[first_empty] <= dc_iQi ? dc_Vi : (rs_has_output && rs_rob_id == dc_Qi) ? rs_output : (is_lsb && lsb_rob_id == dc_Qi) ? lsb_res : {32{1'bx}};
        V2[first_empty] <= dc_iQj ? dc_Vj : (rs_has_output && rs_rob_id == dc_Qj) ? rs_output : (is_lsb && lsb_rob_id == dc_Qj) ? lsb_res : {32{1'bx}};
        Qdes[first_empty] <= dc_Qdest;
      end
      // update
      for (i = 0; i < `RS; i = i + 1) begin
        if (busy[i]) begin
          if (rs_has_output && !iQ1[i] && rs_rob_id == Q1[i]) begin
            iQ1[i] <= 1;
            V1[i] <= rs_output;
          end
          if (rs_has_output && !iQ2[i] && rs_rob_id == Q2[i]) begin
            iQ2[i] <= 1;
            V2[i] <= rs_output;
          end
          if (is_lsb && !iQ1[i] && lsb_rob_id == Q1[i]) begin
            iQ1[i] <= 1;
            V1[i] <= lsb_res;
          end
          if (is_lsb && !iQ2[i] && lsb_rob_id == Q2[i]) begin
            iQ2[i] <= 1;
            V2[i] <= lsb_res;
          end
        end
      end
      // free
      if (is_work) busy[pos] <= 0;
    end
  end
endmodule