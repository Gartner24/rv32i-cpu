// =============================================================================
// alu.v - Arithmetic Logic Unit
// Performs all compute operations required by RV32I.
// Receives a 4-bit control signal (from alu_control.v) and two 32-bit operands.
//
// The 'zero' flag is true when result == 0.
// BEQ uses this: it subtracts rs2 from rs1; if result is zero, they are equal.
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
        4'b0000: result = a + b;  // ADD: suma a + b
        4'b0001: result = a - b;  // SUB: resta a - b
        4'b0100: result = a ^  b;  // XOR: XOR bit a bit
        4'b0011: result = a | b;  // OR:  OR bit a bit
        4'b0010: result = a & b;  // AND: AND bit a bit
        4'b0101: result = a << b[4:0];  // SLL: shift left lógico, usa b[4:0] bits
        4'b0110: result = a >> b[4:0];  // SRL: shift right lógico (rellena con ceros)
        4'b0111: result = $signed(a) >>> b[4:0];  // SRA: shift right aritmético (rellena con el bit de signo)
        4'b1000: result = $signed(a) < $signed(b) ? 32'd1 : 32'd0;  // SLT: si a < b (con signo) -> result = 1, sino 0
        4'b1001: result = (a < b) ? 32'd1 : 32'd0;  // SLTU: igual pero sin signo
        default: result = 32'b0;
    endcase
end

assign zero = (result == 32'b0);


endmodule
