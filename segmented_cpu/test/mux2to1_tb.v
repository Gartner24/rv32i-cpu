`timescale 1ns/1ps
module mux2to1_tb;

reg        sel;
reg [31:0] a, b;
wire[31:0] out;

mux2to1 dut (.sel(sel), .a(a), .b(b), .out(out));

integer errors;
initial begin
    errors = 0;

    a = 32'hAAAAAAAA; b = 32'h55555555;

    sel = 0; #1;
    if (out !== 32'hAAAAAAAA) begin $display("FAIL: sel=0 expected A got %0h", out); errors=errors+1; end

    sel = 1; #1;
    if (out !== 32'h55555555) begin $display("FAIL: sel=1 expected 5 got %0h", out); errors=errors+1; end

    a = 32'd0; b = 32'hFFFFFFFF; sel = 0; #1;
    if (out !== 32'd0)          begin $display("FAIL: sel=0 zero got %0h", out); errors=errors+1; end

    sel = 1; #1;
    if (out !== 32'hFFFFFFFF)   begin $display("FAIL: sel=1 max got %0h",  out); errors=errors+1; end

    if (errors == 0) $display("PASS: mux2to1");
    else             $display("FAIL: mux2to1 (%0d errors)", errors);
    $finish;
end
endmodule
