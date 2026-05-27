// =============================================================================
// instruction_memory.v - Memoria de instrucciones (programa) de la CPU.
// Lectura combinacional: la instruccion esta disponible en el mismo ciclo.
// La direccion llega en bytes; addr[1:0] se descarta (acceso a palabra).
//
// El programa se inicializa con $readmemh(HEX_FILE). Quartus respeta este init
// tambien en sintesis (la memoria se implementa como logica/ROM con esos
// valores constantes), igual que la font_rom de la VGA. En simulacion los
// testbenches eligen el programa con `defparam dut.u_instruction_memory.HEX_FILE`.
//
// Carga "desde afuera": el assembler tambien genera program.mif. Para cambiar
// el programa sin recompilar el HDL se usa el In-System Memory Content Editor
// (requiere implementar esta memoria como IP de RAM con el flag de edicion
// in-system) o "Update MIF" + Assembler. Ver docs/program-loading.md.
// =============================================================================
module instruction_memory #(
    parameter HEX_FILE  = "program.hex",
    parameter MEM_DEPTH = 1024
) (
    input  [31:0] addr,         // direccion byte desde el PC
    output [31:0] instr,        // instruccion de 32 bits (fetch)
    input  [31:0] debug_addr,   // indice de palabra a mostrar en la VGA
    output [31:0] debug_instr   // instruccion en debug_addr (lectura combinacional)
);

reg [31:0] mem [0:MEM_DEPTH-1];

initial begin
    $readmemh(HEX_FILE, mem);
end

assign instr       = mem[addr[31:2]];
assign debug_instr = mem[debug_addr[9:0]];

endmodule
