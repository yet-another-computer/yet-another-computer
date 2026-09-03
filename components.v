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
    parameter WIDTH = 16
) (
    input  wire [WIDTH-1:0] in,
    output wire  [WIDTH-1:0] out,

    input  wire is_open
);
    assign out = is_open ? in : 'z;
endmodule
