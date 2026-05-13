// =============================================================================
// instruction_memory.v - Memoria de Instrucciones (ROM)
// Almacena el programa a ejecutar. Solo lectura durante la operación normal.
// Al inicio de la simulación carga el archivo "program.hex" generado por
// el ensamblador. La dirección es en bytes (como en RISC-V real), pero como
// cada instrucción ocupa 4 bytes, se indexa el array con addr[31:2],
// descartando los 2 bits menos significativos (equivale a dividir entre 4).
// =============================================================================
module instruction_memory #(
    parameter HEX_FILE  = "program.hex",
    parameter MEM_DEPTH = 256
) (
    input  [31:0] addr,   // dirección byte desde el PC
    output [31:0] instr   // instrucción de 32 bits
);

reg [31:0] mem [0:MEM_DEPTH-1];

initial begin
    $readmemh(HEX_FILE, mem);
end

// Lectura combinacional: la instrucción está disponible inmediatamente
assign instr = mem[addr[31:2]];

endmodule
