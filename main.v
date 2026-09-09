module alu #(
    parameter WIDTH = 16
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    output logic [WIDTH-1:0] out,

    input  logic op_plus,
    input  logic op_and,

    output logic flag_zero
);
    always @(*) begin
        if (op_plus)
            out = a + b;
        if (op_and)
            out = a & b;
    end

    assign flag_zero = (out == 0);
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
    input  wire _alu_flag_zero,

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

    reg [8*4:0] instruction_name[16];
    reg [32-1:0] instruction_microcode[2**WIDTH];
    reg [32-1:0] instruction_microcode_len[16];
    initial begin
        integer i;
        for (i = 0; i < 2**WIDTH; i = i + 1)
            instruction_microcode[i] = 32'b0;

        /// No-op
        instruction_name[4'b0000] = "NOOP";
        instruction_microcode_len[4'b0000] = 0;

        /// A <- mem[A]
        instruction_microcode[4'b0001 * 16 + 0] = A_OE | ALU_OP_AND | ALU_OUT__BUS__SIGNAL | RAM_ADDRESS_WE;
        instruction_microcode[4'b0001 * 16 + 1] = RAM_ADDRESS_OE | RAM_VALUE_WE;
        instruction_microcode[4'b0001 * 16 + 2] = RAM_VALUE_OE | A_WE;
        instruction_microcode_len[4'b0001] = 3;

        /// Jump Zero
        instruction_name[4'b0010] = "JZ";
        instruction_microcode[4'b0010 * 16 + 0] = IP_OE | RAM_ADDRESS_WE;
        instruction_microcode[4'b0010 * 16 + 1] = RAM_ADDRESS_OE | RAM_VALUE_WE;
        instruction_microcode[4'b0010 * 16 + 2] = RAM_VALUE_OE | IP_WE | IP_INC;
        instruction_microcode_len[4'b0010] = 3;

        /// Halt
        instruction_name[4'b1111] = "HALT";
        instruction_microcode[4'b1111 * 16 + 0] = HALT;
        instruction_microcode_len[4'b1111] = 1;
    end

    logic [32-1:0] gates_output;

    wire [3:0] command_id; 
    assign command_id = command[7:4];

    reg [3:0] step = 0;
    always @(posedge clock or posedge reset) begin
        if (reset)
            step <= 0;
        else begin
            if (step == instruction_microcode_len[command_id] + 3)
                step <= 0;
            else
                step <= step + 1;
        end
    end

    always @(*) begin
        case (step)
            0: gates_output = IP_OE | RAM_ADDRESS_WE;
            1: gates_output = RAM_ADDRESS_OE | RAM_VALUE_WE | IP_INC;
            2: gates_output = RAM_VALUE_OE | CMD_WE;
            default: begin
                if (command_id == 4'b0010 && !_alu_flag_zero)
                    gates_output = IP_INC;
                else
                    gates_output = instruction_microcode[{command_id, step - 2'd3}];
            end
        endcase
    end

    assign _gate_ram_address_we                 = gates_output[0];
    assign _gate_ram_value_we                   = gates_output[1];
    assign _gate_ip_we                          = gates_output[2];
    assign _gate_cmd_we                         = gates_output[3];
    assign _gate_ram_address_oe                 = gates_output[4];
    assign _gate_ram_value_oe                   = gates_output[5];
    assign _gate_ip_oe                          = gates_output[6];
    assign _gate__bus__reg_ram_value_in__signal = gates_output[7];
    assign _gate_a_we                           = gates_output[8];
    assign _gate_a_oe                           = gates_output[9];
    assign _gate_b_we                           = gates_output[10];
    assign _gate_b_oe                           = gates_output[11];
    assign _gate_alu_op_plus                    = gates_output[12];
    assign _gate_alu_op_and                     = gates_output[13];
    assign _gate__alu_out__bus__signal          = gates_output[14];
    assign _gate_halt                           = gates_output[15];
    assign _gate_ip_inc                         = gates_output[16];
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
    wire _alu_flag_zero;
    alu alu(_reg_a_out, _reg_b_out, _alu_out, _gate_alu_op_plus, _gate_alu_op_and, _alu_flag_zero);

    wire _gate__alu_out__bus__signal;
    wire [15:0] _alu_out_bus;
    gate _gate__alu_out_bus(
        _alu_out,
        _alu_out_bus,
        _gate__alu_out__bus__signal
    );
    
    controller controller(
        _reg_cmd_out,

        _alu_flag_zero,

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

    reg [32:0] current_instruction_name;
    always @(*) begin
        current_instruction_name = controller.instruction_name[_reg_cmd_out[7:4]];
    end

   	initial begin
        
        $monitor("TICK=%0t STEP=%0d RESET=%b BUS=%h RAM_ADDR=%h RAM_VALUE=%h IP=%h CMD=%h A=%h B=%h (%0s)",
            $time,
            controller.step,
            reset,
            bus,
            _reg_ram_address_out,
            _reg_ram_value_out,
            _reg_ip_out,
            _reg_cmd_out,
            _reg_a_out,
            _reg_b_out,
            current_instruction_name
        );

        reset <= 1;
        #2;
        reset <= 0;
        #2;

        #50 $finish;
   	end
endmodule
