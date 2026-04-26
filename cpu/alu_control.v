// =============================================================================
// alu_control.v - ALU Control
// Takes the 2-bit alu_op hint from the main control unit plus funct3 and
// funct7 from the instruction, and produces the 4-bit alu_ctrl signal that
// tells the ALU exactly which operation to perform.
//
// This two-level decode keeps control_unit simple (it only looks at opcode)
// and localizes all arithmetic decoding here.
//
// alu_ctrl encoding:
//   0000 = ADD
//   0001 = SUB
//   0010 = AND
//   0011 = OR
//   0100 = XOR
//   0101 = SLL  (shift left logical)
//   0110 = SRL  (shift right logical)
//   0111 = SRA  (shift right arithmetic)
//   1000 = SLT  (set less than, signed)
//   1001 = SLTU (set less than, unsigned)
// =============================================================================
module alu_control (
    input [1:0] alu_op,    // viene de control_unit
    input [2:0] func3,     // viene de la instrucción
    input [6:0] func7,     // viene de la instrucción
    output reg [3:0] alu_ctrl  // va a la ALU
);

always @(*) begin
    case (alu_op)
        2'b00: alu_ctrl = 4'b0000; // ADD fijo - loads y stores solo necesitan sumar base + offset
        2'b01: alu_ctrl = 4'b0001; // SUB fijo - branches comparan restando rs1 - rs2
        2'b10: begin
            case (func3)
                3'b000: alu_ctrl = func7[5] ? 4'b0001 : 4'b0000; // SUB : ADD
                3'b100: alu_ctrl = 4'b0100; // XOR
                3'b110: alu_ctrl = 4'b0011; // OR
                3'b111: alu_ctrl = 4'b0010; // AND
                3'b001: alu_ctrl = 4'b0101; // SLL
                3'b101: alu_ctrl = func7[5] ? 4'b0111 : 4'b0110; // SRA : SRL
                3'b010: alu_ctrl = 4'b1000; // SLT
                3'b011: alu_ctrl = 4'b1001; // SLTU
                default: alu_ctrl = 4'b0000;
            endcase
        end

        default: alu_ctrl = 4'b0000;
    endcase
end

endmodule
