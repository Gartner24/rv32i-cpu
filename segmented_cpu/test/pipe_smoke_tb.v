// Smoke test for the 5-stage pipeline (Step 1, no hazard logic yet).
// Program (NOP-padded, hazard-free) in pipe_smoke.hex:
//   x1=5, x2=7, x3=x1+x2=12, mem[0]=x3, x4=mem[0]=12,
//   taken beq skips an addi (x6 stays 0), then ebreak.
// Verifies fetch/decode/execute/mem/wb flow + PC redirect on a taken branch.
`timescale 1ns/1ps
module pipe_smoke_tb;

defparam dut.u_imem.HEX_FILE  = "pipe_smoke.hex";
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
        $display("FAIL: pipe_smoke did not halt within %0d cycles", cycle_count);
        errors = errors + 1;
    end else begin
        check("x1",      dut.u_regfile.regs[1], 32'd5);
        check("x2",      dut.u_regfile.regs[2], 32'd7);
        check("x3",      dut.u_regfile.regs[3], 32'd12);
        check("x4",      dut.u_regfile.regs[4], 32'd12);
        check("x6(skip)",dut.u_regfile.regs[6], 32'd0);
        check("dmem[0]", dut.dmem[0], 32'd12);
    end

    if (errors == 0) $display("PASS: pipe_smoke halted in %0d cycles", cycle_count);
    else             $display("FAIL: pipe_smoke (%0d errors)", errors);
    $finish;
end
endmodule
