`timescale 1ns/1ps
module adder_tb;

reg  [31:0] a, b;
wire [31:0] out;

adder dut (.a(a), .b(b), .out(out));

integer errors;
initial begin
    errors = 0;

    a = 32'd5;          b = 32'd3;          #1;
    if (out !== 32'd8)          begin $display("FAIL: 5+3 got %0d",     out); errors=errors+1; end

    a = 32'd0;          b = 32'd0;          #1;
    if (out !== 32'd0)          begin $display("FAIL: 0+0 got %0d",     out); errors=errors+1; end

    // overflow wraps
    a = 32'hFFFFFFFF;   b = 32'd1;          #1;
    if (out !== 32'd0)          begin $display("FAIL: overflow got %0h", out); errors=errors+1; end

    a = 32'hDEADBEEF;   b = 32'd0;          #1;
    if (out !== 32'hDEADBEEF)  begin $display("FAIL: identity got %0h", out); errors=errors+1; end

    a = 32'd100;        b = 32'd200;        #1;
    if (out !== 32'd300)        begin $display("FAIL: 100+200 got %0d", out); errors=errors+1; end

    if (errors == 0) $display("PASS: adder");
    else             $display("FAIL: adder (%0d errors)", errors);
    $finish;
end
endmodule
