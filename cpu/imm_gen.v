// =============================================================================
// imm_gen.v - Generador de Inmediatos
// Extrae y extiende con signo el inmediato de la instrucción.
// RV32I tiene 5 formatos de inmediato con bits dispersos en la instrucción.
// Este módulo los reensambla según el tipo de instrucción (identificado por
// el opcode). El bit de signo siempre es instr[31] en todos los formatos -
// decisión deliberada de RISC-V para simplificar el hardware.
// =============================================================================
module imm_gen (
    input      [31:0] instr,
    output reg [31:0] imm_out
);

wire [6:0] opcode = instr[6:0];

localparam I_TYPE   = 7'b0010011;
localparam LOAD     = 7'b0000011;
localparam JALR     = 7'b1100111;
localparam S_TYPE   = 7'b0100011;
localparam B_TYPE   = 7'b1100011;
localparam LUI      = 7'b0110111;
localparam AUIPC    = 7'b0010111;
localparam JAL      = 7'b1101111;

always @(*) begin
    case (opcode)
        // I-type aritmético (addi, andi, ori...) - I-type carga (lw, lb...) - Jalr
        I_TYPE, LOAD, JALR: imm_out = {{20{instr[31]}}, instr[31:20]};

        // S-type (sw, sb...)
        S_TYPE:
            imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};

        // B-type (beq, bne...)
        B_TYPE:
            imm_out = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

        // U-type AUIPC, LUI
        LUI, AUIPC:
            imm_out = {instr[31:12], 12'b0};

        // J-type JAL
        JAL:
            imm_out = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

        default: imm_out = 32'b0;
    endcase
end

endmodule
