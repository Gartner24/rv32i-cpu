// =============================================================================
// data_memory.v - RAM de la CPU (variables y stack). Bloque autocontenido:
// escritura sincronica en la etapa MEM y lectura combinacional en el mismo
// ciclo. addr llega en bytes; se usa addr[31:2] como indice de palabra.
//
// El tamano se fija con el parametro WORDS (por defecto 256 palabras = 1 KB).
// debug_addr se dimensiona solo segun WORDS, asi que cambiar WORDS ajusta toda
// la cadena (memoria, puerto de depuracion y, en top, el navegador de paginas).
// WORDS debe ser potencia de 2 y multiplo de 32 (una pagina = 32 palabras).
// =============================================================================
module data_memory #(
    parameter WORDS = 256
) (
    input         clk,
    input         mem_write,     // habilita escritura (ya con valido y cpu_enable)
    input         mem_read,
    input  [31:0] addr,
    input  [31:0] write_data,
    output [31:0] read_data,
    input  [$clog2(WORDS)-1:0] debug_addr,  // palabra a mostrar en la VGA
    output [31:0] debug_data
);

reg [31:0] memory [0:WORDS-1];

always @(posedge clk) begin
    if (mem_write)
        memory[addr[31:2]] <= write_data;
end

assign read_data  = mem_read ? memory[addr[31:2]] : 32'b0;
assign debug_data = memory[debug_addr];

endmodule
