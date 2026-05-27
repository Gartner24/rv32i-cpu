// =============================================================================
// instruction_memory.v - Memoria de programa de la CPU.
//
// LECTURA SINCRONICA (registrada) para que Quartus infiera bloque M10K. El
// registro de salida ES el registro de instruccion IF/ID: presenta mem[PC] un
// ciclo despues, justo cuando la etapa ID lo necesita (alineado con if_id_pc en
// top.v). Por eso pipe_ifid ya NO latchea la instruccion. read_en avanza el
// fetch igual que pipe_ifid (cpu_enable & ~stall); el flush se aplica afuera via
// el bit valid (if_id_instruction = valid ? instr : NOP).
//
// El programa se inicializa con $readmemh(HEX_FILE); Quartus respeta el init en
// sintesis. Los testbenches eligen el programa con
// `defparam dut.u_instruction_memory.HEX_FILE`.
// =============================================================================
module instruction_memory #(
    parameter HEX_FILE  = "program.hex",
    parameter MEM_DEPTH = 1024
) (
    input         clk,
    input         rst,
    input         read_en,        // avanza el fetch (= cpu_enable & ~stall)
    input  [31:0] addr,           // direccion byte desde el PC
    output [31:0] instr,          // instruccion registrada (llega en ID)
    input  [31:0] debug_addr,     // indice de palabra para la VGA
    output [31:0] debug_instr     // instruccion en debug_addr (registrada)
);

localparam [31:0] NOP_INSTRUCTION = 32'h00000013;
localparam IAW = $clog2(MEM_DEPTH);

(* ramstyle = "M10K" *) reg [31:0] mem [0:MEM_DEPTH-1];
initial begin
    $readmemh(HEX_FILE, mem);
end

// Fetch: registro de salida (= registro de instruccion IF/ID).
reg [31:0] instr_q;
always @(posedge clk) begin
    if (rst)          instr_q <= NOP_INSTRUCTION;
    else if (read_en) instr_q <= mem[addr[IAW+1:2]];
end
assign instr = instr_q;

// Puerto de depuracion para la VGA (registrado, corre siempre).
reg [31:0] dbg_q;
always @(posedge clk) dbg_q <= mem[debug_addr[IAW-1:0]];
assign debug_instr = dbg_q;

endmodule
