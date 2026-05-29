`timescale 1ns/1ps
// Traza por ciclo del pipeline (lo mismo que se ve en la VGA en modo paso).
// Programa elegido con -PHEXF. Imprime, por ciclo: PC de fetch, la instruccion
// en cada etapa, ALU, destino+we de WB y las senales de riesgo.
module trace_tb;
    parameter HEXF = "../../assembler/each-instruction.hex";
    reg         CLOCK_50 = 0;
    reg  [3:0]  KEY = 4'b1111;
    reg  [9:0]  SW  = 10'b0;
    wire [9:0]  LEDR;
    wire [7:0]  R,G,B; wire HS,VS,CK,BL,SY;
    top #(.DEBOUNCE_LIMIT(2)) dut (
        .CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW), .LEDR(LEDR),
        .VGA_R(R), .VGA_G(G), .VGA_B(B), .VGA_HS(HS), .VGA_VS(VS),
        .VGA_CLK(CK), .VGA_BLANK_N(BL), .VGA_SYNC_N(SY));
    defparam dut.u_instruction_memory.HEX_FILE = HEXF;
    always #10 CLOCK_50 = ~CLOCK_50;
    integer cyc;
    initial begin
        KEY[0] = 0; repeat (3) @(posedge CLOCK_50); KEY[0] = 1;
        $display("cyc| IFpc    | ID       EX       MEM      WB       |aluEX   |WBrd we|fl st fA fB");
        cyc = 0;
        while (!dut.halted && cyc < 250) begin
            @(negedge CLOCK_50);
            $display("%3d| %08h| %08h %08h %08h %08h|%08h| x%0d  %0d|%0d  %0d  %0d  %0d",
                cyc, dut.pc_out,
                dut.if_id_instruction, dut.id_ex_instruction,
                dut.ex_mem_instruction, dut.mem_wb_instruction,
                dut.alu_result, dut.write_back_rd, dut.write_back_enable,
                dut.flush, dut.load_use_stall, dut.forward_a, dut.forward_b);
            @(posedge CLOCK_50); cyc = cyc + 1;
        end
        $display("HALTED after %0d cycles", cyc);
        $finish;
    end
endmodule
