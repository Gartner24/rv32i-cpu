// =============================================================================
// pipe_idex.v - Registro de pipeline ID/EX.
// Captura datos leidos, inmediato, PC y las senales de control de la etapa ID.
//   enable : avanza (cpu_enable).
//   bubble : inserta burbuja (flush por salto, o stall por load-use) -> anula
//            valid y todas las senales de control con efecto.
// =============================================================================
module pipe_idex (
    input             clk,
    input             rst,
    input             enable,
    input             bubble,
    input             in_valid,
    input      [31:0] in_pc,
    input      [31:0] in_pc_plus_4,
    input      [31:0] in_instruction,
    input      [31:0] in_imm,
    input      [31:0] in_rs1_data,
    input      [31:0] in_rs2_data,
    input             in_ctrl_reg_write,
    input             in_ctrl_alu_src,
    input             in_ctrl_alu_a_src,
    input             in_ctrl_mem_write,
    input             in_ctrl_mem_read,
    input             in_ctrl_mem_to_reg,
    input             in_ctrl_branch,
    input             in_ctrl_jal,
    input             in_ctrl_jalr,
    input      [1:0]  in_ctrl_alu_op,
    output reg [31:0] pc,
    output reg [31:0] pc_plus_4,
    output reg [31:0] instruction,
    output reg [31:0] imm,
    output reg [31:0] rs1_data,
    output reg [31:0] rs2_data,
    output reg        valid,
    output reg        ctrl_reg_write,
    output reg        ctrl_alu_src,
    output reg        ctrl_alu_a_src,
    output reg        ctrl_mem_write,
    output reg        ctrl_mem_read,
    output reg        ctrl_mem_to_reg,
    output reg        ctrl_branch,
    output reg        ctrl_jal,
    output reg        ctrl_jalr,
    output reg [1:0]  ctrl_alu_op
);
localparam [31:0] NOP_INSTRUCTION = 32'h00000013;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid <= 1'b0; instruction <= NOP_INSTRUCTION;
        ctrl_reg_write <= 1'b0; ctrl_mem_write <= 1'b0; ctrl_mem_read <= 1'b0;
        ctrl_mem_to_reg <= 1'b0; ctrl_branch <= 1'b0; ctrl_jal <= 1'b0; ctrl_jalr <= 1'b0;
    end else if (enable) begin
        if (bubble) begin
            valid <= 1'b0; instruction <= NOP_INSTRUCTION;
            ctrl_reg_write <= 1'b0; ctrl_mem_write <= 1'b0; ctrl_mem_read <= 1'b0;
            ctrl_mem_to_reg <= 1'b0; ctrl_branch <= 1'b0; ctrl_jal <= 1'b0; ctrl_jalr <= 1'b0;
        end else begin
            pc <= in_pc; pc_plus_4 <= in_pc_plus_4; instruction <= in_instruction;
            imm <= in_imm; rs1_data <= in_rs1_data; rs2_data <= in_rs2_data;
            valid <= in_valid;
            ctrl_reg_write <= in_ctrl_reg_write; ctrl_alu_src <= in_ctrl_alu_src;
            ctrl_alu_a_src <= in_ctrl_alu_a_src; ctrl_mem_write <= in_ctrl_mem_write;
            ctrl_mem_read <= in_ctrl_mem_read; ctrl_mem_to_reg <= in_ctrl_mem_to_reg;
            ctrl_branch <= in_ctrl_branch; ctrl_jal <= in_ctrl_jal; ctrl_jalr <= in_ctrl_jalr;
            ctrl_alu_op <= in_ctrl_alu_op;
        end
    end
end
endmodule
