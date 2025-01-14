// Fetch instruction from instruction cache
`include "const.v"
module insfetch (
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // to/from inscache
  output wire [31:0] out_PC,
  output wire ask_for,
  input wire give_you,
  input wire [31:0] g_ins,  

  // c.add, PC + 2 : Judged inside
  // input wire [1:0] offset,

  // to decoder
  output reg is_ins,
  output reg [31:0] ins_addr,
  output reg [31:0] ins,
  output reg pred_jmp,
  output reg [31:0] another_branch,

  // from decoder
  input wire rob_rs_slb_full,
  // input wire dc_stuck,
  // input wire dc_clear,
  // input wire [31:0] dc_new_pc,

  // from rob
  input wire rob_clear,
  input wire [31:0] rob_new_pc,

  // from rs(alu)
  input wire cancel_stuck,
  input wire [31:0] jalr_new_pc,

  // from rob predictor res
  input wire is_res,
  input wire [7:0] res_pc_part, // pc[8:1]
  input wire res_jmp
);

  reg stuck;
  reg [31:0] PC; // all pc is from here

  assign out_PC = PC;
  assign ask_for = !stuck;

  reg [1:0] predictor[255:0];
  wire pred = (g_ins[6:0] == `ob || g_ins[1:0] == 2'b01 && g_ins[15:14] == 2'b11) && predictor[PC[8:1]][1];
  wire [31:0] nu_jmp_PC = PC + ((g_ins[1:0] == 2'b11) ? 4 : 2);
  // judge c. by last 2 bit
  wire [31:0] da_jmp_PC = PC + (g_ins[6:0] == `ob ? {{20{g_ins[31]}}, g_ins[7], g_ins[30:25], g_ins[11:8], 1'b0} : {{24{g_ins[12]}}, g_ins[6:5], g_ins[2], g_ins[11:10], g_ins[4:3], 1'b0});

  always @(posedge clk_in) begin : INSFETCH
    integer i;
    if (rst_in) begin
      PC <= 0;
      stuck <= 0;
      is_ins <= 0;
      ins_addr <= 0;
      ins <= 0;
      for (i = 0; i < 256; i = i + 1) begin
        predictor[i] = 2'b10;
      end
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
        PC <= jalr_new_pc;
      end
    end
    else begin // not stuck
      if (give_you && !rob_rs_slb_full) begin // has input, not full
        is_ins <= 1;
        ins_addr <= PC;
        ins <= g_ins;

        // if (g_ins == 32'h0ff00513) begin // HALT
        //   stuck <= 1;
        // end
        if (g_ins[6:0] == `ojalr) begin
          stuck <= 1;
        end
        else if (g_ins[1:0] == 2'b10 && g_ins[15:13] == 3'b100 && g_ins[6:2] == 5'b0) begin
          stuck <= 1;
        end
        else if (g_ins[6:0] == `ojal) begin
          PC <= PC + {{12{g_ins[31]}}, g_ins[19:12], g_ins[20], g_ins[30:21], 1'b0};
        end
        else if (g_ins[1:0] == 2'b01 && g_ins[14:13] == 2'b01) begin // c.j c.jal
          PC <= PC + {{21{g_ins[12]}}, g_ins[8], g_ins[10:9], g_ins[6],
                      g_ins[7], g_ins[2], g_ins[11], g_ins[5:3], 1'b0};
        end
        else begin
          pred_jmp <= pred;
          PC <= pred ? da_jmp_PC : nu_jmp_PC;
          another_branch <= (!pred) ? da_jmp_PC : nu_jmp_PC;
        end
      end
      if (is_res) begin
        if (res_jmp) predictor[res_pc_part] <= predictor[res_pc_part] == 2'b11 ? 2'b11 : predictor[res_pc_part] + 1;
        else predictor[res_pc_part] <= predictor[res_pc_part] == 2'b00 ? 2'b00 : predictor[res_pc_part] - 1;
      end
    end
  end
endmodule