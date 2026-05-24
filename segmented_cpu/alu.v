// =============================================================================
// alu.v - Unidad Aritmetico-Logica RV32I
// Realiza la operacion indicada por alu_ctrl sobre dos operandos de 32 bits.
// La senal zero se activa cuando result == 0; la usan BEQ y BNE para decidir
// si el salto se toma o no.
// =============================================================================
module alu (
    input [31:0] a,
    input [31:0] b,
    input [3:0] alu_ctrl,
    output reg [31:0] result,
    output zero
);

always @(*) begin
    case (alu_ctrl)
        4'b0000: result = a + b;                                         // ADD
        4'b0001: result = a - b;                                         // SUB
        4'b0100: result = a ^  b;                                        // XOR
        4'b0011: result = a | b;                                         // OR
        4'b0010: result = a & b;                                         // AND
        4'b0101: result = a << b[4:0];                                   // SLL
        4'b0110: result = a >> b[4:0];                                   // SRL
        4'b0111: result = $signed(a) >>> b[4:0];                         // SRA (extiende bit de signo)
        4'b1000: result = $signed(a) < $signed(b) ? 32'd1 : 32'd0;      // SLT  (con signo)
        4'b1001: result = (a < b)                 ? 32'd1 : 32'd0;      // SLTU (sin signo)
        default: result = 32'b0;
    endcase
end

assign zero = (result == 32'b0);


endmodule
