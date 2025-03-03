// Load-Store Buffer
`include "const.v"
module lsb (
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // from ROB
  input wire rob_clear,
  input wire rob_empty,
  input wire [`ROB_R] rob_head_id, // store only when rob not empty && head of rob

  // from decoder
  input wire is_dc,
  input wire [9:0]   dc_op, // {ins[14:12], ins[6:0]}
  input wire [31:0]   dc_imm,
  input wire          dc_iQi,
  input wire [`ROB_R] dc_Qi,
  input wire          dc_iQj,
  input wire [`ROB_R] dc_Qj,
  input wire [`ROB_R] dc_Qdest,
  input wire [31:0]   dc_Vi,
  input wire [31:0]   dc_Vj,

  output reg lsb_full,

  // from mem
  input wire mem_res_avail,
  input wire [31:0] mem_res,
  input wire mem_stuck,
  output wire is_io,
  output reg is_store, // 0 load 1 store
  output reg [31:0] io_addr,
  output reg [31:0] io_data,
  output reg [2:0] io_op, // ins[14:12]

  // from rs
  input wire is_rs,
  input wire [`ROB_R] rs_rob_id,
  input wire [31:0] rs_res,

  // to rob
  output wire lsb_has_output,
  output wire [`ROB_R] lsb_rob_id,
  output wire [31:0] lsb_output
);

  reg [`LSB_R] head;
  reg [`LSB_R] tail;
  reg [`LSB_BIT:0] size;
  wire [`LSB_BIT:0] nx_size = (is_dc && !(working && mem_res_avail)) ? size + 1 : (!is_dc && working && mem_res_avail) ? size - 1 : size;
  wire nx_full = nx_size == `LSB || nx_size + 1 == `LSB;
  // wire [`LSB_R] nx_head = head + 1;
  // wire [`LSB_R] nx_tail = tail + 1;

  reg [9:0]    op  [`LSB_A];
  reg [31:0]   imm [`LSB_A];
  reg          iQ1 [`LSB_A]; // iQ == 1 <=> Q == -1 <=> no dependency
  reg [`ROB_R] Q1  [`LSB_A];
  reg          iQ2 [`LSB_A]; // iQ == 1 <=> Q == -1 <=> no dependency
  reg [`ROB_R] Q2  [`LSB_A];
  reg [31:0]   V1  [`LSB_A];
  reg [31:0]   V2  [`LSB_A];
  reg [`ROB_R] Qdes[`LSB_A];

  reg working;
  assign is_io = working;

  // output
  assign lsb_has_output = mem_res_avail;
  assign lsb_rob_id = Qdes[head];
  assign lsb_output = mem_res;

  wire [31:0] tmp_addr = V1[head] + imm[head];

  always @(posedge clk_in) begin : LSB
    integer i;
    if (rst_in || rob_clear) begin
      head <= 0;
      tail <= 0;
      size <= 0;
      working <= 0;
      lsb_full <= 0;
      for (i = 0; i < `LSB; i = i + 1) begin
        op[i] <= 0;
        imm[i] <= 0;
        iQ1[i] <= 1;
        Q1[i] <= 0;
        iQ2[i] <= 1;
        Q2[i] <= 0;
        V1[i] <= 0;
        V2[i] <= 0;
        Qdes[i] <= 0;
      end
    end
    else if (!rdy_in) begin end
    else begin
      size <= nx_size;
      lsb_full <= nx_full;
      // insert
      if (is_dc) begin
        // if (size > 0 && tail == head) $display("lsb fucked! size: %0x", size);
        op[tail] <= dc_op;
        imm[tail] <= dc_imm;
        Q1[tail] <= dc_Qi;
        Q2[tail] <= dc_Qj;
        iQ1[tail] <= dc_iQi || (lsb_has_output && lsb_rob_id == dc_Qi) || (is_rs && rs_rob_id == dc_Qi);
        iQ2[tail] <= dc_iQj || (lsb_has_output && lsb_rob_id == dc_Qj) || (is_rs && rs_rob_id == dc_Qj);
        V1[tail] <= dc_iQi ? dc_Vi : (lsb_has_output && lsb_rob_id == dc_Qi) ? lsb_output : (is_rs && rs_rob_id == dc_Qi) ? rs_res : {32{1'bx}};
        V2[tail] <= dc_iQj ? dc_Vj : (lsb_has_output && lsb_rob_id == dc_Qj) ? lsb_output : (is_rs && rs_rob_id == dc_Qj) ? rs_res : {32{1'bx}};
        Qdes[tail] <= dc_Qdest;
        tail <= tail + 1;
      end
      // update
      for (i = 0; i < `LSB; i = i + 1) begin
        if (!(is_dc && i == tail)) begin
          if (lsb_has_output && !iQ1[i] && lsb_rob_id == Q1[i]) begin
            iQ1[i] <= 1;
            V1[i] <= lsb_output;
          end
          if (lsb_has_output && !iQ2[i] && lsb_rob_id == Q2[i]) begin
            iQ2[i] <= 1;
            V2[i] <= lsb_output;
          end
          if (is_rs && !iQ1[i] && rs_rob_id == Q1[i]) begin
            iQ1[i] <= 1;
            V1[i] <= rs_res;
          end
          if (is_rs && !iQ2[i] && rs_rob_id == Q2[i]) begin
            iQ2[i] <= 1;
            V2[i] <= rs_res;
          end
        end
      end
      // work
      // $display("head:%0x size:%0x wo:%0x ms:%0x iqi:%0x iqj:%0x addr:%0x rhi:%0x qdes:%0x", head, size, working, mem_stuck, iQ1[head], iQ2[head], tmp_addr, rob_head_id, Qdes[head]);
      if (size != 0 && working == 0 && !mem_stuck && iQ1[head] && iQ2[head] && ((op[head][6:0] == `ol && tmp_addr[17:16] != 2'b11) || (rob_head_id == Qdes[head]))) begin
        working <= 1;
        is_store <= op[head][6:0] == `os;
        io_addr <= tmp_addr;
        io_data <= V2[head];
        io_op <= op[head][9:7];
      end
      // free
      if (working && mem_res_avail) begin // caution: rob_clear while working
        head <= head + 1;
        working <= 0;
      end
    end
  end
endmodule