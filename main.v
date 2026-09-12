module alu #(
    parameter WIDTH = 16
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    output logic [WIDTH-1:0] out,

    input  logic op_plus,
    input  logic op_lshift,
    input  logic op_rshift,
    input  logic op_inc,

    output logic flag_zero
);
    always @(*) begin
        if (op_plus)
            out = a + b;
        if (op_lshift)
            out = a << 8;
        if (op_rshift)
            out = a >> 8;
        if (op_inc)
            out = a + 1;
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
    output wire _gate_ip_we,
    output wire _gate_cmd_we,

    output wire _gate_ram_address_oe,
    output wire _gate_ip_oe,

    output wire _gate_a_we,
    output wire _gate_a_oe,

    output wire _gate_b_we,
    output wire _gate_b_oe,

    output wire _gate_alu_op_plus,
    output wire _gate_alu_op_lshift,

    output wire _gate__alu_out__bus__signal,

    output wire _gate_halt,

    output wire _gate_ip_inc,

    output wire _gate_mux1_choice,
    output wire _gate_mux2_choice,

    output wire _gate__reg_a_out__bus__signal,
    output wire _gate__reg_b_out__bus__signal,

    output wire _gate_alu_op_inc,

    output wire _gate_alu_op_rshift,

    output wire _gate_ram_flag_write,

    output wire _gate_ram_value_in_we,
    output wire _gate_ram_value_in_oe,

    output wire _gate_ram_value_out_we,
    output wire _gate_ram_value_out_oe,

    input wire clock,
    input wire reset
);
    localparam RAM_ADDRESS_WE                 = 32'b00000000000000000000000000000001;
    localparam IP_WE                          = 32'b00000000000000000000000000000100;
    localparam CMD_WE                         = 32'b00000000000000000000000000001000;
    localparam RAM_ADDRESS_OE                 = 32'b00000000000000000000000000010000;
    localparam IP_OE                          = 32'b00000000000000000000000001000000;
    localparam A_WE                           = 32'b00000000000000000000000100000000;
    localparam A_OE                           = 32'b00000000000000000000001000000000;
    localparam B_WE                           = 32'b00000000000000000000010000000000;
    localparam B_OE                           = 32'b00000000000000000000100000000000;
    localparam ALU_OP_PLUS                    = 32'b00000000000000000001000000000000;
    localparam ALU_OP_LSHIFT                  = 32'b00000000000000000010000000000000;
    localparam ALU_OUT__BUS__SIGNAL           = 32'b00000000000000000100000000000000;
    localparam HALT                           = 32'b00000000000000001000000000000000;
    localparam IP_INC                         = 32'b00000000000000010000000000000000;
    localparam MUX1_CHOICE                    = 32'b00000000000000100000000000000000;
    localparam MUX2_CHOICE                    = 32'b00000000000001000000000000000000;
    localparam REG_A_OUT__BUS__SIGNAL         = 32'b00000000000010000000000000000000;
    localparam REG_B_OUT__BUS__SIGNAL         = 32'b00000000000100000000000000000000;
    localparam ALU_OP_INC                     = 32'b00000000001000000000000000000000;
    localparam ALU_OP_RLSHIFT                 = 32'b00000000100000000000000000000000;
    localparam RAM_FLAG_WRITE                 = 32'b00000001000000000000000000000000;
    localparam RAM_VALUE_IN_WE                = 32'b00000010000000000000000000000000;
    localparam RAM_VALUE_IN_OE                = 32'b00000100000000000000000000000000;
    localparam RAM_VALUE_OUT_WE               = 32'b00001000000000000000000000000000;
    localparam RAM_VALUE_OUT_OE               = 32'b00010000000000000000000000000000;

    reg [8*4:0] instruction_name[16];
    reg [32-1:0] instruction_microcode[2**WIDTH];
    reg [32-1:0] instruction_microcode_len[16];
    initial begin
        integer i;
        for (i = 0; i < 2**WIDTH; i = i + 1)
            instruction_microcode[i] = 32'b0;

        /// No-op
        instruction_name[4'b0000] = "NOOP";
        instruction_microcode[4'b0000 * 16 + 0] = A_OE | B_OE;
        instruction_microcode_len[4'b0000] = 1;

        /// Load a, b ([b] -> a)
        instruction_name[4'b0001] = "LD";
        instruction_microcode[4'b0001 * 16 + 0] = B_OE | REG_B_OUT__BUS__SIGNAL | RAM_ADDRESS_WE;
        instruction_microcode[4'b0001 * 16 + 1] = RAM_ADDRESS_OE | RAM_VALUE_OUT_WE;
        instruction_microcode[4'b0001 * 16 + 2] = RAM_VALUE_OUT_OE | A_WE;
        instruction_microcode_len[4'b0001] = 3;

        /// Store a, b (b -> [a])
        instruction_name[4'b0010] = "ST";
        instruction_microcode[4'b0010 * 16 + 0] = A_OE | REG_A_OUT__BUS__SIGNAL | RAM_ADDRESS_WE;
        instruction_microcode[4'b0010 * 16 + 1] = B_OE | REG_B_OUT__BUS__SIGNAL | RAM_VALUE_IN_WE;
        instruction_microcode[4'b0010 * 16 + 2] = RAM_ADDRESS_OE | RAM_VALUE_IN_OE | RAM_FLAG_WRITE;
        instruction_microcode_len[4'b0010] = 3;

        /// Load direct a, %d (%d -> a)
        instruction_name[4'b0011] = "LDD";
        instruction_microcode[4'b0011 * 16 + 0] = IP_OE | RAM_ADDRESS_WE;
        instruction_microcode[4'b0011 * 16 + 1] = RAM_ADDRESS_OE | RAM_VALUE_OUT_WE;
        instruction_microcode[4'b0011 * 16 + 2] = RAM_VALUE_OUT_OE | IP_INC;
        instruction_microcode_len[4'b0011] = 3;

        /// Jump Zero
        instruction_name[4'b1110] = "JZ";
        instruction_microcode[4'b1110 * 16 + 0] = IP_OE | RAM_ADDRESS_WE;
        instruction_microcode[4'b1110 * 16 + 1] = RAM_ADDRESS_OE | RAM_VALUE_OUT_WE;
        instruction_microcode[4'b1110 * 16 + 2] = RAM_VALUE_OUT_OE | IP_WE | IP_INC;
        instruction_microcode_len[4'b1110] = 3;

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
            1: gates_output = RAM_ADDRESS_OE | RAM_VALUE_OUT_WE | IP_INC;
            2: gates_output = RAM_VALUE_OUT_OE | CMD_WE;
            default: begin
                if (command_id == 4'b0011) begin
                    logic [32-1:0] dst_we;
                    dst_we = command[0] ? B_WE : A_WE;

                    gates_output = instruction_microcode[{command_id, step - 2'd3}];
                    case (step - 2'd3)
                        2: gates_output |= dst_we;
                        default: begin end
                    endcase
                end
                else if (command_id == 4'b1110 && !_alu_flag_zero)
                    gates_output = IP_INC;
                else
                    gates_output = instruction_microcode[{command_id, step - 2'd3}];
            end
        endcase
    end

    assign _gate_ram_address_we                  = gates_output[0];
    assign _gate_ip_we                           = gates_output[2];
    assign _gate_cmd_we                          = gates_output[3];
    assign _gate_ram_address_oe                  = gates_output[4];
    assign _gate_ip_oe                           = gates_output[6];
    assign _gate_a_we                            = gates_output[8];
    assign _gate_a_oe                            = gates_output[9];
    assign _gate_b_we                            = gates_output[10];
    assign _gate_b_oe                            = gates_output[11];
    assign _gate_alu_op_plus                     = gates_output[12];
    assign _gate_alu_op_lshift                   = gates_output[13];
    assign _gate__alu_out__bus__signal           = gates_output[14];
    assign _gate_halt                            = gates_output[15];
    assign _gate_ip_inc                          = gates_output[16];
    assign _gate_mux1_choice                     = gates_output[17];
    assign _gate_mux2_choice                     = gates_output[18];
    assign _gate__reg_a_out__bus__signal         = gates_output[19];
    assign _gate__reg_b_out__bus__signal         = gates_output[20];
    assign _gate_alu_op_inc                      = gates_output[21];
    assign _gate_alu_op_rshift                   = gates_output[23];
    assign _gate_ram_flag_write                  = gates_output[24];
    assign _gate_ram_value_in_we                 = gates_output[25];
    assign _gate_ram_value_in_oe                 = gates_output[26];
    assign _gate_ram_value_out_we                = gates_output[27];
    assign _gate_ram_value_out_oe                = gates_output[28];

    /// Debug
    reg [64:0] current_controller_stage;
    always @(*) begin
        if (step < 3)
            current_controller_stage = "#fetch";
        else
            current_controller_stage = controller.instruction_name[command[7:4]];
    end
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

    wire _gate_ram_value_in_we;
    wire _gate_ram_value_in_oe;
    wire [7:0] _reg_ram_value_in_out;
    register #(.WIDTH(8)) reg_ram_value_in(
        bus[7:0],
        _reg_ram_value_in_out,
        _gate_ram_value_in_we,
        _gate_ram_value_in_oe,
        clock,
        reset
    );

    wire _gate_ram_value_out_we;
    wire _gate_ram_value_out_oe;
    wire [7:0] _reg_ram_value_out_in;
    register #(.WIDTH(8)) reg_ram_value_out(
        _reg_ram_value_out_in,
        bus[7:0],
        _gate_ram_value_out_we,
        _gate_ram_value_out_oe,
        clock,
        reset
    );

    wire [7:0] _reg_ram_value_inout;
    wire _gate_ram_flag_write;
    ram ram(_reg_ram_address_out, _reg_ram_value_inout, _gate_ram_flag_write, clock);
    assign _reg_ram_value_inout = _reg_ram_value_in_out;
    assign _reg_ram_value_out_in = _reg_ram_value_inout;

    wire _gate_ip_we;
    wire _gate_ip_oe;
    wire _gate_ip_inc;
    counter reg_ip(
        bus,
        bus,
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
        {8'b0, bus[7:0]},
        _reg_a_out,
        _gate_a_we,
        _gate_a_oe,
        clock,
        reset
    );

    wire _gate__reg_a_out__bus__signal;
    gate _gate__reg_a_out__bus(
        _reg_a_out,
        bus,
        _gate__reg_a_out__bus__signal
    );

    wire _gate_b_we;
    wire _gate_b_oe;
    wire [15:0] _reg_b_out;
    register reg_b(
        {8'b0, bus[7:0]},
        _reg_b_out,
        _gate_b_we,
        _gate_b_oe,
        clock,
        reset
    );

    wire _gate__reg_b_out__bus__signal;
    gate _gate__reg_b_out__bus(
        _reg_b_out,
        bus,
        _gate__reg_b_out__bus__signal
    );

    wire [15:0] _mux1_out;
    wire _gate_mux1_choice;
    mux mux1(_reg_a_out, _reg_b_out, _gate_mux1_choice, _mux1_out);

    wire [15:0] _mux2_out;
    wire _gate_mux2_choice;
    mux mux2(_reg_a_out, _reg_b_out, _gate_mux2_choice, _mux2_out);

    wire [15:0] _alu_out;
    wire _gate_alu_op_plus;
    wire _gate_alu_op_lshift;
    wire _gate_alu_op_rshift;
    wire _gate_alu_op_inc;
    wire _alu_flag_zero;
    alu alu(
        _mux1_out,
        _mux2_out,
        _alu_out,
        _gate_alu_op_plus,
        _gate_alu_op_lshift,
        _gate_alu_op_rshift,
        _gate_alu_op_inc,
        _alu_flag_zero
    );

    wire _gate__alu_out__bus__signal;
    gate _gate__alu_out_bus(
        _alu_out,
        bus,
        _gate__alu_out__bus__signal
    );
    
    controller controller(
        _reg_cmd_out,

        _alu_flag_zero,

        _gate_ram_address_we,
        _gate_ip_we,
        _gate_cmd_we,
        
        _gate_ram_address_oe,
        _gate_ip_oe,

        _gate_a_we,
        _gate_a_oe,

        _gate_b_we,
        _gate_b_oe,

        _gate_alu_op_plus,
        _gate_alu_op_lshift,

        _gate__alu_out__bus__signal,

        _gate_halt,

        _gate_ip_inc,

        _gate_mux1_choice,
        _gate_mux2_choice,

        _gate__reg_a_out__bus__signal,
        _gate__reg_b_out__bus__signal,

        _gate_alu_op_inc,

        _gate_alu_op_rshift,
        _gate_ram_flag_write,

        _gate_ram_value_in_we,
        _gate_ram_value_in_oe,

        _gate_ram_value_out_we,
        _gate_ram_value_out_oe,
        
        clock,
        reset
    );

   	initial begin
        $monitor("TICK=%0t STEP=%0d RESET=%b BUS=%h RAM_ADDR=%h RAM_VALUE=(%h,%h) IP=%h CMD=%h A=%h B=%h (%0s)",
            $time,
            controller.step,
            reset,
            bus,
            reg_ram_address.value,
            reg_ram_value_in.value,
            reg_ram_value_out.value,
            reg_ip.value,
            reg_cmd.value,
            reg_a.value,
            reg_b.value,
            controller.current_controller_stage
        );

        reset <= 1;
        #2;
        reset <= 0;
        #2;

        #100;
        $writememh("dumpram.hex", ram.memory, 0, 15);
        $finish;
   	end
endmodule
