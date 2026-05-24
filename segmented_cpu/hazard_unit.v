// =============================================================================
// hazard_unit.v - Deteccion de riesgo de uso-tras-carga (load-use).
// Si la instruccion en EX es una carga (mem_read) y su destino coincide con
// un registro fuente de la instruccion en ID, hay que insertar una burbuja de
// 1 ciclo: el dato cargado solo estara disponible (via forwarding MEM/WB) un
// ciclo despues. Combinacional.
//
// load_use_stall = 1 -> congelar PC e IF/ID, e inyectar burbuja en ID/EX.
// =============================================================================
module hazard_unit (
    input        idex_valid,
    input        idex_mem_read,
    input  [4:0] idex_rd,
    input  [4:0] ifid_rs1,
    input  [4:0] ifid_rs2,
    output       load_use_stall
);

assign load_use_stall = idex_valid && idex_mem_read && (idex_rd != 5'b0) &&
                        ((idex_rd == ifid_rs1) || (idex_rd == ifid_rs2));

endmodule
