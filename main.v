module alu #(
    parameter WIDTH = 16
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire [WIDTH-1:0] out,

    input  wire op_plus,
    input  wire op_and
);
    // NOTE: OP_AND IS USED FOR DEBUG PURPOSES FOR NOW
    assign out = op_plus ? (a + b) : (op_and ? a : 'z);
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
    
    output wire _gate_a_we,
    output wire _gate_a_oe,

    output wire _gate_b_we,
    output wire _gate_b_oe,

    output wire _gate_alu_op_plus,
    output wire _gate_alu_op_and,

    output wire _gate__alu_out__bus__signal,

    output wire _gate_halt,

    output wire _gate_ip_inc,

    input wire clock,
    input wire reset
);
    // NOTE: For debug purposes
    // reg [3:0] step;
    always @(posedge clock or posedge reset) begin
        if (reset || _gate_cmd_we)
            step <= 0;
        else
            step <= step + 1;
    end

    localparam RAM_ADDRESS_WE                = 32'b0000000000000000001;
    localparam RAM_VALUE_WE                  = 32'b0000000000000000010;
    localparam IP_WE                         = 32'b0000000000000000100;
    localparam CMD_WE                        = 32'b0000000000000001000;
    localparam RAM_ADDRESS_OE                = 32'b0000000000000010000;
    localparam RAM_VALUE_OE                  = 32'b0000000000000100000;
    localparam IP_OE                         = 32'b0000000000001000000;
    localparam BUS__REG_RAM_VALUE_IN__SIGNAL = 32'b0000000000010000000;
    localparam A_WE                          = 32'b0000000000100000000;
    localparam A_OE                          = 32'b0000000001000000000;
    localparam B_WE                          = 32'b0000000010000000000;
    localparam B_OE                          = 32'b0000000100000000000;
    localparam ALU_OP_PLUS                   = 32'b0000001000000000000;
    localparam ALU_OP_AND                    = 32'b0000010000000000000;
    localparam ALU_OUT__BUS__SIGNAL          = 32'b0000100000000000000;
    localparam HALT                          = 32'b0001000000000000000;
    localparam IP_INC                        = 32'b0010000000000000000;
    
    reg [7:0] INSTRUCTION_COUNT = 16;

    reg [32-1:0] gate_table[2**WIDTH];
    initial begin
        integer i;
        for (i = 0; i < 2**WIDTH; i = i + 1)
            gate_table[i] = 32'b0;

        /// Instruction fetch
        gate_table[4'b0000 * INSTRUCTION_COUNT + 0] = IP_OE | RAM_ADDRESS_WE;
        gate_table[4'b0000 * INSTRUCTION_COUNT + 1] = RAM_ADDRESS_OE | RAM_VALUE_WE | IP_INC;
        gate_table[4'b0000 * INSTRUCTION_COUNT + 2] = RAM_VALUE_OE | CMD_WE;

        /// A <- mem[A]
        gate_table[4'b0001 * INSTRUCTION_COUNT + 0] = A_OE | ALU_OP_AND | ALU_OUT__BUS__SIGNAL | RAM_ADDRESS_WE;
        gate_table[4'b0001 * INSTRUCTION_COUNT + 1] = RAM_ADDRESS_OE | RAM_VALUE_WE;
        gate_table[4'b0001 * INSTRUCTION_COUNT + 2] = RAM_VALUE_OE | A_WE;


        /// Halt
        gate_table[4'b1111 * INSTRUCTION_COUNT + 0] = HALT;

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
    assign _gate_a_we                           = gate_table[pointer][8];
    assign _gate_a_oe                           = gate_table[pointer][9];
    assign _gate_b_we                           = gate_table[pointer][10];
    assign _gate_b_oe                           = gate_table[pointer][11];
    assign _gate_alu_op_plus                    = gate_table[pointer][12];
    assign _gate_alu_op_and                     = gate_table[pointer][13];
    assign _gate__alu_out__bus__signal          = gate_table[pointer][14];
    assign _gate_halt                           = gate_table[pointer][15];
    assign _gate_ip_inc                         = gate_table[pointer][16];
endmodule

module computer;
    wire _gate_halt;

    reg clock = 0;
    reg reset = 0;
    always begin
        if (!_gate_halt)
            #1 clock = ~clock;
        else
            #1;
    end

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
    wire _gate_ip_inc;
    wire [15:0] _reg_ip_out;
    counter reg_ip(
        bus,
        _reg_ip_out,
        _gate_ip_we,
        _gate_ip_oe,
        _gate_ip_inc,
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

    wire _gate_a_we;
    wire _gate_a_oe;
    wire [15:0] _reg_a_out;
    register reg_a(
        bus,
        _reg_a_out,
        _gate_a_we,
        _gate_a_oe,
        clock,
        reset
    );

    wire _gate_b_we;
    wire _gate_b_oe;
    wire [15:0] _reg_b_out;
    register reg_b(
        bus,
        _reg_b_out,
        _gate_b_we,
        _gate_b_oe,
        clock,
        reset
    );

    wire [15:0] _alu_out;
    wire _gate_alu_op_plus;
    wire _gate_alu_op_and;
    alu alu(_reg_a_out, _reg_b_out, _alu_out, _gate_alu_op_plus, _gate_alu_op_and);

    wire _gate__alu_out__bus__signal;
    wire [15:0] _alu_out_bus;
    gate _gate__alu_out_bus(
        _alu_out,
        _alu_out_bus,
        _gate__alu_out__bus__signal
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

        _gate_a_we,
        _gate_a_oe,

        _gate_b_we,
        _gate_b_oe,

        _gate_alu_op_plus,
        _gate_alu_op_and,

        _gate__alu_out__bus__signal,

        _gate_halt,

        _gate_ip_inc,

        clock,
        reset
    );

    assign bus =
                _gate_ip_oe ?
                    _reg_ip_out :
                _gate_ram_value_oe ?
                    {8'b0, _reg_ram_value_out} :
                _gate__alu_out__bus__signal ?
                    _alu_out_bus :
                16'bx;

   	initial begin
        $monitor("TICK=%0t STEP=%0d RESET=%b BUS=%h RAM_ADDR=%h RAM_VALUE=%h IP=%h CMD=%h A=%h B=%h",
            $time,
            step,
            reset,
            bus,
            _reg_ram_address_out,
            _reg_ram_value_out,
            reg_ip.value,
            _reg_cmd_out,
            _reg_a_out,
            _reg_b_out
        );

        reset <= 1;
        #2;
        reset <= 0;
        #2;

        #100 $finish;
   	end
endmodule
