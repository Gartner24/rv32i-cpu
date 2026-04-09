// =============================================================================
// mux2to1.v - Multiplexor 2 a 1 de 32 bits
// Selecciona entre dos entradas según la señal 'sel'.
// Se usa varias veces en el datapath:
//   - Elige entre rs2 o inmediato como operando B de la ALU (alu_src)
//   - Elige entre rs1 o PC como operando A de la ALU (alu_a_src, para AUIPC)
//   - Elige entre PC+4 o dirección de salto como siguiente PC (pc_src)
//   - Elige entre resultado de la ALU o dato de memoria para escribir en rd
//   - Elige entre resultado normal o PC+4 para JAL
// =============================================================================
module mux2to1 (
    input         sel,
    input  [31:0] a,
    input  [31:0] b,
    output [31:0] out
);

// sel=0 -> sale 'a', sel=1 -> sale 'b'
assign out = sel ? b : a;

endmodule
