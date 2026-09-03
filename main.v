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
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] command,

    output wire gate__alu_out,

    input wire clock
);
    reg [3:0] step;
    always @(posedge clock) begin
        step <= step + 1;
    end

    reg [7:0] pointer;
    assign pointer = { command[7:4], step };

    reg [49:0] gate_table[2] = '{
        'b101010101001,
        'b000010101010
    };

    assign gate__alu_out = gate_table[pointer][0];
endmodule

module computer;
    reg clock = 0;
    always #1 clock = ~clock;

    wire [15:0] bus;

    reg [15:0] constant;
    reg use_constant;
    
    wire [15:0] a_out;
    reg a_we;
    reg a_oe;
    register a(bus, a_out, a_we, a_oe, clock);

    wire [15:0] b_out;
    reg b_we;
    reg b_oe;
    register b(bus, b_out, b_we, b_oe, clock);

    wire [15:0] alu_out_;
    alu alu(a_out, b_out, alu_out_, '1, '0);

    reg gate__alu_out;
    wire [15:0] alu_out;
    gate #(.WIDTH(16)) alu_out__bus(alu_out_, alu_out, gate__alu_out);

    assign bus = use_constant ? constant : (alu_out);

	initial begin
		$monitor("time=%0t bus=%b a_out=%b b_out=%b", $time, bus, a_out, b_out);

		use_constant <= 1;
		gate__alu_out <= 0;
		
		constant = 4;
		a_we <= 1;
		a_oe <= 0;
		#2;

		a_we <= 0;
		a_oe <= 1;

		constant = 42;
		b_we <= 1;
		b_oe <= 0;
		#2;

		b_we <= 0;
		b_oe <= 1;

		use_constant <= 0;

		#10 $finish;
	end
endmodule
