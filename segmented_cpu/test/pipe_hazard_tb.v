// Hazard stress test (Step 3): load-use stall + taken-branch flush, NO NOPs.
// Program in pipe_hazard.hex:
//   x1 = 0                       (base address)
//   x2 = 42
//   sw  x2, 0(x1)                mem[0] = 42
//   lw  x3, 0(x1)                x3 = 42        (load)
//   addi x4, x3, 1               x4 = 43        (LOAD-USE: needs 1-cycle stall)
//   beq x4, x4, +8               taken -> flush, skips the next instruction
//   addi x5, x0, 99              POISON (must be flushed -> x5 stays 0)
//   addi x6, x0, 7               x6 = 7
//   ebreak
// Verifies load-use stall and control-hazard flush together.
`timescale 1ns/1ps
module pipe_hazard_tb;

defparam dut.u_imem.HEX_FILE  = "pipe_hazard.hex";
defparam dut.u_imem.MEM_DEPTH = 256;

reg        CLOCK_50;
reg  [3:0] KEY;
reg  [9:0] SW;
wire [9:0] LEDR;
wire [7:0] VGA_R, VGA_G, VGA_B;
wire       VGA_HS, VGA_VS, VGA_CLK, VGA_BLANK_N, VGA_SYNC_N;

top dut (
    .CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW),
    .LEDR(LEDR),
    .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
    .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_CLK(VGA_CLK),
    .VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N)
);

always #10 CLOCK_50 = ~CLOCK_50;

integer errors;
integer cycle_count;

task check;
    input [255:0] name;
    input [31:0]  got;
    input [31:0]  exp;
    begin
        if (got !== exp) begin
            $display("FAIL: %0s expected 0x%08h got 0x%08h", name, exp, got);
            errors = errors + 1;
        end
    end
endtask

initial begin
    errors = 0; cycle_count = 0;
    CLOCK_50 = 0; KEY = 4'hF; SW = 10'h0;

    KEY[0] = 0;
    @(posedge CLOCK_50); @(posedge CLOCK_50); @(posedge CLOCK_50);
    KEY[0] = 1;

    while (!dut.halted && cycle_count < 1000) begin
        @(posedge CLOCK_50);
        cycle_count = cycle_count + 1;
    end
    #1;

    if (!dut.halted) begin
        $display("FAIL: pipe_hazard did not halt within %0d cycles", cycle_count);
        errors = errors + 1;
    end else begin
        check("x2",      dut.u_regfile.regs[2], 32'd42);
        check("x3(lw)",  dut.u_regfile.regs[3], 32'd42);
        check("x4(use)", dut.u_regfile.regs[4], 32'd43);
        check("x5(skip)",dut.u_regfile.regs[5], 32'd0);
        check("x6",      dut.u_regfile.regs[6], 32'd7);
        check("dmem[0]", dut.dmem[0], 32'd42);
    end

    if (errors == 0) $display("PASS: pipe_hazard halted in %0d cycles", cycle_count);
    else             $display("FAIL: pipe_hazard (%0d errors)", errors);
    $finish;
end
endmodule
