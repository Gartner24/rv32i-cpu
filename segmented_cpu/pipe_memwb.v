// =============================================================================
// pipe_memwb.v - Registro de pipeline MEM/WB.
// Captura el resultado de la ALU, el dato leido de memoria, PC+4, la
// instruccion y las senales de control de write-back. Avanza siempre
// (cpu_enable); no recibe flush (la instruccion en MEM ya esta confirmada).
// =============================================================================
module pipe_memwb (
    input             clk,
    input             rst,
    input             enable,
    input             in_valid,
    input      [31:0] in_alu_result,
    input      [31:0] in_mem_read_data,
    input      [31:0] in_pc_plus_4,
    input      [31:0] in_instruction,
    input             in_ctrl_reg_write,
    input             in_ctrl_mem_to_reg,
    input             in_ctrl_jal,
    input             in_ctrl_jalr,
    output reg [31:0] alu_result,
    output reg [31:0] mem_read_data,
    output reg [31:0] pc_plus_4,
    output reg [31:0] instruction,
    output reg        valid,
    output reg        ctrl_reg_write,
    output reg        ctrl_mem_to_reg,
    output reg        ctrl_jal,
    output reg        ctrl_jalr
);
localparam [31:0] NOP_INSTRUCTION = 32'h00000013;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid <= 1'b0; instruction <= NOP_INSTRUCTION; ctrl_reg_write <= 1'b0;
    end else if (enable) begin
        alu_result <= in_alu_result; mem_read_data <= in_mem_read_data;
        pc_plus_4 <= in_pc_plus_4; instruction <= in_instruction; valid <= in_valid;
        ctrl_reg_write <= in_ctrl_reg_write; ctrl_mem_to_reg <= in_ctrl_mem_to_reg;
        ctrl_jal <= in_ctrl_jal; ctrl_jalr <= in_ctrl_jalr;
    end
end
endmodule
