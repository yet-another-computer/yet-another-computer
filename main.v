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
    assign value = write_flag ? 'z : memory[address];

    always @(posedge clock) begin
        if (write_flag)
            memory[address] <= value;
    end

    initial begin
        $readmemh("initram.hex", memory, 0, 15);
    end
endmodule

module controller #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] command,
    output reg [3:0] step,

    output wire _gate_ram_address_we,
    output wire _gate_ram_value_we,
    output wire _gate_ip_we,
    output wire _gate_cmd_we,

    output wire _gate_ram_address_oe,
    output wire _gate_ram_value_oe,
    output wire _gate_ip_oe,

    output wire _gate__bus__reg_ram_value_in__signal,

    input wire clock,
    input wire reset
);
    // NOTE: For debug purposes
    // reg [3:0] step;
    always @(posedge clock or posedge reset) begin
        if (reset)
            step <= 0;
        else
            step <= step + 1;
    end


    localparam RAM_ADDRESS_WE                = 8'b00000001;
    localparam RAM_VALUE_WE                  = 8'b00000010;
    localparam IP_WE                         = 8'b00000100;
    localparam CMD_WE                        = 8'b00001000;
    localparam RAM_ADDRESS_OE                = 8'b00010000;
    localparam RAM_VALUE_OE                  = 8'b00100000;
    localparam IP_OE                         = 8'b01000000;
    localparam BUS__REG_RAM_VALUE_IN__SIGNAL = 8'b10000000;

    reg [8-1:0] gate_table[2**WIDTH];
    initial begin
        integer i;
        for (i = 0; i < 2**WIDTH; i = i + 1)
            gate_table[i] = 8'b0;

        gate_table[0] = IP_OE | RAM_ADDRESS_WE;
        gate_table[1] = RAM_ADDRESS_OE | RAM_VALUE_WE;
        gate_table[2] = RAM_VALUE_OE | CMD_WE;
    end

    wire [7:0] pointer;
    assign pointer = { command[7:4], step };

    assign _gate_ram_address_we                 = gate_table[pointer][0];
    assign _gate_ram_value_we                   = gate_table[pointer][1];
    assign _gate_ip_we                          = gate_table[pointer][2];
    assign _gate_cmd_we                         = gate_table[pointer][3];
    assign _gate_ram_address_oe                 = gate_table[pointer][4];
    assign _gate_ram_value_oe                   = gate_table[pointer][5];
    assign _gate_ip_oe                          = gate_table[pointer][6];
    assign _gate__bus__reg_ram_value_in__signal = gate_table[pointer][7];
endmodule

module computer;
    reg clock = 0;
    always #1 clock = ~clock;
    reg reset = 0;

    wire [15:0] bus;

    wire _gate_ram_address_we;
    wire _gate_ram_address_oe;
    wire [15:0] _reg_ram_address_out;
    register reg_ram_address(
        bus,
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

    wire _gate__bus__reg_ram_value_in__signal;
    gate #(.WIDTH(8)) _gate__bus__reg_ram_value_in(
        bus[7:0],
        _reg_ram_value_in,
        _gate__bus__reg_ram_value_in__signal
    );

    wire [7:0] _reg_ram_value_inout;
    ram ram(_reg_ram_address_out, _reg_ram_value_inout, '0, clock);
    assign __reg_ram_value_in = _gate__bus__reg_ram_value_in__signal ? _reg_ram_value_in : _reg_ram_value_inout;

    wire _gate_ip_we;
    wire _gate_ip_oe;
    wire [15:0] _reg_ip_out;
    register reg_ip(
        bus,
        _reg_ip_out,
        _gate_ip_we,
        _gate_ip_oe,
        clock,
        reset
    );

    wire _gate_cmd_we;
    wire [7:0] _reg_cmd_out;
    register #(.WIDTH(8)) reg_cmd(
        bus[7:0],
        _reg_cmd_out,
        _gate_cmd_we,
        '1,
        clock,
        reset
    );

    wire [3:0] step;
    controller controller(
        _reg_cmd_out,
        step,
       
        _gate_ram_address_we,
        _gate_ram_value_we,
        _gate_ip_we,
        _gate_cmd_we,
        
        _gate_ram_address_oe,
        _gate_ram_value_oe,
        _gate_ip_oe,

        _gate__bus__reg_ram_value_in__signal,

        clock,
        reset
    );

    assign bus =
                _gate_ip_oe ?
                    _reg_ip_out :
                _gate_ram_value_oe ?
                    {8'bx, _reg_ram_value_out} :
                16'bx;

   	initial begin
        $monitor("TICK=%0t STEP=%0d RESET=%b BUS=%b RAM_ADDR=%b RAM_VALUE=%b IP=%b CMD=%b",
            $time,
            step,
            reset,
            bus,
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
