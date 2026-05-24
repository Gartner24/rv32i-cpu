`timescale 1ns/1ps
module alu_control_tb;

reg [1:0] alu_op;
reg [2:0] func3;
reg [6:0] func7;
wire[3:0] alu_ctrl;

alu_control dut (.alu_op(alu_op), .func3(func3), .func7(func7), .alu_ctrl(alu_ctrl));

integer errors;

task chk;
    input [3:0]   exp;
    input [255:0] name;
    begin
        #1;
        if (alu_ctrl !== exp) begin
            $display("FAIL: %s expected %04b got %04b", name, exp, alu_ctrl);
            errors = errors + 1;
        end
    end
endtask

initial begin
    errors = 0;

    // alu_op=00: ADD regardless of func3/func7
    alu_op=2'b00; func3=3'b000; func7=7'h00; chk(4'b0000, "op=00 ADD");
    alu_op=2'b00; func3=3'b101; func7=7'h20; chk(4'b0000, "op=00 still ADD");

    // alu_op=01: branch - func3 selects operation
    alu_op=2'b01; func3=3'b000; func7=7'h00; chk(4'b0001, "op=01 BEQ  SUB");
    alu_op=2'b01; func3=3'b001; func7=7'h00; chk(4'b0001, "op=01 BNE  SUB");
    alu_op=2'b01; func3=3'b100; func7=7'h00; chk(4'b1000, "op=01 BLT  SLT");
    alu_op=2'b01; func3=3'b101; func7=7'h00; chk(4'b1000, "op=01 BGE  SLT");
    alu_op=2'b01; func3=3'b110; func7=7'h00; chk(4'b1001, "op=01 BLTU SLTU");
    alu_op=2'b01; func3=3'b111; func7=7'h00; chk(4'b1001, "op=01 BGEU SLTU");

    // alu_op=10: R/I decode
    alu_op=2'b10;
    func3=3'b000; func7=7'h00; chk(4'b0000, "op=10 ADD");
    func3=3'b000; func7=7'h20; chk(4'b0001, "op=10 SUB");
    func3=3'b100; func7=7'h00; chk(4'b0100, "op=10 XOR");
    func3=3'b110; func7=7'h00; chk(4'b0011, "op=10 OR");
    func3=3'b111; func7=7'h00; chk(4'b0010, "op=10 AND");
    func3=3'b001; func7=7'h00; chk(4'b0101, "op=10 SLL");
    func3=3'b101; func7=7'h00; chk(4'b0110, "op=10 SRL");
    func3=3'b101; func7=7'h20; chk(4'b0111, "op=10 SRA");
    func3=3'b010; func7=7'h00; chk(4'b1000, "op=10 SLT");
    func3=3'b011; func7=7'h00; chk(4'b1001, "op=10 SLTU");

    if (errors == 0) $display("PASS: alu_control");
    else             $display("FAIL: alu_control (%0d errors)", errors);
    $finish;
end
endmodule
