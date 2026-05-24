// =============================================================================
// pc.v - Registro de 32 bits que apunta a la instruccion en curso.
// Cada ciclo activo (cpu_en=1) avanza a pc_next (PC+4 o direccion de salto).
// Reset sincrono vuelve a 0x00000000.
// =============================================================================
module pc (
    input             clk,
    input             rst,
    input             en,       // clock enable (0 = freeze)
    input      [31:0] pc_next,  // siguiente dirección (viene de top.v)
    output reg [31:0] pc_out    // dirección actual (va a instruction_memory)
);

always @(posedge clk or posedge rst) begin
    if (rst)
        pc_out <= 32'h00000000;
    else if (en)
        pc_out <= pc_next;
end

endmodule
