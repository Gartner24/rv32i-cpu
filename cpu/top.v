// =============================================================================
// top.v - RV32I CPU Top-Level for DE1-SoC
//
// Controls:
//   KEY[0]   : reset (active-low)
//   KEY[1]   : manual step (one instruction per debounced press)
//   SW[0]    : 0 = free run, 1 = manual step mode
//
// All CPU flip-flops run from CLOCK_50. Step/auto/halt are clock-enables,
// not clock muxes, so Cyclone V uses only one clock domain (no glitches).
//
// Outputs:
//   VGA      : 640x480 debug overlay (PC, INSTR, ALU, control flags, x0-x31)
//   LEDR[0]  : step mode indicator (mirrors SW[0])
//   LEDR[9]  : halted
// =============================================================================
module top #(
    // Debounce filter: KEY[1] must be stable this many CLOCK_50 cycles.
    // Default ~1 ms at 50 MHz. Override in testbenches (defparam dut.DEBOUNCE_LIMIT=4).
    parameter DEBOUNCE_LIMIT = 50000
) (
    input         CLOCK_50,
    input  [3:0]  KEY,
    input  [9:0]  SW,
    output [9:0]  LEDR,
    // VGA
    output [7:0]  VGA_R, VGA_G, VGA_B,
    output        VGA_HS, VGA_VS, VGA_CLK,
    output        VGA_BLANK_N, VGA_SYNC_N
);

// --- Reset (active-low KEY[0] -> active-high rst) ---
wire rst = ~KEY[0];

// --- KEY[1] debounce + falling-edge detect ---
// Requires KEY[1] stable for DEBOUNCE_LIMIT CLOCK_50 cycles before updating.
// Produces one 1-cycle step_pulse per physical press regardless of bounce.
reg        key1_sync0, key1_sync1;
reg [15:0] key1_count;
reg        key1_stable;
always @(posedge CLOCK_50 or posedge rst) begin
    if (rst) begin
        key1_sync0  <= 1'b1;
        key1_sync1  <= 1'b1;
        key1_count  <= 16'b0;
        key1_stable <= 1'b1;
    end else begin
        key1_sync0 <= KEY[1];
        key1_sync1 <= key1_sync0;
        if (key1_sync1 == key1_stable) begin
            key1_count <= 16'b0;
        end else if (key1_count == DEBOUNCE_LIMIT - 1) begin
            key1_stable <= key1_sync1;
            key1_count  <= 16'b0;
        end else begin
            key1_count <= key1_count + 1'b1;
        end
    end
end
reg key1_stable_prev;
always @(posedge CLOCK_50 or posedge rst) begin
    if (rst) key1_stable_prev <= 1'b1;
    else     key1_stable_prev <= key1_stable;
end
wire step_pulse = key1_stable_prev & ~key1_stable;

// --- Clock enable: all CPU FFs run on CLOCK_50, gated by cpu_en ---
// Step mode: one enable per debounced KEY[1] press.
// Auto mode: run continuously until halted.
reg halted;
wire cpu_en = SW[0] ? (step_pulse && ~halted) : ~halted;

// --- Halt detection ---
wire [31:0] instr;
always @(posedge CLOCK_50 or posedge rst) begin
    if (rst)        halted <= 1'b0;
    else if (cpu_en && (instr == 32'h00000000 || instr == 32'h00100073))
                    halted <= 1'b1;
end

// --- Datapath wires ---
wire [31:0] pc_out;
wire [31:0] pc_next;
wire [31:0] pc_plus4;
wire [31:0] pc_branch;
wire [31:0] pc_jump;
wire [31:0] imm_ext;
wire [31:0] reg_data1;
wire [31:0] reg_data2;
wire [31:0] alu_operand_a;
wire [31:0] alu_operand_b;
wire [31:0] alu_result;
wire [31:0] mem_data_out;
wire [31:0] wb_data_pre;
wire [31:0] wb_data;
wire [31:0] exit_code;
// VGA debug port
wire [4:0]  vga_dbg_addr;
wire [31:0] vga_dbg_data;

// --- Control signals ---
wire        reg_write;
wire        alu_src;
wire        alu_a_src;
wire        mem_write;
wire        mem_read;
wire        mem_to_reg;
wire        branch;
wire        jal;
wire        jalr;
wire        alu_zero;
wire        pc_src;
wire [1:0]  alu_op;
wire [3:0]  alu_ctrl;

// --- Register and memory storage (flip-flops here so sub-modules stay clock-free) ---
reg [31:0]  regs [0:31];
reg [31:0]  dmem [0:255];
wire [32*32-1:0]   regs_flat;
wire [256*32-1:0]  dmem_flat;
integer     ri;

// Branch condition depends on funct3
reg branch_cond;
always @(*) begin
    case (instr[14:12])
        3'b000: branch_cond =  alu_zero;        // BEQ
        3'b001: branch_cond = ~alu_zero;        // BNE
        3'b100: branch_cond =  alu_result[0];   // BLT  (SLT result)
        3'b101: branch_cond = ~alu_result[0];   // BGE
        3'b110: branch_cond =  alu_result[0];   // BLTU (SLTU result)
        3'b111: branch_cond = ~alu_result[0];   // BGEU
        default: branch_cond = 1'b0;
    endcase
