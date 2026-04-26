// =============================================================================
// instruction_memory.v - Memoria de Instrucciones (ROM)
// Almacena el programa a ejecutar. Solo lectura durante la operación normal.
// Al inicio de la simulación carga el archivo "program.hex" generado por
// el ensamblador. La dirección es en bytes (como en RISC-V real), pero como
// cada instrucción ocupa 4 bytes, se indexa el array con addr[31:2],
// descartando los 2 bits menos significativos (equivale a dividir entre 4).
// =============================================================================
module instruction_memory (
    input  [31:0] addr,   // dirección byte desde el PC
    output [31:0] instr   // instrucción de 32 bits
);

reg [31:0] mem [0:1023]; // 1024 palabras = 4 KB de programa

initial begin
    $readmemh("program.hex", mem);
end

// Lectura combinacional: la instrucción está disponible inmediatamente
assign instr = mem[addr[31:2]];

endmodule
