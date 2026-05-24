// =============================================================================
// pipe_ifid.v - Registro de pipeline IF/ID.
// Captura PC, PC+4 e instruccion de la etapa IF. Control:
//   enable : avanza (clock-enable global cpu_enable).
//   flush  : inserta burbuja (salto tomado) -> prioridad sobre stall.
//   stall  : congela (mantiene la misma instruccion) por load-use.
// =============================================================================
module pipe_ifid (
    input             clk,
    input             rst,
    input             enable,
    input             flush,
    input             stall,
    input      [31:0] in_pc,
    input      [31:0] in_pc_plus_4,
    input      [31:0] in_instruction,
    output reg [31:0] pc,
    output reg [31:0] pc_plus_4,
    output reg [31:0] instruction,
    output reg        valid
);
localparam [31:0] NOP_INSTRUCTION = 32'h00000013;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc <= 32'b0; pc_plus_4 <= 32'b0; instruction <= NOP_INSTRUCTION; valid <= 1'b0;
    end else if (enable) begin
        if (flush) begin
            instruction <= NOP_INSTRUCTION; valid <= 1'b0;
        end else if (stall) begin
            // mantener (la instruccion espera en ID)
        end else begin
            pc <= in_pc; pc_plus_4 <= in_pc_plus_4;
            instruction <= in_instruction; valid <= 1'b1;
        end
    end
end
endmodule
