// Integration test: runs assembler/final_test.hex until ebreak, asserts x10==0.
// Tests: multiplicar, valor_absoluto, maximo, fibonacci, mcd
`timescale 1ns/1ps
module top_final_test_tb;

defparam dut.u_imem.HEX_FILE  = "../../assembler/final_test.hex";
defparam dut.u_imem.MEM_DEPTH = 1024;

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

initial begin
    errors = 0; cycle_count = 0;
    CLOCK_50 = 0;
    KEY = 4'hF;
    SW  = 10'h0;

    // Reset
    KEY[0] = 0;
    @(posedge CLOCK_50); @(posedge CLOCK_50); @(posedge CLOCK_50);
    KEY[0] = 1;

    // Run until halted or timeout (10000 cycles)
    while (!dut.halted && cycle_count < 10000) begin
        @(posedge CLOCK_50);
        cycle_count = cycle_count + 1;
    end
    #1;

    if (!dut.halted) begin
        $display("FAIL: final_test did not halt within %0d cycles", cycle_count);
        errors = errors + 1;
    end else begin
        if (dut.regs[10] !== 32'd0) begin
            $display("FAIL: final_test x10 (exit code) expected 0 got %0d (0x%0h)",
                     $signed(dut.regs[10]), dut.regs[10]);
            errors = errors + 1;
        end else begin
            $display("PASS: final_test halted in %0d cycles, x10=0", cycle_count);
        end
    end

    if (errors == 0) $display("PASS: top_final_test");
    else             $display("FAIL: top_final_test (%0d errors)", errors);
    $finish;
end
endmodule
