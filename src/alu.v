// ALU
`include "const.v"
module alu (
  input wire clk_in,

  input wire yes,
  input wire [10:0] op,
  input wire [31:0] v1,
  input wire [31:0] v2,
  // input wire [31:0] pc,
input wire [31:0] imm,
input wire [`ROB_R] in_rob_id,

output reg has_output,
output reg [`ROB_R] rob_id,
output reg [31:0] value
);

  always @(posedge clk_in) begin
    // TODO
  end
endmodule