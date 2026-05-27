// =============================================================================
// pipe_ifid.v - Registro de pipeline IF/ID (PC, PC+4 y valid).
// La INSTRUCCION ya no se latchea aqui: la memoria de instrucciones tiene
// lectura sincronica (M10K) y su registro de salida hace de registro IF/ID de la
// instruccion. top.v arma if_id_instruction = valid ? instr_rom : NOP.
// Control:
//   enable : avanza (clock-enable global cpu_enable).
//   flush  : inserta burbuja (salto tomado) -> valid=0; prioridad sobre stall.
//   stall  : congela (mantiene PC) por load-use.
// =============================================================================
module pipe_ifid (
    input             clk,
    input             rst,
    input             enable,
    input             flush,
    input             stall,
    input      [31:0] in_pc,
    input      [31:0] in_pc_plus_4,
    output reg [31:0] pc,
    output reg [31:0] pc_plus_4,
    output reg        valid
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc <= 32'b0; pc_plus_4 <= 32'b0; valid <= 1'b0;
    end else if (enable) begin
        if (flush) begin
            valid <= 1'b0;
        end else if (stall) begin
            // mantener (la instruccion espera en ID)
        end else begin
            pc <= in_pc; pc_plus_4 <= in_pc_plus_4; valid <= 1'b1;
        end
    end
end
endmodule
