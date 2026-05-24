// =============================================================================
// pipe_exmem.v - Registro de pipeline EX/MEM.
// Captura el resultado de la ALU, el dato a almacenar, la decision/objetivo de
// salto (resueltos en EX, actuados en MEM) y las senales de control de MEM/WB.
//   enable : avanza (cpu_enable).
//   flush  : inserta burbuja (la instruccion joven en EX se descarta cuando un
//            salto mas viejo se toma en MEM). pc_src se anula.
// =============================================================================
module pipe_exmem (
    input             clk,
    input             rst,
    input             enable,
    input             flush,
    input             in_valid,
    input      [31:0] in_alu_result,
    input      [31:0] in_store_data,
    input      [31:0] in_pc_plus_4,
    input      [31:0] in_instruction,
    input      [31:0] in_branch_target,
    input             in_pc_src,
    input             in_ctrl_reg_write,
    input             in_ctrl_mem_write,
    input             in_ctrl_mem_read,
    input             in_ctrl_mem_to_reg,
    input             in_ctrl_jal,
    input             in_ctrl_jalr,
    output reg [31:0] alu_result,
    output reg [31:0] store_data,
    output reg [31:0] pc_plus_4,
    output reg [31:0] instruction,
    output reg [31:0] branch_target,
    output reg        pc_src,
    output reg        valid,
    output reg        ctrl_reg_write,
    output reg        ctrl_mem_write,
    output reg        ctrl_mem_read,
    output reg        ctrl_mem_to_reg,
    output reg        ctrl_jal,
    output reg        ctrl_jalr
);
localparam [31:0] NOP_INSTRUCTION = 32'h00000013;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid <= 1'b0; instruction <= NOP_INSTRUCTION; pc_src <= 1'b0;
        ctrl_reg_write <= 1'b0; ctrl_mem_write <= 1'b0; ctrl_mem_read <= 1'b0;
        ctrl_mem_to_reg <= 1'b0; ctrl_jal <= 1'b0; ctrl_jalr <= 1'b0;
    end else if (enable) begin
        if (flush) begin
            valid <= 1'b0; instruction <= NOP_INSTRUCTION; pc_src <= 1'b0;
            ctrl_reg_write <= 1'b0; ctrl_mem_write <= 1'b0; ctrl_mem_read <= 1'b0;
            ctrl_mem_to_reg <= 1'b0; ctrl_jal <= 1'b0; ctrl_jalr <= 1'b0;
        end else begin
            alu_result <= in_alu_result; store_data <= in_store_data;
            pc_plus_4 <= in_pc_plus_4; instruction <= in_instruction;
            branch_target <= in_branch_target; pc_src <= in_pc_src;
            valid <= in_valid; ctrl_reg_write <= in_ctrl_reg_write;
            ctrl_mem_write <= in_ctrl_mem_write; ctrl_mem_read <= in_ctrl_mem_read;
            ctrl_mem_to_reg <= in_ctrl_mem_to_reg; ctrl_jal <= in_ctrl_jal;
            ctrl_jalr <= in_ctrl_jalr;
        end
    end
end
endmodule
