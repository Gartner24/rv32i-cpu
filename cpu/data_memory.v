// =============================================================================
// data_memory.v - Memoria de Datos (combinacional pura)
// Decodifica lecturas del arreglo mem_flat que viene de top.v.
// Los flip-flops de escritura viven en top.v para que este modulo
// sea puramente combinacional (sin clk), cumpliendo la regla monociclo.
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
