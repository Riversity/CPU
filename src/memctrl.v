// Memory Controller
// Mem, what can I say?
`include "const.v"
module memctrl (
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // to/from inscache
  input wire is_fetch,
  input wire [31:0] fetch_addr,
  output wire is_back,
  output wire [31:0] back_ins,

  // to/from lsb
  output wire mem_res_avail,
  output wire [31:0] mem_res,
  output wire working, // to mem_stuck

  input wire is_io,
  input wire is_store, // 0 load 1 store
  input wire [31:0] io_addr,
  input wire [31:0] io_data,
  input wire [2:0] io_op, // ins[14:12]

  // with ram
  input wire io_buffer_full, // todo
  output reg [31:0] addr,
  output reg is_write, // reversed from ram notation!
  output reg [7:0] write,
  input wire [7:0] read
);

  reg [31:0] data;
  reg busy;
  assign working = busy;

  reg [1:0] stat; // 00 load 01 store 10 ins
  reg [2:0] cur; // current position, 0, 1, 2, 3, 4 // because read is available 2 cycles later

  assign is_back = busy && stat[1] && (cur == 0);
  assign back_ins = {data[31:8], read};
  assign mem_res_avail = busy && (!stat[1]) && (cur == 0);
  assign mem_res = io_op == 3'b000 ? {{24{read[7]}}, read} : io_op == 3'b001 ? {{16{data[15]}}, data[15:8], read} : io_op == 3'b100 ? {{24'b0}, read} : io_op == 3'b101 ? {{16'b0}, data[15:8], read} : {data[31:8], read};
  // sign extension

  always @(posedge clk_in) begin : MEMCTRL
    if (rst_in) begin
      data <= 0;
      addr <= 0;
      is_write <= 0; // load
      write <= 0;
      busy <= 0;
      stat <= 0;
      cur <= 3;
    end
    else if (!rdy_in) begin end
    else begin
      if (!busy && !io_buffer_full) begin
        if (is_io) begin // ls priority
          busy <= 1;
          stat <= {1'b0, is_store};
          // first cycle rush
          if (is_store) begin
            is_write <= 1;
            case (io_op[1:0])
              2'b00: begin cur <= 0; addr <= io_addr; write <= io_data[7:0]; end
              2'b01: begin cur <= 1; addr <= io_addr + 2; write <= io_data[15:8]; end
              2'b10: begin cur <= 3; addr <= io_addr + 3; write <= io_data[31:24]; end
            endcase
          end
          else begin
            is_write <= 0;
            case (io_op[1:0])
              2'b00: begin cur <= 1; addr <= io_addr; end
              2'b01: begin cur <= 2; addr <= io_addr + 2; end
              2'b10: begin cur <= 4; addr <= io_addr + 3; end
            endcase
          end
        end
        else if (is_fetch) begin
          busy <= 1;
          stat <= 2'b10;
          is_write <= 0;
          cur <= 4;
          addr <= fetch_addr + 3; 
        end
        else begin
          data <= 0;
          addr <= 0;
          is_write <= 0;
          cur <= 0;
        end
      end
      else begin
        // work
        if (cur == 0) begin
          busy <= 0;
          data <= 0;
          is_write <= 0;
          cur <= 4;
        end
        else if (!io_buffer_full) begin
          cur <= cur - 1;
          if (stat[0]) begin // write
            case (cur)
              3: write <= io_data[23:16];
              2: write <= io_data[15:8];
              1: write <= io_data[7:0];
            endcase
            is_write <= 1;
            addr <= addr - 1;
          end
          else begin
            case (cur)
              3: data[31:24] <= read;
              2: data[23:16] <= read;
              1: data[15:8] <= read;
            endcase
            is_write <= 0;
            addr <= addr - 1;
          end
        end
      end
    end
  end
endmodule