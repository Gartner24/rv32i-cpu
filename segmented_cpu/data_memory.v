// =============================================================================
// data_memory.v - RAM de datos byte-direccionable (variables y stack).
// Almacena por bytes: 4 carriles de byte por palabra, con escritura por byte
// (byte_we[k] habilita el byte k). Una palabra = 4 bytes concatenados
// (little-endian). La seleccion y extension sub-palabra (lb/lh/lbu/lhu) se hace
// en la etapa WB de top.v.
//
// LECTURA SINCRONICA (registrada) para que Quartus infiera bloque M10K en vez de
// logica. El dato sale un ciclo despues de presentar la direccion, llegando a la
// etapa WB; read_en (= cpu_enable) congela el registro en modo paso/halt.
//
// addr llega en bytes; addr[AW+1:2] es el indice de palabra, addr[1:0] el byte.
// Tamano fijado por WORDS (por defecto 256 palabras = 1 KB).
// =============================================================================
module data_memory #(
    parameter WORDS = 256
) (
    input         clk,
    input         read_en,       // habilita el registro de lectura (= cpu_enable)
    input         mem_read,
    input  [3:0]  byte_we,        // habilitacion por byte (ya con valido & cpu_enable & store)
    input  [31:0] addr,
    input  [31:0] write_data,     // dato ya alineado al carril destino
    output [31:0] read_data,
    input  [$clog2(WORDS)-1:0] debug_addr,  // palabra a mostrar en la VGA
    output [31:0] debug_data
);

localparam AW = $clog2(WORDS);
wire [AW-1:0] w = addr[AW+1:2];

(* ramstyle = "M10K" *) reg [31:0] memory [0:WORDS-1];

// Puerto A: escritura por byte.
always @(posedge clk) begin
    if (byte_we[0]) memory[w][7:0]   <= write_data[7:0];
    if (byte_we[1]) memory[w][15:8]  <= write_data[15:8];
    if (byte_we[2]) memory[w][23:16] <= write_data[23:16];
    if (byte_we[3]) memory[w][31:24] <= write_data[31:24];
end

// Puerto A: lectura registrada (llega en WB). Congelada por read_en.
reg [31:0] read_q;
always @(posedge clk)
    if (read_en)
        read_q <= mem_read ? memory[w] : 32'b0;
assign read_data = read_q;

// Puerto B: solo-lectura para la VGA (registrado, corre siempre).
reg [31:0] debug_q;
always @(posedge clk)
    debug_q <= memory[debug_addr];
assign debug_data = debug_q;

endmodule
