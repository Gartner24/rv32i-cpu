// =============================================================================
// adder.v - Sumador de 32 bits
// Se instancia dos veces en top.v: una para calcular PC+4 y otra para
// calcular PC+inmediato (dirección de salto). No tiene clock porque es
// combinacional puro - la salida cambia instantáneamente con las entradas.
// =============================================================================
module adder (
    input [31:0] a,
    input [31:0] b,
    output [31:0] out
);

assign out = a + b;

endmodule
