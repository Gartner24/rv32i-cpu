`timescale 1ns/1ps
module pc_tb;

reg        clk, rst, en;
reg [31:0] pc_next;
wire[31:0] pc_out;

pc dut (.clk(clk), .rst(rst), .en(en), .pc_next(pc_next), .pc_out(pc_out));

always #5 clk = ~clk;

integer errors;
initial begin
    errors = 0;
    clk = 0; rst = 1; en = 1; pc_next = 32'hDEADBEEF;

    // Reset holds PC at 0
    @(posedge clk); #1;
    if (pc_out !== 32'h0) begin $display("FAIL: reset expected 0 got %0h", pc_out); errors=errors+1; end

    // Release reset, advance
    rst = 0; pc_next = 32'h4;
    @(posedge clk); #1;
    if (pc_out !== 32'h4) begin $display("FAIL: advance expected 4 got %0h", pc_out); errors=errors+1; end

    pc_next = 32'h8;
    @(posedge clk); #1;
    if (pc_out !== 32'h8) begin $display("FAIL: advance expected 8 got %0h", pc_out); errors=errors+1; end

    // Jump target
    pc_next = 32'h100;
    @(posedge clk); #1;
    if (pc_out !== 32'h100) begin $display("FAIL: jump expected 100 got %0h", pc_out); errors=errors+1; end

    // en=0 freezes PC
    en = 0; pc_next = 32'hFFFF;
    @(posedge clk); #1;
    if (pc_out !== 32'h100) begin $display("FAIL: en=0 freeze got %0h (expected 100)", pc_out); errors=errors+1; end
    @(posedge clk); #1;
    if (pc_out !== 32'h100) begin $display("FAIL: en=0 still freeze got %0h", pc_out); errors=errors+1; end

    // en=1 resumes
    en = 1;
    @(posedge clk); #1;
    if (pc_out !== 32'hFFFF) begin $display("FAIL: en=1 resume expected FFFF got %0h", pc_out); errors=errors+1; end

    // rst overrides en=0
    en = 0; rst = 1;
    @(posedge clk); #1;
    if (pc_out !== 32'h0) begin $display("FAIL: rst override expected 0 got %0h", pc_out); errors=errors+1; end

    if (errors == 0) $display("PASS: pc");
    else             $display("FAIL: pc (%0d errors)", errors);
    $finish;
end
endmodule
