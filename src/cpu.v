// RISCV32 CPU top module
// port modification allowed for debugging purposes
`include "const.v"
module cpu (
  input  wire        clk_in,      // system clock signal
  input  wire        rst_in,      // reset signal
  input  wire        rdy_in,      // ready signal, pause cpu when low

  input  wire [ 7:0] mem_din,     // data input bus
  output wire [ 7:0] mem_dout,    // data output bus
  output wire [31:0] mem_a,       // address bus (only 17:0 is used)
  output wire        mem_wr,      // write/read signal (1 for write)
  
  input  wire        io_buffer_full, // 1 if uart buffer is full

  output wire [31:0] dbgreg_dout     // cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

// rob & regfile
wire    [4:0] set_id;
wire   [31:0] set_val;
wire [`ROB_R] set_from_rob_id;
wire    [4:0] set_dep_id;
wire [`ROB_R] set_dep_Q;
wire [`ROB_R] get_rob_id_1;
wire          rob_avail_1;
wire   [31:0] rob_val_1;
wire [`ROB_R] get_rob_id_2;
wire          rob_avail_2;
wire   [31:0] rob_val_2;

wire is_commit;

// regfile & decode
wire    [4:0] get_id_1;
wire   [31:0] get_val_1;
wire          get_has_dep_1;
wire [`ROB_R] get_dep_1;
wire    [4:0] get_id_2;
wire   [31:0] get_val_2;
wire          get_has_dep_2;
wire [`ROB_R] get_dep_2;

// rob to all
wire rob_clear;
wire rob_empty;
wire rob_full;

regfile RegFile (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .set_id(set_id),
  .set_val(set_val),
  .set_from_rob_id(set_from_rob_id),
  .get_id_1(get_id_1),
  .get_val_1(get_val_1),
  .get_has_dep_1(get_has_dep_1),
  .get_dep_1(get_dep_1),
  .get_id_2(get_id_2),
  .get_val_2(get_val_2),
  .get_has_dep_2(get_has_dep_2),
  .get_dep_2(get_dep_2),
  .set_dep_id(set_dep_id),
  .set_dep_Q(set_dep_Q),
  .rob_clear(rob_clear),
  .get_rob_id_1(get_rob_id_1),
  .rob_avail_1(rob_avail_1),
  .rob_val_1(rob_val_1),
  .get_rob_id_2(get_rob_id_2),
  .rob_avail_2(rob_avail_2),
  .rob_val_2(rob_val_2),
  .is_commit(is_commit)
);

// rob & decoder
wire is_r_ins;
// wire [31:0] r_ins;
wire [31:0] r_ins_pc;
wire [4:0] r_ins_rd;
wire r_ins_pred_jmp;
wire [31:0] r_another_addr;
wire [1:0] r_ins_type;
wire [`ROB_R] rob_free_id;

// rob & lsb
wire [`ROB_R] rob_head_id;
wire lsb_has_output;
wire [`ROB_R] lsb_rob_id;
wire [31:0] lsb_output;

