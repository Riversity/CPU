`include "const.v"

module foolish_decode(
  input wire clk_in,

  input wire [31:0] ins,
  input wire [31:0] pc,

  output reg [5:0] op,
  output reg [4:0] rd,
  output reg [4:0] rs1,
  output reg [4:0] rs2,
  output reg [31:0] imm
);

  always @(posedge clk_in) begin
    rd = ins[11:7];
    rs1 = ins[19:15];
    rs2 = ins[24:20];

    case (ins[6:0])
      7'b0110111: begin
        op = `LUI;
        imm = {ins[31:12], 12'b0};
      end
      7'b0010111: begin
        op = `AUIPC;
        imm = {ins[31:12], 12'b0};
      end
      7'b1101111: begin
        op = `JAL;
        imm = {{12{ins[31]}}, ins[19:12], ins[20], ins[30:21], 1'b0};
      end
      7'b1100111: begin
        op = `JALR;
        imm = {{20{ins[31]}}, ins[31:20]};
      end
      7'b1100011: begin
        imm = {{20{ins[31]}}, ins[7], ins[30:25], ins[11:8], 1'b0};
        case (ins[14:12])
          3'b000: begin op = `BEQ; end
          3'b001: begin op = `BNE; end
          3'b100: begin op = `BLT; end
          3'b101: begin op = `BGE; end
          3'b110: begin op = `BLTU; end
          3'b111: begin op = `BGEU; end
        endcase
      end
      7'b0000011: begin
        imm = {{20{ins[31]}}, ins[31:20]};
        case (ins[14:12])
          3'b000: begin op = `LB; end
          3'b001: begin op = `LH; end
          3'b010: begin op = `LW; end
          3'b100: begin op = `LBU; end
          3'b101: begin op = `LHU; end
        endcase
      end
      7'b0100011: begin
        imm = {{20{ins[31]}}, ins[31:25], ins[11:7]};
        case (ins[14:12])
          3'b000: begin op = `SB; end
          3'b001: begin op = `SH; end
          3'b010: begin op = `SW; end
        endcase
      end
      7'b0010011: begin
        imm = {{20{ins[31]}}, ins[31:20]};
        case (ins[14:12])
          3'b000: begin op = `ADDI; end
          3'b010: begin op = `SLTI; end
          3'b011: begin op = `SLTIU; end
          3'b100: begin op = `XORI; end
          3'b110: begin op = `ORI; end
          3'b111: begin op = `ANDI; end
          3'b001: begin
            op = `SLLI;
            imm = ins[24:20];
          end
          3'b101: begin
            op = ins[30] ? 6'd26 : 6'd25; // SRAI SRLI
            imm = ins[24:20];
          end
        endcase
      end
      7'b0110011: begin
        case (ins[14:12])
          3'b000: op = ins[30] ? 6'd28 : 6'd27; // SUB ADD
          3'b001: begin op = `SLL; end
          3'b010: begin op = `SLT; end
          3'b011: begin op = `SLTU; end
          3'b100: begin op = `XOR; end 
          3'b101: op = ins[30] ? 6'd34 : 6'd33; // SRA SRL
          3'b110: begin op = `OR; end
          3'b111: begin op = `AND; end
        endcase
      end
    endcase
    if(ins == 32'h0ff00513) begin op = `HALT; end
  end
endmodule