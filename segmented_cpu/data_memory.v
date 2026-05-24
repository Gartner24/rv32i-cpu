// =============================================================================
// data_memory.v - RAM de 256 palabras (1 KB) de la CPU (variables y stack).
// Bloque autocontenido (como en el diagrama): escritura sincronica en la etapa
// MEM y lectura combinacional en el mismo ciclo. addr llega en bytes; se usa
// addr[31:2] como indice de palabra (acceso alineado).
// =============================================================================
module data_memory (
    input         clk,
    input         mem_write,    // habilita escritura (ya con valid y cpu_en)
    input         mem_read,
    input  [31:0] addr,
    input  [31:0] write_data,
    output [31:0] read_data,
    input  [4:0]  debug_addr,   // palabra 0..31 a mostrar en la VGA
    output [31:0] debug_data
);

reg [31:0] mem [0:255];

always @(posedge clk) begin
    if (mem_write)
        mem[addr[31:2]] <= write_data;
end

assign read_data  = mem_read ? mem[addr[31:2]] : 32'b0;
assign debug_data = mem[debug_addr];

endmodule
