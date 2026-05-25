// Test de LUI (Step de correccion del bug de LUI).
// Programa en pipe_lui.hex:
//   addi x6, x0, 100     # x6 = 100 (nonzero). El campo rs1 de la instruccion
//                        # LUI de abajo resulta ser x6, asi que con el bug
//                        # viejo (operando A = rs1) LUI daria 100 + imm.
//   nop; nop
//   lui  x5, 0x30        # x5 debe ser 0x00030000 (= 0x30 << 12), NO 0x30000+100
//   nop; nop
//   ebreak
// Con el bug: x5 = 0x00030000 + 100 = 0x00030064. Con el fix: x5 = 0x00030000.
`timescale 1ns/1ps
module pipe_lui_tb;

defparam dut.u_instruction_memory.HEX_FILE  = "pipe_lui.hex";
defparam dut.u_instruction_memory.MEM_DEPTH = 256;

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

integer errors, cyc;
initial begin
    errors = 0; CLOCK_50 = 0; KEY = 4'hF; SW = 10'h0;
    KEY[0] = 0;
    @(posedge CLOCK_50); @(posedge CLOCK_50); @(posedge CLOCK_50);
    KEY[0] = 1;

    cyc = 0;
    while (!dut.halted && cyc < 1000) begin @(posedge CLOCK_50); cyc = cyc + 1; end
    #1;

    if (!dut.halted) begin
        $display("FAIL: pipe_lui did not halt"); errors = errors + 1;
    end else begin
        if (dut.u_register_file.registers[6] !== 32'd100) begin
            $display("FAIL: x6 expected 100 got %0d", dut.u_register_file.registers[6]);
            errors = errors + 1;
        end
        if (dut.u_register_file.registers[5] !== 32'h00030000) begin
            $display("FAIL: x5 (lui) expected 0x00030000 got 0x%08h",
                     dut.u_register_file.registers[5]);
            errors = errors + 1;
        end
    end

    if (errors == 0) $display("PASS: pipe_lui (x5=0x00030000)");
    else             $display("FAIL: pipe_lui (%0d errors)", errors);
    $finish;
end
endmodule