// rob & rs
wire rs_has_output;
wire [`ROB_R] rs_rob_id;
wire [31:0] rs_output;

// rob & insfetch
wire [31:0] rob_new_pc;
wire is_b_res;
wire [7:0] b_res_pc_part;
wire b_res_jmp;

rob RoB (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .rob_clear(rob_clear),
  .rob_empty(rob_empty),
  .rob_full(rob_full),
  .new_pc(rob_new_pc),
  .is_ins(is_r_ins),
  // .ins(r_ins),
  .ins_pc(r_ins_pc),
  // .ins_already_done(r_ins_already_done),
  // .ins_result(r_ins_result),
  .ins_rd(r_ins_rd),
  .ins_pred_jmp(r_ins_pred_jmp),
  .another_addr(r_another_addr),
  .ins_type(r_ins_type),
  .rob_free_id(rob_free_id),
  .rob_head_id(rob_head_id),
  .lsb_has_output(lsb_has_output),
  .lsb_rob_id(lsb_rob_id),
  .lsb_output(lsb_output),
  .rs_has_output(rs_has_output),
  .rs_rob_id(rs_rob_id),
  .rs_output(rs_output),
  .set_id(set_id),
  .set_val(set_val),
  .set_from_rob_id(set_from_rob_id),
  .set_dep_id(set_dep_id),
  .set_dep_Q(set_dep_Q),
  .get_rob_id_1(get_rob_id_1),
  .rob_avail_1(rob_avail_1),
  .rob_val_1(rob_val_1),
  .get_rob_id_2(get_rob_id_2),
  .rob_avail_2(rob_avail_2),
  .rob_val_2(rob_val_2),
  .is_b_res(is_b_res),
  .b_res_pc_part(b_res_pc_part),
  .b_res_jmp(b_res_jmp),
  .is_commit(is_commit)
);

// mem & inscache
wire is_fetch;
wire [31:0] fetch_addr;
wire is_back;
wire [31:0] back_ins;

// mem & lsb
wire mem_res_avail;
wire [31:0] mem_res;
wire mem_stuck;
wire is_io;
wire is_store;
wire [31:0] io_addr;
wire [31:0] io_data;
wire [2:0] io_op;

// inscache & insfetch
wire [31:0] out_pc;
wire ask_for;
wire give_you;
wire [31:0] g_ins;

memctrl MemCtrl (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .is_fetch(is_fetch),
  .fetch_addr(fetch_addr),
  .is_back(is_back),
  .back_ins(back_ins),
  .mem_res_avail(mem_res_avail),
  .mem_res(mem_res),
  .working(mem_stuck),
  .is_io(is_io),
  .is_store(is_store),
  .io_addr(io_addr),
  .io_data(io_data),
  .io_op(io_op),
  .io_buffer_full(io_buffer_full),
  .addr(mem_a),
  .is_write(mem_wr),
  .write(mem_dout),
  .read(mem_din),
  .rob_clear(rob_clear)
);

inscache InsCache (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .is_fetch(ask_for),
  .pc(out_pc),
  .is_ret(give_you),
  .ret(g_ins),
  .is_send_mem(is_fetch),
  .send_addr(fetch_addr),
  .is_mem_back(is_back),
  .back_ins(back_ins)
);

// insfetch & decoder
wire is_dc_ins;
wire [31:0] dc_ins_addr;
wire [31:0] dc_ins;
wire pred_jmp;
wire [31:0] another_branch;
wire rob_rs_slb_full;

// insfetch && rs
wire cancel_stuck;
wire [31:0] jalr_new_pc;

insfetch InsFetch (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .out_PC(out_pc),
  .ask_for(ask_for),
  .give_you(give_you),
  .g_ins(g_ins),
  .is_ins(is_dc_ins),
  .ins_addr(dc_ins_addr),
  .ins(dc_ins),
  .pred_jmp(pred_jmp),
  .another_branch(another_branch),
  .rob_rs_slb_full(rob_rs_slb_full),
  .rob_clear(rob_clear),
  .rob_new_pc(rob_new_pc),
  .cancel_stuck(cancel_stuck),
  .jalr_new_pc(jalr_new_pc),
  .is_res(is_b_res),
  .res_pc_part(b_res_pc_part),
  .res_jmp(b_res_jmp)
);

// decode & rs
wire rs_full;
wire is_rs;
wire [31:0]   rs_pc;
wire [10:0]   rs_op;
wire [31:0]   rs_imm;
wire          rs_iQi;
wire [`ROB_R] rs_Qi;
wire          rs_iQj;
wire [`ROB_R] rs_Qj;
wire [`ROB_R] rs_Qdest;
wire [31:0]   rs_Vi;
wire [31:0]   rs_Vj;

