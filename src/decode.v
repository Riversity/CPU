// Instruction Decoder
module decode(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // from ins fetch
  input wire is_ins,
  input wire [31:0] ins_addr,
  input wire [31:0] ins,

  // to ins fetch
  output wire stall,
  output wire [31:0] new_pc
);
  wire [6:0] op = ins[6:0];
  wire [4:0] rd = ins[11:7];
  wire [4:0] rs1 = ins[19:15];
  wire [4:0] rs2 = ins[24:20];

endmodule