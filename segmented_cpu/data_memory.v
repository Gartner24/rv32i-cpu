// =============================================================================
// data_memory.v - RAM de datos byte-direccionable (variables y stack).
// Almacena por bytes: 4 carriles de byte por palabra, con escritura por byte
// (byte_we[k] habilita el byte k). Una palabra = 4 bytes concatenados
// (little-endian). Lectura combinacional de la palabra completa; la seleccion y
// extension sub-palabra (lb/lh/lbu/lhu) se hace en la etapa WB de top.v.
//
// El tamano se fija con WORDS (por defecto 256 palabras = 1 KB). addr llega en
// bytes; addr[AW+1:2] es el indice de palabra y addr[1:0] el byte dentro de ella.
// =============================================================================
module data_memory #(
    parameter WORDS = 256
) (
    input         clk,
    input         mem_read,
    input  [3:0]  byte_we,       // habilitacion por byte (ya con valido & cpu_enable & store)
    input  [31:0] addr,
    input  [31:0] write_data,    // dato ya alineado al carril destino
    output [31:0] read_data,
    input  [$clog2(WORDS)-1:0] debug_addr,  // palabra a mostrar en la VGA
    output [31:0] debug_data
);

localparam AW = $clog2(WORDS);
wire [AW-1:0] w = addr[AW+1:2];

reg [31:0] memory [0:WORDS-1];

always @(posedge clk) begin
    if (byte_we[0]) memory[w][7:0]   <= write_data[7:0];
    if (byte_we[1]) memory[w][15:8]  <= write_data[15:8];
    if (byte_we[2]) memory[w][23:16] <= write_data[23:16];
    if (byte_we[3]) memory[w][31:24] <= write_data[31:24];
end

assign read_data  = mem_read ? memory[w] : 32'b0;
assign debug_data = memory[debug_addr];

endmodule
