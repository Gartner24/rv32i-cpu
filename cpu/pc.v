// =============================================================================
// pc.v - Contador de Programa (Program Counter)
// Registro de 32 bits que guarda la dirección de la instrucción actual.
// En cada flanco de subida del reloj carga el siguiente PC que viene de top.v
// (que puede ser PC+4 o una dirección de salto).
// Con reset activo vuelve a 0x00000000 - punto de inicio del programa.
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
