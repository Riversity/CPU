// ALU
`include "const.v"
module alu (
  input wire clk_in,

  input wire yes,
  input wire [10:0] op,
  input wire [31:0] v1,
  input wire [31:0] v2,
  input wire [31:0] pc,
  input wire is_short,
  input wire [31:0] imm,
  input wire [`ROB_R] in_rob_id,

  output reg has_output,
  output reg [`ROB_R] rob_id,
  output reg [31:0] value,
  output reg has_new_pc,
  output reg [31:0] new_pc
);

  always @(posedge clk_in) begin
    if (yes != 1) begin
      has_output <= 0;
      has_new_pc <= 0;
    end
    else begin
      has_output <= 1;
      has_new_pc <= op[6:0] == `ojalr;
      rob_id <= in_rob_id;
      case (op[6:0])
        `olui: value <= imm;
        `oauipc: value <= imm + pc;
        `ojal: value <= pc + is_short ? 2 : 4;
        `ojalr: begin value <= pc + is_short ? 2 : 4; new_pc <= (v1 + imm) & ~1; end
        `ob: case (op[9:7])
          3'b000: value <= v1 == v2;
          3'b001: value <= v1 != v2;
          3'b100: value <= $signed(v1) < $signed(v2);
          3'b101: value <= $signed(v1) >= $signed(v2);
          3'b110: value <= v1 < v2;
          3'b111: value <= v1 >= v2;
        endcase
        //`ol `os
        `ori: case (op[9:7])
          3'b000: value <= v1 + imm;
          3'b010: value <= $signed(v1) < $signed(imm);
          3'b011: value <= v1 < imm;
          3'b100: value <= v1 ^ imm;
          3'b110: value <= v1 | imm;
          3'b111: value <= v1 & imm;
          3'b001: value <= v1 << imm[4:0];
          3'b101: case (op[10])
            0: value <= v1 >> imm[4:0];
            1: value <= $signed(v1) >>> imm[4:0];
          endcase
        endcase
        `orr: case (op[9:7])
          3'b000: case (op[10])
            0: value <= v1 + v2;
            1: value <= v1 - v2;
          endcase
          3'b001: value <= v1 << v2[4:0];
          3'b010: value <= $signed(v1) < $signed(v2);
          3'b011: value <= v1 < v2;
          3'b100: value <= v1 ^ v2;
          3'b101: case (op[10])
            0: value <= v1 >> v2[4:0];
            1: value <= $signed(v1) >>> v2[4:0];
          endcase
          3'b110: value <= v1 | v2;
          3'b111: value <= v1 & v2;
        endcase
      endcase
    end
  end
endmodule