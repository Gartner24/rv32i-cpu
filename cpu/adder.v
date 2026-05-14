// =============================================================================
// adder.v - Sumador combinacional de 32 bits.
// Instanciado dos veces en top.v: u_pc_plus4 calcula PC+4,
// u_pc_branch calcula PC+offset para saltos.
// =============================================================================
module adder (
    input [31:0] a,
    input [31:0] b,
    output [31:0] out
);

assign out = a + b;

endmodule
