// =============================================================================
// instruction_memory.v - ROM de 256 instrucciones que contiene el programa.
// Carga program.hex al inicio de la simulacion/sintesis.
// La direccion llega en bytes; addr[1:0] se descarta porque cada instruccion
// ocupa 4 bytes (acceso siempre alineado a palabra).
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
