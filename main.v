module alu #(
    parameter WIDTH = 16
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire [WIDTH-1:0] out,

    input  wire op_plus,
    input  wire op_and
);
    assign out = op_plus ? (a + b) : (op_and ? a & b : 'z);
endmodule

module ram #(
    parameter WIDTH = 16
) (
    input wire [WIDTH-1:0] address,
    inout wire [7:0] value,

    input wire write_flag,
    input wire clock
);
    reg [7:0] memory[2**WIDTH];
    assign value = write_flag ? memory[address] : 'z;

    always @(posedge clock) begin
        if (write_flag)
            memory[address] <= value;
    end
endmodule

module controller #(
    parameter WIDTH = 8,
    parameter GATE_NUM = 12
) (
    input  wire [WIDTH-1:0] command,

    output wire _gate_ram_address,
    output wire _gate_ram_value,
    output wire _gate_ip,
    output wire _gate_cmd,

    output wire _gate_ram_address_we,
    output wire _gate_ram_value_we,
    output wire _gate_ip_we,
    output wire _gate_cmd_we,

    output wire _gate_ram_address_oe,
    output wire _gate_ram_value_oe,
    output wire _gate_ip_oe,

    input wire clock,
    input wire reset
);
    reg [3:0] step;
    always @(posedge clock or posedge reset) begin
        if (reset)
            step <= 0;
        if (clock)
            step <= step + 1;
    end

    reg [7:0] pointer;
    assign pointer = { command[7:4], step };

    reg [GATE_NUM-1:0] gate_table[2**WIDTH];
    initial begin
        integer i;
        for (i = 0; i < 2**WIDTH; i = i + 1)
            gate_table[i] = {GATE_NUM{1'b000000000000}};
        gate_table[0] = 'b101010000010;
    end

    assign _gate_ram_address = gate_table[pointer][0];
    assign _gate_ram_value = gate_table[pointer][1];
    assign _gate_ip = gate_table[pointer][2];
    assign _gate_cmd = gate_table[pointer][3];
    assign _gate_ram_address_we = gate_table[pointer][4];
    assign _gate_ram_value_we = gate_table[pointer][5];
    assign _gate_ip_we = gate_table[pointer][6];
    assign _gate_cmd_we = gate_table[pointer][7];
    assign _gate_ram_address_oe = gate_table[pointer][8];
    assign _gate_ram_value_oe = gate_table[pointer][9];
    assign _gate_ip_oe = gate_table[pointer][10];
endmodule

module computer;
    reg clock = 0;
    always #1 clock = ~clock;
    reg reset = 0;

    wire [15:0] bus;

    wire _gate_ram_address_we;
    wire _gate_ram_address_oe;
    wire [15:0] _reg_ram_address_in;
    wire [15:0] _reg_ram_address_out;
    register reg_ram_address(
        _reg_ram_address_in,
        _reg_ram_address_out,
        _gate_ram_address_we,
        _gate_ram_address_oe,
        clock,
        reset
    );

    wire _gate_ram_value_we;
    wire _gate_ram_value_oe;
    wire [7:0] _reg_ram_value_in;
    wire [7:0] _reg_ram_value_out;
    wire [7:0] __reg_ram_value_in;
    register #(.WIDTH(8)) reg_ram_value(
        __reg_ram_value_in,
        _reg_ram_value_out,
        _gate_ram_value_we,
        _gate_ram_value_oe,
        clock,
        reset
    );

    wire [7:0] _reg_ram_value_inout;
    ram ram(_reg_ram_address_out, _reg_ram_value_inout, '0, clock);
    assign __reg_ram_value_in = _reg_ram_value_in[7:0] | _reg_ram_value_inout;

    wire _gate_ip_we;
    wire _gate_ip_oe;
    wire [15:0] _reg_ip_in;
    wire [15:0] _reg_ip_out;
    register reg_ip(
        _reg_ip_in,
        _reg_ip_out,
        _gate_ip_we,
        _gate_ip_oe,
        clock,
        reset
    );

    wire _gate_cmd_we;
    wire [7:0] _reg_cmd_in;
    wire [7:0] _reg_cmd_out;
    register #(.WIDTH(8)) reg_cmd(
        _reg_cmd_in,
        _reg_cmd_out,
        _gate_cmd_we,
        '1,
        clock,
        reset
    );

    wire _gate_ram_address;
    gate gate_ram_address(bus, _reg_ram_address_in, _gate_ram_address);

    wire _gate_ram_value;
    gate #(.WIDTH(8)) gate_ram_value(bus[7:0], _reg_ram_value_in, _gate_ram_value);

    wire _gate_ip;
    gate gate_ip(bus, _reg_ip_in, _gate_ip);

    wire _gate_cmd;
    gate #(.WIDTH(8)) gate_cmd(bus[7:0], _reg_cmd_in, _gate_cmd);

    controller controller(
        _reg_cmd_out,

        _gate_ram_address,
        _gate_ram_value,
        _gate_ip,
        _gate_cmd,
        
        _gate_ram_address_we,
        _gate_ram_value_we,
        _gate_ip_we,
        _gate_cmd_we,
        
        _gate_ram_address_oe,
        _gate_ram_value_oe,
        _gate_ip_oe,

        clock,
        reset
    );

    assign bus[7:0] = _reg_ram_value_out | _reg_ip_out[7:0];
    assign bus[15:8] = _reg_ip_out[15:8];

   	initial begin
        $monitor("time=%0t RAM_ADDR=%b RAM_VALUE=%b IP=%b CMD=%b",
            $time,
            _reg_ram_address_out,
            _reg_ram_value_out,
            _reg_ip_out,
            _reg_cmd_out
        );

        reset <= 1;
        #2;
        reset <= 0;
        #2;
        
        #10 $finish;
   	end
endmodule
