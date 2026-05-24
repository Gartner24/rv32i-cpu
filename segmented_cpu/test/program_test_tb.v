// Banco de prueba generico para correr cualquier programa del ensamblador en la
// CPU segmentada. El programa se elige al compilar con -Pprogram_test_tb.HEXF=...
//
// Convencion (igual que el crt0 del ensamblador): main() devuelve 0 en x10 (a0)
// si todos los chequeos pasan, o -N si fallo el chequeo N. El crt0 hace
// "call main; ebreak", asi que al detenerse (halt) x10 tiene el codigo de salida.
//
// Reporta los ciclos y el tiempo real equivalente a 50 MHz (1 ciclo = 20 ns).
`timescale 1ns/1ps
module program_test_tb;

parameter HEXF   = "../../assembler/test_arith.hex"; // override con -P
parameter DEPTH  = 1024;
parameter MAXCYC = 50000;

defparam dut.u_instruction_memory.HEX_FILE  = HEXF;
defparam dut.u_instruction_memory.MEM_DEPTH = DEPTH;

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

integer cyc;
initial begin
    CLOCK_50 = 0; KEY = 4'hF; SW = 10'h0;

    KEY[0] = 0;
    @(posedge CLOCK_50); @(posedge CLOCK_50); @(posedge CLOCK_50);
    KEY[0] = 1;

    cyc = 0;
    while (!dut.halted && cyc < MAXCYC) begin
        @(posedge CLOCK_50);
        cyc = cyc + 1;
    end
    #1;

    if (!dut.halted)
        $display("FAIL: %0s did not halt within %0d cycles", HEXF, cyc);
    else if (dut.u_register_file.registers[10] !== 32'd0)
        $display("FAIL: %0s exit code x10 = %0d (fallo el chequeo numero %0d)",
                 HEXF, $signed(dut.u_register_file.registers[10]),
                 -$signed(dut.u_register_file.registers[10]));
    else
        $display("PASS: %0s  (%0d ciclos = %0d ns @50MHz)", HEXF, cyc, cyc*20);

    $finish;
end
endmodule
