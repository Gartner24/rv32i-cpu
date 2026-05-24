// =============================================================================
// register_file.v - Banco de 32 registros de 32 bits (x0..x31) del pipeline.
// Bloque autocontenido (como en el diagrama): tiene su puerto de escritura
// sincronico (etapa WB) y dos lecturas combinacionales (etapa ID).
//   - x0 siempre lee 0.
//   - Bypass write-first interno: si en este ciclo se escribe el mismo registro
//     que se lee, la lectura devuelve el dato que se esta escribiendo. Esto
//     cubre la dependencia RAW a distancia 3 (productor en WB, consumidor en ID)
//     que el forwarding EX/MEM y MEM/WB no alcanza.
// =============================================================================
module register_file (
    input         clk,
    input         rst,
    input         write_enable,   // habilita escritura (RegWrite, ya con rd!=0 y valido)
    input  [4:0]  write_reg,       // registro destino (rd de la etapa WB)
    input  [31:0] write_data,      // dato a escribir (mux de write-back)
    input  [4:0]  rs1,
    input  [4:0]  rs2,
    input  [4:0]  debug_addr,      // registro a mostrar en la VGA
    output [31:0] read_data1,
    output [31:0] read_data2,
    output [31:0] debug_data
);

reg [31:0] registers [0:31];
integer i;

always @(posedge clk or posedge rst) begin
    if (rst)
        for (i = 0; i < 32; i = i + 1) registers[i] <= 32'b0;
    else if (write_enable && (write_reg != 5'b0))
        registers[write_reg] <= write_data;
end

assign read_data1 = (rs1 == 5'b0)                      ? 32'b0      :
                    (write_enable && (write_reg == rs1)) ? write_data : registers[rs1];
assign read_data2 = (rs2 == 5'b0)                      ? 32'b0      :
                    (write_enable && (write_reg == rs2)) ? write_data : registers[rs2];
assign debug_data = (debug_addr == 5'b0)               ? 32'b0      : registers[debug_addr];

endmodule
