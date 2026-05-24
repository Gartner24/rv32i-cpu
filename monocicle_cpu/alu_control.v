// =============================================================================
// alu_control.v - Determina la operacion exacta que debe ejecutar la ALU.
// Combina alu_op (hint de 2 bits de control_unit) con funct3 y funct7
// de la instruccion para producir alu_ctrl de 4 bits.
// Segundo nivel de decodificacion: control_unit solo mira el opcode;
// este modulo resuelve el detalle aritmetico.
//
// Tabla alu_ctrl:
//   0000=ADD  0001=SUB  0010=AND  0011=OR   0100=XOR
//   0101=SLL  0110=SRL  0111=SRA  1000=SLT  1001=SLTU
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
        2'b01: case (func3)
            3'b000, 3'b001: alu_ctrl = 4'b0001; // BEQ/BNE -> SUB
            3'b100, 3'b101: alu_ctrl = 4'b1000; // BLT/BGE  -> SLT  (signed)
            3'b110, 3'b111: alu_ctrl = 4'b1001; // BLTU/BGEU -> SLTU
            default:        alu_ctrl = 4'b0001;
        endcase
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

        // I-type aritmetico: funct3=000 siempre es ADD (func7 forma parte del inmediato, no del opcode)
        2'b11: begin
            case (func3)
                3'b000: alu_ctrl = 4'b0000; // addi
                3'b100: alu_ctrl = 4'b0100; // xori
                3'b110: alu_ctrl = 4'b0011; // ori
                3'b111: alu_ctrl = 4'b0010; // andi
                3'b001: alu_ctrl = 4'b0101; // slli
                3'b101: alu_ctrl = func7[5] ? 4'b0111 : 4'b0110; // srai : srli
                3'b010: alu_ctrl = 4'b1000; // slti
                3'b011: alu_ctrl = 4'b1001; // sltiu
                default: alu_ctrl = 4'b0000;
            endcase
        end

        default: alu_ctrl = 4'b0000;
    endcase
end

endmodule
