// =============================================================================
// top.v - RV32I CPU Top-Level for DE1-SoC
//
// Controls:
//   KEY[0]   : reset (active-low)
//   KEY[1]   : manual clock step (one instruction per press)
//   SW[0]    : 0 = free run, 1 = manual step mode
//
// Outputs:
//   VGA      : 640x480 debug overlay (PC, INSTR, ALU, control flags, x0-x31)
//   HEX5-HEX0: lower 24 bits of PC (hex)
//   LEDR[0]  : step mode indicator
//   LEDR[8:1]: exit_code[7:0] when halted, else pc_out[9:2]
//   LEDR[9]  : halted
// =============================================================================
module top (
    input         CLOCK_50,
    input  [3:0]  KEY,
    input  [9:0]  SW,
    output [9:0]  LEDR,
    output [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
    // VGA
    output [7:0]  VGA_R, VGA_G, VGA_B,
    output        VGA_HS, VGA_VS, VGA_CLK,
    output        VGA_BLANK_N, VGA_SYNC_N
);

// --- Reset (active-low KEY[0] -> active-high rst) ---
wire rst = ~KEY[0]; 

// --- Step mode: 2-FF synchronizer + falling-edge detect on KEY[1] ---
reg key1_s0, key1_s1, key1_prev;
always @(posedge CLOCK_50 or posedge rst) begin
    if (rst) begin
        key1_s0   <= 1'b1;
        key1_s1   <= 1'b1;
        key1_prev <= 1'b1;
    end else begin
        key1_s0   <= KEY[1];
        key1_s1   <= key1_s0;
        key1_prev <= key1_s1;
    end
end
// Falling edge of KEY[1] (active-low button press) = one step
wire step_pulse = key1_prev & ~key1_s1;
wire en = SW[0] ? step_pulse : 1'b1;

// --- Halt detection ---
reg halted;
wire [31:0] instr;
wire cpu_en = en & ~halted;
always @(posedge CLOCK_50 or posedge rst) begin
    if (rst)                              halted <= 1'b0;
    else if (en && (instr == 32'h00000000 || instr == 32'h00100073)) halted <= 1'b1;
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

// funct3[0] (instr[12]) inverts the branch condition: 0=BEQ(branch==0), 1=BNE(branch!=0)
wire branch_taken = branch & (alu_zero ^ instr[12]);
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
    .reg_write(reg_write), .en(cpu_en), .rst(rst),
    .rs1(instr[19:15]), .rs2(instr[24:20]), .rd(instr[11:7]),
    .write_data(wb_data),
    .read_data1(reg_data1), .read_data2(reg_data2),
    .debug_addr(vga_dbg_addr), .debug_data(vga_dbg_data),
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
    .mem_write(mem_write), .mem_read(mem_read), .en(cpu_en),
    .addr(alu_result), .write_data(reg_data2), .read_data(mem_data_out)
);

mux2to1 u_mux_wb  (.sel(mem_to_reg),  .a(alu_result),  .b(mem_data_out), .out(wb_data_pre));
mux2to1 u_mux_jal (.sel(jal | jalr),  .a(wb_data_pre), .b(pc_plus4),     .out(wb_data));

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

// --- HEX: always show lower 24 bits of PC ---
hex_display h0 (.value(pc_out[3:0]),   .segments(HEX0));
hex_display h1 (.value(pc_out[7:4]),   .segments(HEX1));
hex_display h2 (.value(pc_out[11:8]),  .segments(HEX2));
hex_display h3 (.value(pc_out[15:12]), .segments(HEX3));
hex_display h4 (.value(pc_out[19:16]), .segments(HEX4));
hex_display h5 (.value(pc_out[23:20]), .segments(HEX5));

// --- LEDs ---
assign LEDR[0]   = SW[0];
assign LEDR[8:1] = halted ? exit_code[7:0] : pc_out[9:2];
assign LEDR[9]   = halted;

endmodule
