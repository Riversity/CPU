// Fetch instruction from instruction cache
module insfetch (
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,
  
  output reg  [31:0] PC, // all pc is from here

  // to/from mem manager or something
  output wire ask_for,
  input wire give_you,
  input wire [31:0] give_you_ins,  

  // TODO: c.add, PC + 2?
  input wire [1:0] ins_length,

  // to decoder
  output reg is_ins,
  output reg [31:0] ins_addr,
  output reg [31:0] ins,
  // from decoder
  input wire dc_stuck,
  input wire dc_clear,
  input wire [31:0] dc_new_pc,

  // from rob
  input wire rob_clear,
  input wire [31:0] new_pc
);
  reg stuck;
  wire [31:0] nx_PC = rob_clear ? new_pc : (dc_clear ? dc_new_pc : PC + ins_length);

endmodule