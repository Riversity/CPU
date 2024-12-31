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
  output reg          rs_is_short,
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
  // output reg r_ins_already_done, // jal jalr auipc lui
  // output reg [31:0] r_ins_result, // jal jalr auipc lui
  output reg [4:0] r_ins_rd,
  output reg r_ins_pred_jmp,
  output reg [31:0] r_another_addr, // br, different from predicted
  output reg [1:0] r_ins_type
);

  // c.addi4spn: addi rd, x2, uimm
  // localparam caddi = 5'b00001;
  // localparam cjal = 5'b00101;
  // localparam cli = 5'b01001;

  wire [1:0] ins_1_0 = ins[1:0];
  wire [1:0] ins_6_5 = ins[6:5];
  wire [1:0] ins_11_10 = ins[11:10];
  wire [2:0] ins_15_13 = ins[15:13];

  wire long = ins_1_0 == 2'b11 || ins == 32'b0;

  assign f_stall = rs_full || lsb_full || rob_full;

  wire [6:0] op = long ? ins[6:0] :
                  ins_1_0 == 2'b00 ? (
                    ins_15_13 == 3'b000 ? `ori :
                    ins_15_13 == 3'b010 ? `ol :
                    ins_15_13 == 3'b110 ? `os : 7'b0
                  ) :
                  ins_1_0 == 2'b01 ? (
                    ins_15_13 == 3'b000 || ins_15_13 == 3'b010 ? `ori :
                    ins_15_13 == 3'b001 || ins_15_13 == 3'b101 ? `ojal :
                    ins_15_13 == 3'b011 ? (ins[11:7] == 5'b00010 ? `ori : `olui):
                    ins_15_13 == 3'b100 ? (ins_11_10 == 2'b11 ? `orr : `ori):
                    `ob
                  ) : (
                    ins_15_13 == 3'b000 ? `ori :
                    ins_15_13 == 3'b010 ? `ol :
                    ins_15_13 == 3'b100 ? (ins[6:2] == 5'b00000 ? `ojalr : `orr):
                    `os
                  );
  wire [4:0] rd = long ? ins[11:7] :
                  ins_1_0 == 2'b00 ? {2'b01, ins[4:2]} :
                  ins_1_0 == 2'b01 ? (
                    ins_15_13 == 3'b001 ? 5'b1 :
                    ins_15_13 == 3'b101 ? 5'b0 :
                    ins[15] ? {2'b01, ins[9:7]} :
                    ins[11:7]
                  ) : (
                    ins_15_13 == 3'b100 && ins[6:2] == 5'b0 ? {4'b0, ins[12]} :
                    ins[11:7]
                  );
  wire [4:0] rs1 =  long ? ins[19:15] :
                    ins_1_0 == 2'b00 ? (
                      ins_15_13 == 3'b000 ? 5'b10 : {2'b01, ins[9:7]}
                    ) :
                    ins_1_0 == 2'b01 ? (
                      ins_15_13 == 3'b010 ? 5'b0 :
                      ins[15] ? {2'b01, ins[9:7]} :
                      ins[11:7]
                    ) : (
                      ins_15_13 == 3'b000 ? ins[11:7] :
                      ins_15_13 == 3'b010 || ins_15_13 == 3'b110 ? 5'b10 :
                      ins[6:2] != 5'b00000 && ins[12] == 1'b0 ? 0 : ins[11:7]
                    );
  wire [4:0] rs2 =  long ? ins[24:20] :
                    ins_1_0 == 2'b10 ? ins[6:2] :
                    ins_1_0 == 2'b01 && ins[15:14] == 2'b11 ? 5'b0 : {2'b01, ins[4:2]};
  wire [31:0] immIext = long ? {{20{ins[31]}}, ins[31:20]} :
                        ins_1_0 == 2'b00 ? (
                         ins_15_13 == 3'b000 ? {22'b0, ins[10:7], ins[12:11], ins[5], ins[6], 2'b0} :
                         {25'b0, ins[5], ins[12:10], ins[6], 2'b0}
                        ) :
                        ins_1_0 == 2'b01 ?
                        (
                          ins_15_13 == 3'b011 ? {{23{ins[12]}}, ins[4:3], ins[5], ins[2], ins[6], 4'b0} :
                          {{27{ins[12]}}, ins[6:2]}
                          // ins_15_13 == 3'b000 || ins_15_13 == 3'b010 || ins_15_13 == 3'b100 
                        ) : (
                          ins_15_13 == 3'b000 ? {26'b0, ins[12], ins[6:2]} :
                          ins_15_13 == 3'b010 ? {24'b0, ins[3:2], ins[12], ins[6:4], 2'b0} :
                          32'b0
                        );
  wire [31:0] immSext = long ? {{20{ins[31]}}, ins[31:25], ins[11:7]} :
                        ins_1_0 == 2'b00 ? {25'b0, ins[5], ins[12:10], ins[6], 2'b0} : // sw
                                           {24'b0, ins[8:7], ins[12:9], 2'b0}; // swsp
  // wire [31:0] immBext = {{20{ins[31]}}, ins[7], ins[30:25], ins[11:8], 1'b0}; // offset
  // wire [31:0] immJext = {{12{ins[31]}}, ins[19:12], ins[20], ins[30:21], 1'b0};
  wire [31:0] immUext = long ? {ins[31:12], 12'b0} : {{15{ins[12]}}, ins[6:2], 12'b0};

  // instant wire to regfile
  assign get_id_1 = (op == `oauipc || op == `olui || op == `ojal) ? 0 : rs1;
  assign get_id_2 = (op == `oauipc || op == `olui || op == `ojal
                  || op == `ojalr || op == `ori || op == `ol) ? 0 : rs2;

  assign rs_Qdest = rob_free_id;
  assign lsb_Qdest = rob_free_id;

  // wire to_rs = op == `ojalr || op == `ob || op == `ori || op == `orr || op == `oauipc || op == `olui || op == `ojal;
  wire to_lsb = op == `os || op == `ol;
  wire to_rs = !to_lsb;

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
      if (is_ins && ins_addr != last_addr && !f_stall) begin
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
        rs_is_short <= !long;
        rs_op <=  long ? {ins[30], ins[14:12], ins[6:0]} :
                  ins_1_0 == 2'b10 ? (
                    ins_15_13 == 3'b000 ? {4'b0001, op} : // slli
                    {4'b0000, op} // add
                  ) :
                  ins_1_0 == 2'b01 ? (
                    ins_15_13 == 3'b100 ? (
                      ins_11_10 == 2'b00 ? {4'b0101, op} : // srli
                      ins_11_10 == 2'b01 ? {4'b1101, op} : // srai
                      ins_11_10 == 2'b10 ? {4'b0111, op} : ( // andi
                        ins_6_5 == 2'b00 ? {4'b1000, op} : // sub
                        ins_6_5 == 2'b01 ? {4'b0100, op} : // xor
                        ins_6_5 == 2'b01 ? {4'b0110, op} : // or
                        {4'b0111, op} // and
                      )
                    ) :
                    ins_15_13 == 3'b110 ? {4'b0000, op} : // beqz
                    ins_15_13 == 3'b111 ? {4'b0001, op} : // bnez
                    {4'b0000, op} // addi
                  ) : (
                    {4'b0000, op} // addi
                  );
        rs_imm <= (op == `oauipc || op == `olui) ? immUext : immIext;
        // rs_imm <= (op == `oauipc || op == `olui) ? immUext : op == `ojal ? immJext : immIext;
        // slli etc. is handled in alu
        // `orr, `ob have no imm
        // `ojalr is also this

        is_lsb <= to_lsb;
        lsb_op <= long ? {ins[14:12], ins[6:0]} : {3'b010, op};
        lsb_imm <= op == `ol ? immIext : immSext;

        r_is_ins <= 1;
        r_ins_pc <= ins_addr;
        // r_ins_already_done <= op == `ojal || op == `ojalr
        //                    || op == `oauipc || op == `olui;
        // corresponding to stat in rob
        // r_ins_already_done <= 0;
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