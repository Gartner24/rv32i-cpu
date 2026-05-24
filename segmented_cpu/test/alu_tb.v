`timescale 1ns/1ps
module alu_tb;

reg  [31:0] a, b;
reg  [3:0]  alu_ctrl;
wire [31:0] result;
wire        zero;

alu dut (.a(a), .b(b), .alu_ctrl(alu_ctrl), .result(result), .zero(zero));

integer errors;

task chk;
    input [31:0] exp_result;
    input        exp_zero;
    input [255:0] name;
    begin
        #1;
        if (result !== exp_result) begin
            $display("FAIL: %s result: expected %0h got %0h", name, exp_result, result);
            errors = errors + 1;
        end
        if (zero !== exp_zero) begin
            $display("FAIL: %s zero: expected %0b got %0b", name, exp_zero, zero);
            errors = errors + 1;
        end
    end
endtask

initial begin
    errors = 0;

    // ADD (0000)
    alu_ctrl=4'b0000; a=32'd10;         b=32'd20;         chk(32'd30,          1'b0, "ADD 10+20");
    alu_ctrl=4'b0000; a=32'd0;          b=32'd0;          chk(32'd0,           1'b1, "ADD zero flag");
    alu_ctrl=4'b0000; a=32'hFFFFFFFF;   b=32'd1;          chk(32'd0,           1'b1, "ADD overflow");

    // SUB (0001)
    alu_ctrl=4'b0001; a=32'd10;         b=32'd10;         chk(32'd0,           1'b1, "SUB equal");
    alu_ctrl=4'b0001; a=32'd20;         b=32'd5;          chk(32'd15,          1'b0, "SUB 20-5");
    alu_ctrl=4'b0001; a=32'd5;          b=32'd10;         chk(32'hFFFFFFFB,    1'b0, "SUB negative");

    // AND (0010)
    alu_ctrl=4'b0010; a=32'hFF00FF00;   b=32'hF0F0F0F0;   chk(32'hF000F000,    1'b0, "AND");
    alu_ctrl=4'b0010; a=32'hAAAAAAAA;   b=32'h55555555;   chk(32'd0,           1'b1, "AND zero");

    // OR (0011)
    alu_ctrl=4'b0011; a=32'hFF00FF00;   b=32'h00FF00FF;   chk(32'hFFFFFFFF,    1'b0, "OR");
    alu_ctrl=4'b0011; a=32'd0;          b=32'd0;          chk(32'd0,           1'b1, "OR zero");

    // XOR (0100)
    alu_ctrl=4'b0100; a=32'hFFFFFFFF;   b=32'hFFFFFFFF;   chk(32'd0,           1'b1, "XOR self");
    alu_ctrl=4'b0100; a=32'hAAAAAAAA;   b=32'h55555555;   chk(32'hFFFFFFFF,    1'b0, "XOR");

    // SLL (0101)
    alu_ctrl=4'b0101; a=32'd1;          b=32'd4;          chk(32'd16,          1'b0, "SLL 1<<4");
    alu_ctrl=4'b0101; a=32'd1;          b=32'd31;         chk(32'h80000000,    1'b0, "SLL 1<<31");
    alu_ctrl=4'b0101; a=32'd1;          b=32'd0;          chk(32'd1,           1'b0, "SLL no shift");

    // SRL (0110)
    alu_ctrl=4'b0110; a=32'h80000000;   b=32'd1;          chk(32'h40000000,    1'b0, "SRL logical");
    alu_ctrl=4'b0110; a=32'd16;         b=32'd4;          chk(32'd1,           1'b0, "SRL 16>>4");
    alu_ctrl=4'b0110; a=32'hFFFFFFFF;   b=32'd31;         chk(32'd1,           1'b0, "SRL 31");

    // SRA (0111)
    alu_ctrl=4'b0111; a=32'h80000000;   b=32'd1;          chk(32'hC0000000,    1'b0, "SRA sign extend");
    alu_ctrl=4'b0111; a=32'd16;         b=32'd4;          chk(32'd1,           1'b0, "SRA positive");
    alu_ctrl=4'b0111; a=32'hFFFFFFFF;   b=32'd4;          chk(32'hFFFFFFFF,    1'b0, "SRA all ones");

    // SLT (1000) signed
    alu_ctrl=4'b1000; a=32'hFFFFFFFF;   b=32'd1;          chk(32'd1,           1'b0, "SLT -1<1");
    alu_ctrl=4'b1000; a=32'd1;          b=32'hFFFFFFFF;   chk(32'd0,           1'b1, "SLT 1<-1 false");
    alu_ctrl=4'b1000; a=32'd5;          b=32'd5;          chk(32'd0,           1'b1, "SLT equal");

    // SLTU (1001) unsigned
    alu_ctrl=4'b1001; a=32'hFFFFFFFF;   b=32'd1;          chk(32'd0,           1'b1, "SLTU large<small");
    alu_ctrl=4'b1001; a=32'd1;          b=32'hFFFFFFFF;   chk(32'd1,           1'b0, "SLTU small<large");
    alu_ctrl=4'b1001; a=32'd0;          b=32'd0;          chk(32'd0,           1'b1, "SLTU equal");

    if (errors == 0) $display("PASS: alu");
    else             $display("FAIL: alu (%0d errors)", errors);
    $finish;
end
endmodule