// decode & lsb
wire lsb_full;
wire is_lsb;
wire [9:0]    lsb_op;
wire [31:0]   lsb_imm;
wire          lsb_iQi;
wire [`ROB_R] lsb_Qi;
wire          lsb_iQj;
wire [`ROB_R] lsb_Qj;
wire [`ROB_R] lsb_Qdest;
wire [31:0]   lsb_Vi;
wire [31:0]   lsb_Vj;

decode Decode (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .is_ins(is_dc_ins),
  .ins_addr(dc_ins_addr),
  .ins(dc_ins),
  .pred_jmp(pred_jmp),
  .pred_another(another_branch),
  .f_stall(rob_rs_slb_full),
  .get_id_1(get_id_1),
  .get_val_1(get_val_1),
  .get_has_dep_1(get_has_dep_1),
  .get_dep_1(get_dep_1),
  .get_id_2(get_id_2),
  .get_val_2(get_val_2),
  .get_has_dep_2(get_has_dep_2),
  .get_dep_2(get_dep_2),
  .rs_full(rs_full),
  .is_rs(is_rs),
  .rs_pc(rs_pc),
  .rs_op(rs_op),
  .rs_imm(rs_imm),
  .rs_iQi(rs_iQi),
  .rs_Qi(rs_Qi),
  .rs_iQj(rs_iQj),
  .rs_Qj(rs_Qj),
  .rs_Qdest(rs_Qdest),
  .rs_Vi(rs_Vi),
  .rs_Vj(rs_Vj),
  .lsb_full(lsb_full),
  .is_lsb(is_lsb),
  .lsb_op(lsb_op),
  .lsb_imm(lsb_imm),
  .lsb_iQi(lsb_iQi),
  .lsb_Qi(lsb_Qi),
  .lsb_iQj(lsb_iQj),
  .lsb_Qj(lsb_Qj),
  .lsb_Qdest(lsb_Qdest),
  .lsb_Vi(lsb_Vi),
  .lsb_Vj(lsb_Vj),
  .rob_full(rob_full),
  .rob_clear(rob_clear),
  .rob_free_id(rob_free_id),
  .r_is_ins(is_r_ins),
  // .r_ins(r_ins),
  .r_ins_pc(r_ins_pc),
  // .r_ins_already_done(r_ins_already_done),
  // .r_ins_result(r_ins_result),
  .r_ins_rd(r_ins_rd),
  .r_ins_pred_jmp(r_ins_pred_jmp),
  .r_another_addr(r_another_addr),
  .r_ins_type(r_ins_type)
);

rs RS (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .rob_clear(rob_clear),
  .is_dc(is_rs),
  .dc_pc(rs_pc),
  .dc_op(rs_op),
  .dc_imm(rs_imm),
  .dc_iQi(rs_iQi),
  .dc_Qi(rs_Qi),
  .dc_iQj(rs_iQj),
  .dc_Qj(rs_Qj),
  .dc_Qdest(rs_Qdest),
  .dc_Vi(rs_Vi),
  .dc_Vj(rs_Vj),
  .rs_full(rs_full),
  .is_lsb(lsb_has_output),
  .lsb_rob_id(lsb_rob_id),
  .lsb_res(lsb_output),
  .rs_has_output(rs_has_output),
  .rs_rob_id(rs_rob_id),
  .rs_output(rs_output),
  .has_jalr_new_pc(cancel_stuck),
  .jalr_new_pc(jalr_new_pc)
);

lsb LSB (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .rob_clear(rob_clear),
  .rob_empty(rob_empty),
  .rob_head_id(rob_head_id),
  .is_dc(is_lsb),
  .dc_op(lsb_op),
  .dc_imm(lsb_imm),
  .dc_iQi(lsb_iQi),
  .dc_Qi(lsb_Qi),
  .dc_iQj(lsb_iQj),
  .dc_Qj(lsb_Qj),
  .dc_Qdest(lsb_Qdest),
  .dc_Vi(lsb_Vi),
  .dc_Vj(lsb_Vj),
  .lsb_full(lsb_full),
  .mem_res_avail(mem_res_avail),
  .mem_res(mem_res),
  .mem_stuck(mem_stuck),
  .is_io(is_io),
  .is_store(is_store),
  .io_addr(io_addr),
  .io_data(io_data),
  .io_op(io_op),
  .is_rs(rs_has_output),
  .rs_rob_id(rs_rob_id),
  .rs_res(rs_output),
  .lsb_has_output(lsb_has_output),
  .lsb_rob_id(lsb_rob_id),
  .lsb_output(lsb_output)
);

endmodule