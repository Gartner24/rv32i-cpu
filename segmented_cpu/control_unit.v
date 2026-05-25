// =============================================================================
// control_unit.v - Decodifica el opcode[6:0] y activa las senales de control
// que gobiernan el datapath: que registros leer, si acceder a memoria,
// que operacion hace la ALU, y como calcular el siguiente PC.
//
// Mapa de opcodes RV32I:
//   0110011 = R-type  (add, sub, and, or ...)
//   0010011 = I-type  (addi, andi, ori ...)
//   0000011 = Load    (lw)
//   0100011 = S-type  (sw)
//   1100011 = B-type  (beq, bne, blt, bge ...)
//   0110111 = LUI
//   0010111 = AUIPC
//   1101111 = JAL
//   1100111 = JALR
// =============================================================================
module control_unit (
    input  [6:0] opcode,
    output reg reg_write,   // habilita escritura en register file
    output reg alu_src,     // 0 = rs2, 1 = inmediato
    output reg alu_a_src,   // 0 = rs1, 1 = PC (para AUIPC)
    output reg alu_a_zero,  // 1 = fuerza operando A = 0 (para LUI: rd = imm<<12)
    output reg mem_write,   // habilita escritura en data memory
    output reg mem_read,    // habilita lectura de data memory
    output reg mem_to_reg,  // 0 = ALU result, 1 = dato de memoria
    output reg branch,      // instruccion de salto condicional
    output reg jal,         // salto incondicional (JAL)
    output reg jalr,  // salto incondicional a rs1+imm (JALR)
    output reg [1:0] alu_op   // pista para alu_control
);

localparam R_TYPE = 7'b0110011;
localparam I_TYPE = 7'b0010011;
localparam LOAD = 7'b0000011;
localparam S_TYPE = 7'b0100011;
localparam B_TYPE = 7'b1100011;
localparam LUI = 7'b0110111;
localparam AUIPC = 7'b0010111;
localparam JAL = 7'b1101111;
localparam JALR = 7'b1100111;

always @(*) begin
    // Por defecto el operando A NO se fuerza a 0; solo LUI lo activa abajo.
    alu_a_zero = 1'b0;
    case (opcode)
        R_TYPE: begin  // R-type
            reg_write  = 1;
            alu_src    = 0;
            alu_a_src  = 0;
            mem_write  = 0;
            mem_read   = 0;
            mem_to_reg = 0;
            branch     = 0;
            jal        = 0;
            jalr       = 0;
            alu_op     = 2'b10;
        end
        I_TYPE: begin  // I-type aritmético
            reg_write  = 1;
            alu_src    = 1;
            alu_a_src  = 0;
            mem_write  = 0;
            mem_read   = 0;
            mem_to_reg = 0;
            branch     = 0;
            jal        = 0;
            jalr       = 0;
            alu_op     = 2'b11;
        end
        LOAD: begin  // Load
            reg_write  = 1;
            alu_src    = 1;
            alu_a_src  = 0;
            mem_write  = 0;
            mem_read   = 1;
            mem_to_reg = 1;
            branch     = 0;
            jal        = 0;
            jalr       = 0;
            alu_op     = 2'b00;
        end
        S_TYPE: begin  // S-type
            reg_write  = 0;
            alu_src    = 1;
            alu_a_src  = 0;
            mem_write  = 1;
            mem_read   = 0;
            mem_to_reg = 0;
            branch     = 0;
            jal        = 0;
            jalr       = 0;
            alu_op     = 2'b00;
        end
        B_TYPE: begin  // B-type
            reg_write  = 0;
            alu_src    = 0;
            alu_a_src  = 0;
            mem_write  = 0;
            mem_read   = 0;
            mem_to_reg = 0;
            branch     = 1;
            jal        = 0;
            jalr       = 0;
            alu_op     = 2'b01;
        end
        LUI: begin  // LUI: rd = imm<<12. Operando A forzado a 0 (el campo rs1
                    // de LUI son bits del inmediato, NO un registro valido).
            reg_write  = 1;
            alu_src    = 1;
            alu_a_src  = 0;
            alu_a_zero = 1;  // operando A = 0  ->  ALU hace 0 + imm = imm<<12
            mem_write  = 0;
            mem_read   = 0;
            mem_to_reg = 0;
            branch     = 0;
            jal        = 0;
            jalr       = 0;
            alu_op     = 2'b00;
        end
        AUIPC: begin  // AUIPC
            reg_write  = 1;
            alu_src    = 1;
            alu_a_src  = 1;  // usa PC como operando A en vez de rs1
            mem_write  = 0;
            mem_read   = 0;
            mem_to_reg = 0;
            branch     = 0;
            jal        = 0;
            jalr       = 0;
            alu_op     = 2'b00;
        end
        JAL: begin  // JAL
            reg_write  = 1;  // guarda PC+4 en rd
            alu_src    = 1;
            alu_a_src  = 0;
            mem_write  = 0;
            mem_read   = 0;
            mem_to_reg = 0;
            branch     = 0;
            jal        = 1;  // salto incondicional
            jalr       = 0;
            alu_op     = 2'b00;
        end
        JALR: begin
            reg_write  = 1;
            alu_src    = 1;
            alu_a_src  = 0;
            mem_write  = 0;
            mem_read   = 0;
            mem_to_reg = 0;
            branch     = 0;
            jal        = 0;
            jalr       = 1;   // señal dedicada para JALR
            alu_op     = 2'b00;
        end
        default: begin
            reg_write  = 0;
            alu_src    = 0;
            alu_a_src  = 0;
            mem_write  = 0;
            mem_read   = 0;
            mem_to_reg = 0;
            branch     = 0;
            jal        = 0;
            jalr       = 0;
            alu_op     = 2'b00;
        end
    endcase
end

endmodule
