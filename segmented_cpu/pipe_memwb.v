// =============================================================================
// pipe_memwb.v - Registro de pipeline MEM/WB.
// Captura el resultado de la ALU, el dato leido de memoria, PC+4, la
// instruccion y las senales de control de write-back. Avanza siempre (cpu_en);
// no recibe flush (la instruccion en MEM ya esta confirmada).
// =============================================================================
module pipe_memwb (
    input             clk,
    input             rst,
    input             en,
    input             in_valid,
    input      [31:0] in_alu_result,
    input      [31:0] in_mem_data,
    input      [31:0] in_pc4,
    input      [31:0] in_instr,
    input             in_reg_write,
    input             in_mem_to_reg,
    input             in_jal,
    input             in_jalr,
    output reg [31:0] alu_result,
    output reg [31:0] mem_data,
    output reg [31:0] pc4,
    output reg [31:0] instr,
    output reg        valid,
    output reg        reg_write,
    output reg        mem_to_reg,
    output reg        jal,
    output reg        jalr
);
localparam [31:0] NOP = 32'h00000013;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid <= 1'b0; instr <= NOP; reg_write <= 1'b0;
    end else if (en) begin
        alu_result <= in_alu_result; mem_data <= in_mem_data;
        pc4 <= in_pc4; instr <= in_instr; valid <= in_valid;
        reg_write <= in_reg_write; mem_to_reg <= in_mem_to_reg;
        jal <= in_jal; jalr <= in_jalr;
    end
end
endmodule
