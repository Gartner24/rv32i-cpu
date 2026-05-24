// Forwarding test (Step 2): back-to-back data dependencies with NO NOPs.
// Program in pipe_forward.hex:
//   x1 = 5
//   x2 = x1 + 3 = 8     (rs1=x1 from EX/MEM -> distance 1)
//   x3 = x2 + 1 = 9     (rs1=x2 from EX/MEM -> distance 1)
//   x4 = x1 + x2 = 13   (x2 from MEM/WB distance 2; x1 from WB->ID bypass distance 3)
//   x5 = x3 - x1 = 4    (x3 from MEM/WB distance 2; x1 from register file distance 4)
//   x6 = 1
//   ebreak
// Verifies EX/MEM forward, MEM/WB forward, and the WB->ID bypass.
`timescale 1ns/1ps
module pipe_forward_tb;

defparam dut.u_imem.HEX_FILE  = "pipe_forward.hex";
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
        $display("FAIL: pipe_forward did not halt within %0d cycles", cycle_count);
        errors = errors + 1;
    end else begin
        check("x1", dut.regs[1], 32'd5);
        check("x2", dut.regs[2], 32'd8);
        check("x3", dut.regs[3], 32'd9);
        check("x4", dut.regs[4], 32'd13);
        check("x5", dut.regs[5], 32'd4);
        check("x6", dut.regs[6], 32'd1);
    end

    if (errors == 0) $display("PASS: pipe_forward halted in %0d cycles", cycle_count);
    else             $display("FAIL: pipe_forward (%0d errors)", errors);
    $finish;
end
endmodule
