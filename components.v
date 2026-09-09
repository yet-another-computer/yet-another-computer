module register #(
    parameter WIDTH = 16
) (
    input  wire [WIDTH-1:0] in,
    output wire  [WIDTH-1:0] out,

    input  wire write_enabled,
    input  wire output_enabled,
    input  wire clock,
    input  wire reset
);
    reg [WIDTH-1:0] value;

    always @(posedge clock or posedge reset) begin
        if (reset)
            value <= 0;
        if (write_enabled)
            value <= in;
    end

    assign out = output_enabled ? value : 'z;
endmodule

module gate #(
    parameter WIDTH = 16
) (
    input  wire [WIDTH-1:0] in,
    output wire  [WIDTH-1:0] out,

    input  wire is_open
);
    assign out = is_open ? in : 'z;
endmodule

module mux #(
    parameter WIDTH = 16
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire choice,

    output wire [WIDTH-1:0] out
);
    assign out = choice ? b : a;
endmodule

// NOTE: 4x 74LS161 (4-bit synchronous counter with parallel load)
module counter #(
    parameter WIDTH = 16
) (
    input  wire [WIDTH-1:0] in,
    output wire  [WIDTH-1:0] out,

    input  wire write_enabled,
    input  wire output_enabled,
    input  wire increment,
    input  wire clock,
    input  wire reset
);
    reg [WIDTH-1:0] value;

    always @(posedge clock or posedge reset) begin
        if (reset)
            value <= 0;
        else if (write_enabled)
            value <= in;
        else if (increment)
            value <= value + 1;
    end

    assign out = output_enabled ? value : 'z;
endmodule
