// Fetch instruction from instruction cache
`include "const.v"
module insfetch (
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  output wire [31:0] out_PC,

  // to/from mem manager or something
  output wire ask_for,
  input wire give_you,
  input wire [31:0] give_you_ins,  

  // TODO: c.add, PC + 2? // Judged inside
  // input wire [1:0] offset,

  // to decoder
  output reg is_ins,
  output reg [31:0] ins_addr,
  output reg [31:0] ins,
  // from decoder
  input wire rob_rs_slb_full,
  // input wire dc_stuck,
  // input wire dc_clear,
  // input wire [31:0] dc_new_pc,

  // from rob
  input wire rob_clear,
  input wire [31:0] rob_new_pc,
  input wire cancel_stuck
);

  reg stuck;
  reg [31:0] PC; // all pc is from here

  assign out_PC = PC;
  assign ask_for = !stuck;

  always @(posedge clk_in) begin : INSFETCH
    if (rst_in) begin
      PC <= 0;
      stuck <= 0;
      is_ins <= 0;
      ins_addr <= 0;
      ins <= 0;
    end
    else if (!rdy_in) begin end
    else if (rob_clear) begin
      PC <= rob_new_pc;
      stuck <= 0;
      is_ins <= 0;
      ins_addr <= 0;
      ins <= 0;
    end
    else if (stuck) begin
      is_ins <= 0;
      if (cancel_stuck) begin
        stuck <= 0;
        PC <= rob_new_pc;
      end
    end
    else begin // not stuck
      if (give_you && !rob_rs_slb_full) begin // has input, not full
        is_ins <= 1;
        if (give_you_ins == 32'h0ff00513) begin // HALT
          stuck <= 1;
          // PC <= PC;
        end
        if (give_you_ins[6:0] == `ojalr) begin
          stuck <= 1;
          PC <= rob_new_pc;
        end
        else if (give_you_ins[6:0] == `ojal) begin
          PC <= PC + {{12{give_you_ins[31]}}, give_you_ins[19:12], give_you_ins[20], give_you_ins[30:21], 1'b0};
        end
        else begin
          PC <= PC + (give_you_ins[1:0] == 2'b11) ? 4 : 2;
          // judge c. by last 2 bit
        end
      end
    end
  end
endmodule