// =============================================================================
// mux2to1.v - Multiplexor 2 a 1 de 32 bits
// sel=0 -> sale a,  sel=1 -> sale b
// =============================================================================
module mux2to1 (
    input         sel,
    input  [31:0] a,
    input  [31:0] b,
    output [31:0] out
);

assign out = sel ? b : a;

endmodule
