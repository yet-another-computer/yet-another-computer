module register #(
    parameter WIDTH = 16
) (
    input  wire [WIDTH-1:0] in,
    output wire  [WIDTH-1:0] out,

    input  wire write_enabled,
    input  wire output_enabled,
    input  wire clock
);
    reg [WIDTH-1:0] value;

    always @(posedge clock) begin
        if (write_enabled) begin
            value <= in;
        end
    end

    assign out = output_enabled ? value : 'z;
endmodule

module gate #(
    parameter WIDTH
) (
    input  wire [WIDTH-1:0] in,
    output wire  [WIDTH-1:0] out,

    input  wire is_open
);
    assign out = is_open ? in : 'z;
endmodule


module computer;
    reg clock = 0;
    always #0.5 clock = ~clock;

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

    assign bus = use_constant ? constant : (a_out + b_out);

	initial begin
		$monitor("time=%0t bus=%b a_out=%b b_out=%b", $time, bus, a_out, b_out);

		constant = 4;
		use_constant = 1;
		a_we = 1;
		a_oe = 0;
		b_we = 1;
		b_oe = 0;
		#1;
		use_constant = 0;
		#1;
		a_we = 0;
		a_oe = 1;
		b_we = 0;
		b_oe = 1;

		#10 $finish;
	end
endmodule
