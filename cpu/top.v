// =============================================================================
// top.v - RV32I CPU Top-Level for DE1-SoC
//
// Controls:
//   KEY[0]   : reset (active-low; hold to reset, release to run)
//   KEY[1]   : manual clock step (press once = advance one instruction)
//   SW[0]    : 0 = free run at 50 MHz, 1 = manual step mode
//   SW[9:8]  : display mode
//                00 = PC
//                01 = current instruction
//                10 = ALU result
//                11 = value of register selected by SW[7:3]
//   SW[7:3]  : register index (x0-x31) to inspect when SW[9:8]=11
//   SW[1]    : when SW[9:8]=11, selects half: 0=bits[15:0], 1=bits[31:16]
//
// Outputs:
//   HEX5-HEX0 : in reg mode HEX5:HEX4=index(dec) HEX3:HEX0=value(hex); else raw hex
//   LEDR[0]    : step mode indicator (mirrors SW[0])
//   LEDR[8:1]  : instruction index (pc_out[9:2])
//   LEDR[9]    : program done (halted)
// =============================================================================
module top (
    input         CLOCK_50,
    input  [3:0]  KEY,
    input  [9:0]  SW,
    output [9:0]  LEDR,
    output [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
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
wire [31:0] debug_reg_data;
wire [31:0] exit_code;

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

assign pc_src = (branch & alu_zero) | jal | jalr;

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
    .clk(CLOCK_50), .reg_write(reg_write), .en(cpu_en),
    .rs1(instr[19:15]), .rs2(instr[24:20]), .rd(instr[11:7]),
    .write_data(wb_data),
    .read_data1(reg_data1), .read_data2(reg_data2),
    .debug_addr(SW[7:3]), .debug_data(debug_reg_data),
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
    .clk(CLOCK_50), .mem_write(mem_write), .mem_read(mem_read), .en(cpu_en),
    .addr(alu_result), .write_data(reg_data2), .read_data(mem_data_out)
);

mux2to1 u_mux_wb  (.sel(mem_to_reg),  .a(alu_result),  .b(mem_data_out), .out(wb_data_pre));
mux2to1 u_mux_jal (.sel(jal | jalr),  .a(wb_data_pre), .b(pc_plus4),     .out(wb_data));

// --- Display logic ---
wire [4:0]  reg_idx  = SW[7:3];
wire [3:0]  tens     = (reg_idx >= 5'd30) ? 4'd3 :
                       (reg_idx >= 5'd20) ? 4'd2 :
                       (reg_idx >= 5'd10) ? 4'd1 : 4'd0;
wire [4:0]  tens_x10 = (tens == 4'd3) ? 5'd30 :
                       (tens == 4'd2) ? 5'd20 :
                       (tens == 4'd1) ? 5'd10 : 5'd0;
wire [3:0]  ones     = reg_idx - tens_x10;
wire [15:0] reg_half = SW[1] ? debug_reg_data[31:16] : debug_reg_data[15:0];

reg [23:0] display_value;
always @(*) begin
    case (SW[9:8])
        2'b00:   display_value = pc_out[23:0];
        2'b01:   display_value = instr[23:0];
        2'b10:   display_value = alu_result[23:0];
        2'b11:   display_value = {tens, ones, reg_half};
        default: display_value = 24'b0;
    endcase
end

hex_display h0 (.value(display_value[3:0]),   .segments(HEX0));
hex_display h1 (.value(display_value[7:4]),   .segments(HEX1));
hex_display h2 (.value(display_value[11:8]),  .segments(HEX2));
hex_display h3 (.value(display_value[15:12]), .segments(HEX3));
hex_display h4 (.value(display_value[19:16]), .segments(HEX4));
hex_display h5 (.value(display_value[23:20]), .segments(HEX5));

// --- LEDs ---
assign LEDR[0]   = SW[0];            // step mode indicator
assign LEDR[8:1] = halted ? exit_code[7:0] : pc_out[9:2];
assign LEDR[9]   = halted;            // program done indicator

endmodule
