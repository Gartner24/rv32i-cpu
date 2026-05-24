// =============================================================================
// forwarding_unit.v - Unidad de adelantamiento (forwarding) del pipeline.
// Compara los registros fuente de la instruccion en EX contra los destinos
// de las instrucciones en EX/MEM y MEM/WB para evitar burbujas por
// dependencias de datos (RAW). Combinacional.
//
//   forward = 2'b10 -> adelantar desde EX/MEM (resultado de la etapa previa)
//   forward = 2'b01 -> adelantar desde MEM/WB (valor de write-back)
//   forward = 2'b00 -> usar el valor leido del banco de registros (ID/EX)
//
// EX/MEM tiene prioridad sobre MEM/WB (dato mas reciente). Nunca se adelanta
// desde/para x0.
// =============================================================================
module forwarding_unit (
    input  [4:0] ex_rs1,
    input  [4:0] ex_rs2,
    input        mem_reg_write,
    input  [4:0] mem_rd,
    input        wb_reg_write,
    input  [4:0] wb_rd,
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);

always @(*) begin
    // Operando A (rs1)
    if (mem_reg_write && (mem_rd != 5'b0) && (mem_rd == ex_rs1))
        forward_a = 2'b10;
    else if (wb_reg_write && (wb_rd != 5'b0) && (wb_rd == ex_rs1))
        forward_a = 2'b01;
    else
        forward_a = 2'b00;

    // Operando B (rs2)
    if (mem_reg_write && (mem_rd != 5'b0) && (mem_rd == ex_rs2))
        forward_b = 2'b10;
    else if (wb_reg_write && (wb_rd != 5'b0) && (wb_rd == ex_rs2))
        forward_b = 2'b01;
    else
        forward_b = 2'b00;
end

endmodule
