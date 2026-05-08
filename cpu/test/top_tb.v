// Integration test for top.v (DE1-SoC RV32I CPU)
//
// Test program (test/program.hex):
//   addi x1, x0, 5      // x1 = 5
//   addi x2, x0, 10     // x2 = 10
//   add  x3, x1, x2     // x3 = 15
//   sw   x3, 0(x0)      // mem[0] = 15
//   lw   x4, 0(x0)      // x4 = 15
`timescale 1ns/1ps
module top_tb;

reg        CLOCK_50;
reg  [3:0] KEY;
reg  [9:0] SW;
wire [9:0] LEDR;
wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
wire [7:0] VGA_R, VGA_G, VGA_B;
wire       VGA_HS, VGA_VS, VGA_CLK, VGA_BLANK_N, VGA_SYNC_N;

top dut (
    .CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW),
    .LEDR(LEDR), .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
    .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5),
    .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
    .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_CLK(VGA_CLK),
    .VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N)
);

// 50 MHz -> 20 ns period
always #10 CLOCK_50 = ~CLOCK_50;

integer errors;

task wait_cycles;
    input integer n;
    integer i;
    begin for (i = 0; i < n; i = i+1) @(posedge CLOCK_50); end
endtask

initial begin
    errors = 0;
    CLOCK_50 = 0;
    KEY = 4'hF;
    SW  = 10'h0;

    // Assert reset
    KEY[0] = 0;
    wait_cycles(3);
    #1;
    if (dut.u_pc.pc_out !== 32'h0)
        begin $display("FAIL: reset PC expected 0 got %0h", dut.u_pc.pc_out); errors = errors+1; end

    // Free-run for 8 cycles (5 instructions + margin)
    KEY[0] = 1;
    wait_cycles(8);
    #1;

    if (dut.u_regfile.regs[1] !== 32'd5)
        begin $display("FAIL: x1 expected 5 got %0d",  dut.u_regfile.regs[1]); errors = errors+1; end
    if (dut.u_regfile.regs[2] !== 32'd10)
        begin $display("FAIL: x2 expected 10 got %0d", dut.u_regfile.regs[2]); errors = errors+1; end
    if (dut.u_regfile.regs[3] !== 32'd15)
        begin $display("FAIL: x3 expected 15 got %0d", dut.u_regfile.regs[3]); errors = errors+1; end
    if (dut.u_regfile.regs[4] !== 32'd15)
        begin $display("FAIL: x4 expected 15 got %0d", dut.u_regfile.regs[4]); errors = errors+1; end

    // LEDR[0] mirrors SW[0]
    if (LEDR[0] !== 1'b0)
        begin $display("FAIL: LEDR[0] should be 0 in auto mode got %0b", LEDR[0]); errors = errors+1; end

    // Step mode: reset and step through one instruction at a time
    KEY[0] = 0; SW = 10'h1;
    wait_cycles(3); #1;
    if (dut.u_pc.pc_out !== 32'h0)
        begin $display("FAIL: step-mode reset PC expected 0 got %0h", dut.u_pc.pc_out); errors = errors+1; end

    KEY[0] = 1;
    wait_cycles(3); #1;
    if (dut.u_pc.pc_out !== 32'h0)
        begin $display("FAIL: step mode no advance without press got %0h", dut.u_pc.pc_out); errors = errors+1; end

    // Press KEY[1] to step one instruction
    KEY[1] = 0; wait_cycles(2); KEY[1] = 1;
    wait_cycles(2); #1;
    if (dut.u_pc.pc_out !== 32'h4)
        begin $display("FAIL: step 1 expected PC=4 got %0h", dut.u_pc.pc_out); errors = errors+1; end

    KEY[1] = 0; wait_cycles(2); KEY[1] = 1;
    wait_cycles(2); #1;
    if (dut.u_pc.pc_out !== 32'h8)
        begin $display("FAIL: step 2 expected PC=8 got %0h", dut.u_pc.pc_out); errors = errors+1; end

    if (LEDR[0] !== 1'b1)
        begin $display("FAIL: LEDR[0] should be 1 in step mode got %0b", LEDR[0]); errors = errors+1; end

    if (errors == 0) $display("PASS: top");
    else             $display("FAIL: top (%0d errors)", errors);
    $finish;
end
endmodule
