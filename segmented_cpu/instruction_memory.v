// =============================================================================
// instruction_memory.v - Memoria de instrucciones (programa) de la CPU.
// Lectura combinacional: la instruccion esta disponible en el mismo ciclo.
// La direccion llega en bytes; addr[1:0] se descarta (acceso a palabra).
//
// Carga del programa "desde afuera" (no horneado en el HDL):
//   - SIMULACION (`define SIMULATION, ver Makefile -DSIMULATION): se inicializa
//     con $readmemh(HEX_FILE) para que los testbenches elijan el programa con
//     defparam dut.u_imem.HEX_FILE.
//   - SINTESIS (Quartus, sin SIMULATION): la RAM on-chip se inicializa desde
//     program.mif (atributo ram_init_file). Para cambiar el programa NO se
//     recompila el HDL: se regenera program.mif (assembler) y se actualiza con
//     "Update Memory Initialization File" + Assembler, o se edita en vivo por
//     JTAG con el In-System Memory Content Editor. Ver docs/program-loading.md.
//
// Si en la placa el atributo ram_init_file diera problemas, definir SIMULATION
// tambien en sintesis hace que vuelva a $readmemh(program.hex) (camino probado
// del monociclo).
// =============================================================================
module instruction_memory #(
    parameter HEX_FILE  = "program.hex",
    parameter MEM_DEPTH = 1024
) (
    input  [31:0] addr,   // direccion byte desde el PC
    output [31:0] instr   // instruccion de 32 bits
);

`ifdef SIMULATION
reg [31:0] mem [0:MEM_DEPTH-1];
initial begin
    $readmemh(HEX_FILE, mem);
end
`else
(* ram_init_file = "program.mif" *) reg [31:0] mem [0:MEM_DEPTH-1];
`endif

assign instr = mem[addr[31:2]];

endmodule
