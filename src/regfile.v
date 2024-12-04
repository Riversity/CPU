// Register File
`include "const.v"

module regfile (
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // write value
  input wire     [4:0] set_id,
  input wire    [31:0] set_val,

  // read value
  input wire     [4:0] get_id_1,
  output wire   [31:0] get_val_1,
  output wire          get_has_dep_1,
  output wire [`ROB_R] get_dep_1,
  input wire     [4:0] get_id_2,
  output wire   [31:0] get_val_2,
  output wire          get_has_dep_2,
  output wire [`ROB_R] get_dep_2,

  // from ROB
  // set dep
  input wire     [4:0] set_dep_id,
  input wire  [`ROB_R] set_dep_Q,

  input wire rob_clear,

  // to ROB
  output wire [`ROB_R] get_rob_id_1,
  input wire           rob_avail_1,
  input wire    [31:0] rob_val_1,
  output wire [`ROB_R] get_rob_id_2,
  input wire           rob_avail_2,
  input wire    [31:0] rob_val_2
);

  reg [31:0]  REGS[0:31];
  reg         BUSY[0:31];
  reg [`ROB_R] DEP[0:31];

  // bind values
  wire has_dep_1 = BUSY[get_id_1] || set_dep_id && set_dep_id == get_id_1; // new dependencies!
  wire has_dep_2 = BUSY[get_id_2] || set_dep_id && set_dep_id == get_id_2;
  assign get_val_1 = has_dep_1 ? rob_val_1 : REGS[get_id_1];
  assign get_val_2 = has_dep_2 ? rob_val_2 : REGS[get_id_2];
  assign get_has_dep_1 = has_dep_1 && !rob_avail_1;
  assign get_has_dep_2 = has_dep_2 && !rob_avail_2;
  assign get_dep_1 = set_dep_id == get_id_1 ? set_dep_Q : DEP[get_id_1];
  assign get_dep_2 = set_dep_id == get_id_2 ? set_dep_Q : DEP[get_id_2];
  assign get_rob_id_1 = get_dep_1;
  assign get_rob_id_2 = get_dep_2;

  always @(posedge clk_in) begin : REGFILE
    integer i;
    if (rst_in) begin
      for (i = 0; i < 32; i = i + 1) begin
        REGS[i] <= 0;
        DEP[i] <= 0;
        BUSY[i] <= 0;
      end
    end
    else if (!rdy_in) begin end
    else if (rob_clear) begin
      for (i = 0; i < 32; i = i + 1) begin
        DEP[i] <= 0;
        BUSY[i] <= 0;
      end
    end
    else begin
      if (set_id) begin
        REGS[set_id] <= set_val;
      end
      if (set_dep_id) begin
        BUSY[set_dep_id] <= 1;
        DEP[set_dep_id] <= set_dep_Q;
      end
    end
  end
endmodule