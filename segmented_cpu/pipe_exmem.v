// =============================================================================
// pipe_exmem.v - Registro de pipeline EX/MEM.
// Captura el resultado de la ALU, el dato a almacenar, la decision/objetivo de
// salto (resueltos en EX, actuados en MEM) y las senales de control de MEM/WB.
//   en    : avanza (cpu_en).
//   flush : inserta burbuja (la instruccion joven en EX se descarta cuando un
//           salto mas viejo se toma en MEM). pc_src se anula.
// =============================================================================
module pipe_exmem (
    input             clk,
    input             rst,
    input             en,
    input             flush,
    input             in_valid,
    input      [31:0] in_alu_result,
    input      [31:0] in_store_data,
    input      [31:0] in_pc4,
    input      [31:0] in_instr,
    input      [31:0] in_branch_target,
    input             in_pc_src,
    input             in_reg_write,
    input             in_mem_write,
    input             in_mem_read,
    input             in_mem_to_reg,
    input             in_jal,
    input             in_jalr,
    output reg [31:0] alu_result,
    output reg [31:0] store_data,
    output reg [31:0] pc4,
    output reg [31:0] instr,
    output reg [31:0] branch_target,
    output reg        pc_src,
    output reg        valid,
    output reg        reg_write,
    output reg        mem_write,
    output reg        mem_read,
    output reg        mem_to_reg,
    output reg        jal,
    output reg        jalr
);
localparam [31:0] NOP = 32'h00000013;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid <= 1'b0; instr <= NOP; pc_src <= 1'b0;
        reg_write <= 1'b0; mem_write <= 1'b0; mem_read <= 1'b0;
        mem_to_reg <= 1'b0; jal <= 1'b0; jalr <= 1'b0;
    end else if (en) begin
        if (flush) begin
            valid <= 1'b0; instr <= NOP; pc_src <= 1'b0;
            reg_write <= 1'b0; mem_write <= 1'b0; mem_read <= 1'b0;
            mem_to_reg <= 1'b0; jal <= 1'b0; jalr <= 1'b0;
        end else begin
            alu_result <= in_alu_result; store_data <= in_store_data;
            pc4 <= in_pc4; instr <= in_instr;
            branch_target <= in_branch_target; pc_src <= in_pc_src;
            valid <= in_valid; reg_write <= in_reg_write;
            mem_write <= in_mem_write; mem_read <= in_mem_read;
            mem_to_reg <= in_mem_to_reg; jal <= in_jal; jalr <= in_jalr;
        end
    end
end
endmodule
