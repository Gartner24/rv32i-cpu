// =============================================================================
// pipe_idex.v - Registro de pipeline ID/EX.
// Captura datos leidos, inmediato, PC y las senales de control de la etapa ID.
//   en     : avanza (cpu_en).
//   bubble : inserta burbuja (flush por salto, o stall por load-use) -> anula
//            valid y todas las senales de control con efecto.
// =============================================================================
module pipe_idex (
    input             clk,
    input             rst,
    input             en,
    input             bubble,
    input             in_valid,
    input      [31:0] in_pc,
    input      [31:0] in_pc4,
    input      [31:0] in_instr,
    input      [31:0] in_imm,
    input      [31:0] in_rdata1,
    input      [31:0] in_rdata2,
    input             in_reg_write,
    input             in_alu_src,
    input             in_alu_a_src,
    input             in_mem_write,
    input             in_mem_read,
    input             in_mem_to_reg,
    input             in_branch,
    input             in_jal,
    input             in_jalr,
    input      [1:0]  in_alu_op,
    output reg [31:0] pc,
    output reg [31:0] pc4,
    output reg [31:0] instr,
    output reg [31:0] imm,
    output reg [31:0] rdata1,
    output reg [31:0] rdata2,
    output reg        valid,
    output reg        reg_write,
    output reg        alu_src,
    output reg        alu_a_src,
    output reg        mem_write,
    output reg        mem_read,
    output reg        mem_to_reg,
    output reg        branch,
    output reg        jal,
    output reg        jalr,
    output reg [1:0]  alu_op
);
localparam [31:0] NOP = 32'h00000013;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid <= 1'b0; instr <= NOP;
        reg_write <= 1'b0; mem_write <= 1'b0; mem_read <= 1'b0;
        mem_to_reg <= 1'b0; branch <= 1'b0; jal <= 1'b0; jalr <= 1'b0;
    end else if (en) begin
        if (bubble) begin
            valid <= 1'b0; instr <= NOP;
            reg_write <= 1'b0; mem_write <= 1'b0; mem_read <= 1'b0;
            mem_to_reg <= 1'b0; branch <= 1'b0; jal <= 1'b0; jalr <= 1'b0;
        end else begin
            pc <= in_pc; pc4 <= in_pc4; instr <= in_instr; imm <= in_imm;
            rdata1 <= in_rdata1; rdata2 <= in_rdata2; valid <= in_valid;
            reg_write <= in_reg_write; alu_src <= in_alu_src;
            alu_a_src <= in_alu_a_src; mem_write <= in_mem_write;
            mem_read <= in_mem_read; mem_to_reg <= in_mem_to_reg;
            branch <= in_branch; jal <= in_jal; jalr <= in_jalr;
            alu_op <= in_alu_op;
        end
    end
end
endmodule
