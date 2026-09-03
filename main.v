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

    wire [15:0] alu_out;
    // reg gate__alu_out__bus;
    alu alu(a_out, b_out, alu_out, '1, '0);
    // gate #(.WIDTH(16)) alu_out__bus(alu_out, bus, gate__alu_out__bus);

    assign bus = use_constant ? constant : (alu_out);

	initial begin
		$monitor("time=%0t bus=%b a_out=%b b_out=%b", $time, bus, a_out, b_out);

		use_constant <= 1;

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
