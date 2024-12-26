// Instruction Cache
`include "const.v"
module inscache (
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // to/from insfetch
  input wire is_fetch,
  input wire [31:0] pc,
  output wire is_ret,
  output wire [31:0] ret,

  // to/from mem
  output reg is_send_mem,
  output reg [31:0] send_addr,
  input wire is_mem_back,
  input wire [31:0] back_ins
);

  // addr is 17 bit long, last 1 bit is 0
  // TAG 16:10, DATA & POS 9:1
  reg [31:0] data[0:511];
  reg [6:0] tag[0:511];
  reg avail[0:511];

  reg working;

  wire [8:0] index = pc[9:1];
  wire just_from_mem = is_mem_back && send_addr == pc;

  assign is_ret = is_fetch && ((avail[index] && pc[16:10] == tag[index]) || just_from_mem);
  // hit or just from mem
  assign ret = just_from_mem ? back_ins : data[index];

  always @(posedge clk_in) begin : INSCACHE
    integer i;
    if (rst_in) begin
      is_send_mem <= 0;
      send_addr <= 0;
      working <= 0;
      for (i = 0; i < 512; i = i + 1) begin
        data[i] <= 0;
        tag[i] <= 0;
        avail[i] <= 0;
      end
    end
    else if (!rdy_in) begin end
    else begin
      if (working) begin
        if (is_mem_back) begin
          is_send_mem <= 0;
          working <= 0;
          data[send_addr[9:1]] <= back_ins;
          tag[send_addr[9:1]] <= send_addr[16:10];
          avail[send_addr[9:1]] <= 1;
        end
      end
      else begin // mem not working
        if (is_fetch) begin
          is_send_mem <= 1;
          send_addr <= pc;
          working <= 1;
        end
      end
    end
  end
endmodule