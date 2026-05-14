// =============================================================================
// data_memory.v - RAM de 256 palabras (1 KB) para variables y stack.
// Recibe el arreglo de datos empaquetado desde top.v (donde viven los FF).
// Devuelve el dato en addr de forma combinacional en el mismo ciclo.
// =============================================================================
module data_memory (
    input  [256*32-1:0] mem_flat,  // 256 palabras x 32 bits, empaquetadas
    input  mem_read,
    input  [31:0] addr,
    output [31:0] read_data
);

wire [31:0] mem [0:255];
genvar gi;

generate
    for (gi = 0; gi < 256; gi = gi + 1) begin : unpack
        assign mem[gi] = mem_flat[32*gi +: 32];
    end
endgenerate

assign read_data = mem_read ? mem[addr[31:2]] : 32'b0;

endmodule
