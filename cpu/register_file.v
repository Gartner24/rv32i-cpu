// =============================================================================
// register_file.v - Banco de Registros
// Implementa los 32 registros de propósito general x0–x31 de RV32I.
// Tiene dos puertos de lectura combinacionales (rs1, rs2) y un puerto de
// escritura síncrono (rd). El registro x0 siempre devuelve cero y no se puede
// escribir - esto se garantiza en la lógica de lectura.
// =============================================================================
module register_file (
    input   reg_write,           // habilita escritura (desde control_unit)
    input   en,                  // clock enable (0 = freeze writes)
    input   rst,                 // reset activo-alto: pone todos los registros a 0
    input   [4:0]  rs1,          // dirección del primer registro a leer
    input   [4:0]  rs2,          // dirección del segundo registro a leer
    input   [4:0]  rd,           // dirección del registro a escribir
    input   [31:0] write_data,   // dato a escribir en rd
    output  [31:0] read_data1,   // valor leído de rs1
    output  [31:0] read_data2,   // valor leído de rs2
    input   [4:0]  debug_addr,   // registro a inspeccionar (desde switches)
    output  [31:0] debug_data,   // valor del registro inspeccionado
    output  [31:0] exit_code     // siempre lee x10 (a0) - codigo de salida de main
);

reg [31:0] regs [0:31];
integer i;

always @(*) begin
    if (rst) begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'b0;
    end else if (reg_write && en && rd != 5'b0)
        regs[rd] = write_data;
end

// Lectura combinacional - x0 siempre devuelve cero sin importar lo almacenado
assign read_data1  = (rs1 == 5'b0) ? 32'b0 : regs[rs1];
assign read_data2  = (rs2 == 5'b0) ? 32'b0 : regs[rs2];
assign debug_data  = (debug_addr == 5'b0) ? 32'b0 : regs[debug_addr];
assign exit_code   = regs[10];

endmodule
