// =============================================================================
// data_memory.v - Memoria de Datos (RAM)
// Aquí viven las variables del programa mientras corre (heap, stack, globales).
// La escritura es síncrona (necesita flanco de reloj).
// La lectura es combinacional (instantánea, sin reloj).
// Por ahora solo soporta acceso de palabra completa de 32 bits (lw/sw).
// El soporte de byte (lb/sb) y media palabra (lh/sh) se puede agregar después.
// =============================================================================
module data_memory (
    input mem_write,   // señal de escritura desde control_unit
    input mem_read,    // señal de lectura desde control_unit
    input en,          // clock enable (0 = freeze writes)
    input [31:0] addr,        // dirección calculada por la ALU
    input [31:0] write_data,  // dato a escribir (valor de rs2)
    output [31:0] read_data    // dato leído (va al mux de writeback)
);

reg [31:0] mem [0:255];  // 256 palabras = 1 KB de datos

// Escritura en flanco de subida de en (un tick = una escritura)
always @(posedge en) begin
    if (mem_write)
        mem[addr[31:2]] <= write_data;
end

// Lectura combinacional - si mem_read está activo devuelve el dato, sino cero
assign read_data = mem_read ? mem[addr[31:2]] : 32'b0;

endmodule