end
wire branch_taken = branch & branch_cond;
assign pc_src = branch_taken | jal | jalr;

// --- CPU instances ---

pc u_pc (
    .clk(CLOCK_50), .rst(rst), .en(cpu_en),
    .pc_next(pc_next), .pc_out(pc_out)
);

adder u_pc_plus4  (.a(pc_out),  .b(32'd4),    .out(pc_plus4));
adder u_pc_branch (.a(pc_out),  .b(imm_ext),  .out(pc_branch));

mux2to1 u_mux_jump (.sel(jalr),   .a(pc_branch), .b(alu_result), .out(pc_jump));
mux2to1 u_mux_pc   (.sel(pc_src), .a(pc_plus4),  .b(pc_jump),    .out(pc_next));

instruction_memory u_imem (.addr(pc_out), .instr(instr));

control_unit u_ctrl (
    .opcode(instr[6:0]),
    .reg_write(reg_write), .alu_src(alu_src), .alu_a_src(alu_a_src),
    .mem_write(mem_write), .mem_read(mem_read), .mem_to_reg(mem_to_reg),
    .branch(branch), .jal(jal), .jalr(jalr), .alu_op(alu_op)
);

register_file u_regfile (
    .regs_flat(regs_flat),
    .rs1(instr[19:15]), .rs2(instr[24:20]),
    .debug_addr(vga_dbg_addr),
    .read_data1(reg_data1), .read_data2(reg_data2),
    .debug_data(vga_dbg_data),
    .exit_code(exit_code)
);

imm_gen u_immgen (.instr(instr), .imm_out(imm_ext));

mux2to1 u_mux_alu_a (.sel(alu_a_src), .a(reg_data1), .b(pc_out),   .out(alu_operand_a));
mux2to1 u_mux_alu_b (.sel(alu_src),   .a(reg_data2), .b(imm_ext),  .out(alu_operand_b));

alu_control u_alu_ctrl (
    .alu_op(alu_op), .func3(instr[14:12]), .func7(instr[31:25]), .alu_ctrl(alu_ctrl)
);

alu u_alu (
    .a(alu_operand_a), .b(alu_operand_b),
    .alu_ctrl(alu_ctrl), .result(alu_result), .zero(alu_zero)
);

data_memory u_dmem (
    .mem_flat(dmem_flat),
    .mem_read(mem_read),
    .addr(alu_result),
    .read_data(mem_data_out)
);

mux2to1 u_mux_wb  (.sel(mem_to_reg),  .a(alu_result),  .b(mem_data_out), .out(wb_data_pre));
mux2to1 u_mux_jal (.sel(jal | jalr),  .a(wb_data_pre), .b(pc_plus4),     .out(wb_data));

// --- Clocked writes for register file and data memory ---
always @(posedge CLOCK_50 or posedge rst) begin
    if (rst) begin
        for (ri = 0; ri < 32; ri = ri + 1) regs[ri] <= 32'b0;
    end else if (cpu_en && reg_write && instr[11:7] != 5'b0) begin
        regs[instr[11:7]] <= wb_data;
    end
end

genvar gri;
generate
    for (gri = 0; gri < 32; gri = gri + 1) begin : pack_regs
        assign regs_flat[32*gri +: 32] = regs[gri];
    end
endgenerate

always @(posedge CLOCK_50) begin
    if (cpu_en && mem_write)
        dmem[alu_result[31:2]] <= reg_data2;
end

genvar gmi;
generate
    for (gmi = 0; gmi < 256; gmi = gmi + 1) begin : pack_dmem
        assign dmem_flat[32*gmi +: 32] = dmem[gmi];
    end
endgenerate

// --- VGA ---
wire [9:0] vga_x, vga_y;
wire       vga_video_on;

vga_controller u_vgac (
    .clk_50MHz(CLOCK_50), .reset(rst),
    .video_on(vga_video_on), .hsync(VGA_HS), .vsync(VGA_VS),
    .clk(VGA_CLK), .x(vga_x), .y(vga_y)
);

vga_debug u_vgad (
    .video_on(vga_video_on), .x(vga_x), .y(vga_y),
    .pc_out(pc_out), .instr(instr), .alu_result(alu_result),
    .imm_ext(imm_ext), .mem_data_out(mem_data_out),
    .alu_zero(alu_zero), .halted(halted),
    .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
    .mem_to_reg(mem_to_reg), .alu_src(alu_src),
    .branch(branch), .jal(jal), .jalr(jalr), .pc_src(pc_src),
    .reg_debug_addr(vga_dbg_addr), .reg_debug_data(vga_dbg_data),
    .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B)
);

assign VGA_BLANK_N = vga_video_on;
assign VGA_SYNC_N  = 1'b0;

// --- LEDs ---
assign LEDR[0]   = SW[0];
assign LEDR[8:1] = 8'b0;
assign LEDR[9]   = halted;

endmodule
