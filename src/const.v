`define ROB_BIT 6
`define ROB (1 << `ROB_BIT)
`define ROB_R `ROB_BIT-1:0
`define ROB_A 0:`ROB-1

`define RS_BIT 4
`define RS (1 << `RS_BIT)
`define RS_R `RS_BIT-1:0
`define RS_A 0:`RS-1

`define LSB_BIT 4
`define LSB (1 << `LSB_BIT)
`define LSB_R `LSB_BIT-1:0
`define LSB_A 0:`LSB-1

`define LUI   6'd0
`define AUIPC 6'd1
`define JAL   6'd2
`define JALR  6'd3
`define BEQ   6'd4
`define BNE   6'd5
`define BLT   6'd6
`define BGE   6'd7
`define BLTU  6'd8
`define BGEU  6'd9
`define LB    6'd10
`define LH    6'd11
`define LW    6'd12
`define LBU   6'd13
`define LHU   6'd14
`define SB    6'd15
`define SH    6'd16
`define SW    6'd17
`define ADDI  6'd18
`define SLTI  6'd19
`define SLTIU 6'd20
`define XORI  6'd21
`define ORI   6'd22
`define ANDI  6'd23
`define SLLI  6'd24
`define SRLI  6'd25
`define SRAI  6'd26
`define ADD   6'd27
`define SUB   6'd28
`define SLL   6'd29
`define SLT   6'd30
`define SLTU  6'd31
`define XOR   6'd32
`define SRL   6'd33
`define SRA   6'd34
`define OR    6'd35
`define AND   6'd36
`define HALT  6'd37
`define NIL   6'd38

`define olui   7'b0110111
`define oauipc 7'b0010111
`define ojal   7'b1101111
`define ojalr  7'b1100111
`define ob     7'b1100011
`define ol     7'b0000011
`define os     7'b0100011
`define ori    7'b0010011
`define orr    7'b0110011

`define Stype 2'b00;
`define Rtype 2'b01; // need to change reg
`define Btype 2'b10; // change pc
`define Jtype 2'b11; // jal jalr: change reg; change pc