// =============================================================================
// pipe_ifid.v - Registro de pipeline IF/ID.
// Captura PC, PC+4 e instruccion de la etapa IF. Control:
//   en    : avanza (clock-enable global cpu_en).
//   flush : inserta burbuja (salto tomado) -> prioridad sobre stall.
//   stall : congela (mantiene la misma instruccion) por load-use.
// =============================================================================
module pipe_ifid (
    input             clk,
    input             rst,
    input             en,
    input             flush,
    input             stall,
    input      [31:0] in_pc,
    input      [31:0] in_pc4,
    input      [31:0] in_instr,
    output reg [31:0] pc,
    output reg [31:0] pc4,
    output reg [31:0] instr,
    output reg        valid
);
localparam [31:0] NOP = 32'h00000013;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc <= 32'b0; pc4 <= 32'b0; instr <= NOP; valid <= 1'b0;
    end else if (en) begin
        if (flush) begin
            instr <= NOP; valid <= 1'b0;
        end else if (stall) begin
            // mantener (la instruccion espera en ID)
        end else begin
            pc <= in_pc; pc4 <= in_pc4; instr <= in_instr; valid <= 1'b1;
        end
    end
end
endmodule
