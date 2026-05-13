// =============================================================================
// register_file.v - Banco de Registros (combinacional puro)
// Decodifica lecturas del arreglo regs_flat que viene de top.v.
// Los flip-flops de escritura viven en top.v para que este modulo
// sea puramente combinacional (sin clk), cumpliendo la regla monociclo.
// =============================================================================
module register_file (
    input  [32*32-1:0] regs_flat,  // 32 registros x 32 bits, empaquetados
    input  [4:0]  rs1,
    input  [4:0]  rs2,
    input  [4:0]  debug_addr,
    output [31:0] read_data1,
    output [31:0] read_data2,
    output [31:0] debug_data,
    output [31:0] exit_code
);

wire [31:0] regs [0:31];
genvar gi;
generate
    for (gi = 0; gi < 32; gi = gi + 1) begin : unpack
        assign regs[gi] = regs_flat[32*gi +: 32];
    end
endgenerate

assign read_data1 = (rs1 == 5'b0) ? 32'b0 : regs[rs1];
assign read_data2 = (rs2 == 5'b0) ? 32'b0 : regs[rs2];
assign debug_data = (debug_addr == 5'b0) ? 32'b0 : regs[debug_addr];
assign exit_code  = regs[10];

endmodule
