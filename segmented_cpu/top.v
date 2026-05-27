// =============================================================================
// top.v - CPU RV32I SEGMENTADA (pipeline de 5 etapas) para la DE1-SoC.
// Etapas: IF (fetch) -> ID (decode) -> EX (execute) -> MEM -> WB.
//
// Estructura (como el diagrama de Patterson & Hennessy):
//   - Bloques autocontenidos: register_file y data_memory tienen su propio
//     puerto de escritura sincronico.
//   - Los 4 registros de pipeline son modulos discretos: pipe_ifid, pipe_idex,
//     pipe_exmem, pipe_memwb.
//   - Unidad de forwarding (forwarding_unit) y de riesgos (hazard_unit).
//   - El salto se resuelve en la etapa MEM (PCSrc desde EX/MEM): un salto
//     tomado descarta 3 instrucciones jovenes (flush).
//
// Convencion de nombres: los prefijos de etapa van completos (if_id_, id_ex_,
// ex_mem_, mem_wb_) y las senales de control llevan el prefijo ctrl_. Se
// conservan los terminos estandar de RISC-V (rs1, rs2, rd, pc, imm, alu_result).
//
// Controles fisicos:
//   KEY[0] : reset (activo en bajo)
//   KEY[1] : paso manual (un tick de reloj por pulsacion, con anti-rebote)
//   SW[0]  : 0 = ejecucion libre, 1 = modo paso a paso
// =============================================================================
module top #(
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

localparam [31:0] NOP_INSTRUCTION    = 32'h00000013; // addi x0,x0,0
localparam [31:0] EBREAK_INSTRUCTION = 32'h00100073;

// --- Reset ---
wire rst = ~KEY[0];

// --- Anti-rebote KEY[1]: genera step_pulse (1 ciclo) por cada pulsacion ---
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

// --- Halt: se activa cuando un ebreak/instr-nula valido llega a WB ---
reg halted;
// clock-enable global: modo paso = un tick por pulsacion, libre = corre hasta halt
wire cpu_enable = SW[0] ? (step_pulse && ~halted) : ~halted;

// =====================================================================
//  Salidas de los registros de pipeline (manejadas por los modulos pipe_*)
// =====================================================================
// IF/ID
wire [31:0] if_id_pc, if_id_pc_plus_4, if_id_instruction;
wire        if_id_valid;
// ID/EX
wire [31:0] id_ex_pc, id_ex_pc_plus_4, id_ex_instruction, id_ex_imm,
            id_ex_rs1_data, id_ex_rs2_data;
wire        id_ex_valid;
wire        id_ex_ctrl_reg_write, id_ex_ctrl_alu_src, id_ex_ctrl_alu_a_src,
            id_ex_ctrl_alu_a_zero,
            id_ex_ctrl_mem_write, id_ex_ctrl_mem_read, id_ex_ctrl_mem_to_reg,
            id_ex_ctrl_branch, id_ex_ctrl_jal, id_ex_ctrl_jalr;
wire [1:0]  id_ex_ctrl_alu_op;
// EX/MEM
wire [31:0] ex_mem_alu_result, ex_mem_store_data, ex_mem_pc_plus_4,
            ex_mem_instruction, ex_mem_branch_target;
wire        ex_mem_valid, ex_mem_pc_src;
wire        ex_mem_ctrl_reg_write, ex_mem_ctrl_mem_write, ex_mem_ctrl_mem_read,
            ex_mem_ctrl_mem_to_reg, ex_mem_ctrl_jal, ex_mem_ctrl_jalr;
// MEM/WB
wire [31:0] mem_wb_alu_result, mem_wb_mem_read_data, mem_wb_pc_plus_4,
            mem_wb_instruction;
wire        mem_wb_valid;
wire        mem_wb_ctrl_reg_write, mem_wb_ctrl_mem_to_reg, mem_wb_ctrl_jal,
            mem_wb_ctrl_jalr;

// =====================================================================
//  Etapa WB (combinacional) - se calcula primero porque alimenta a ID
// =====================================================================
wire [4:0]  write_back_rd        = mem_wb_instruction[11:7];
wire [31:0] write_back_value_pre = mem_wb_ctrl_mem_to_reg ? mem_wb_mem_read_data
                                                          : mem_wb_alu_result;
wire [31:0] write_back_data      = (mem_wb_ctrl_jal | mem_wb_ctrl_jalr)
                                   ? mem_wb_pc_plus_4 : write_back_value_pre;
wire        write_back_enable    = mem_wb_valid & mem_wb_ctrl_reg_write
                                   & (write_back_rd != 5'b0);

// =====================================================================
//  Etapa IF (fetch)
// =====================================================================
wire [31:0] pc_out, if_instruction, if_pc_plus_4;
wire [31:0] pc_next;

// freno de fetch al ver ebreak/nula (no busca mas alla del fin del programa)
wire ebreak_in_fetch = (if_instruction == EBREAK_INSTRUCTION)
                     || (if_instruction == 32'h00000000);

// Control de riesgos:
//   - stall por load-use (carga en EX).
//   - flush por salto tomado, resuelto en MEM (como el diagrama): PCSrc viene
//     de la etapa MEM (EX/MEM). Un salto tomado descarta 3 instrucciones jovenes.
//   - Prioridad flush > stall: un salto tomado en MEM anula el stall de una
//     carga mas joven (que de todos modos se descarta).
wire load_use_stall;                              // de hazard_unit
wire flush           = ex_mem_valid & ex_mem_pc_src;
wire stall_effective = load_use_stall & ~flush;
// El flush tiene prioridad sobre el freno por ebreak: si se busco
// especulativamente un ebreak detras del salto, la redireccion debe ganar para
// no congelar el PC en una instruccion que no se debe ejecutar.
wire pc_enable = cpu_enable & ~stall_effective & (flush | ~ebreak_in_fetch);

assign pc_next = flush ? ex_mem_branch_target : if_pc_plus_4;

pc u_pc (
    .clk(CLOCK_50), .rst(rst), .en(pc_enable),
    .pc_next(pc_next), .pc_out(pc_out)
);
adder u_pc_plus_4_adder (.a(pc_out), .b(32'd4), .out(if_pc_plus_4));
// puerto de depuracion de la memoria de instrucciones (columna de programa)
wire [31:0] vga_instr_debug_addr, vga_instr_debug_data;
instruction_memory u_instruction_memory (
    .addr(pc_out), .instr(if_instruction),
    .debug_addr(vga_instr_debug_addr), .debug_instr(vga_instr_debug_data)
);

// =====================================================================
//  Etapa ID (decode + lectura de registros + inmediato)
// =====================================================================
wire [4:0]  rs1 = if_id_instruction[19:15];
wire [4:0]  rs2 = if_id_instruction[24:20];
wire [31:0] rs1_data, rs2_data, imm;

wire        ctrl_reg_write, ctrl_alu_src, ctrl_alu_a_src, ctrl_alu_a_zero,
            ctrl_mem_write, ctrl_mem_read, ctrl_mem_to_reg,
            ctrl_branch, ctrl_jal, ctrl_jalr;
wire [1:0]  ctrl_alu_op;

control_unit u_control_unit (
    .opcode(if_id_instruction[6:0]),
    .reg_write(ctrl_reg_write), .alu_src(ctrl_alu_src), .alu_a_src(ctrl_alu_a_src),
    .alu_a_zero(ctrl_alu_a_zero),
    .mem_write(ctrl_mem_write), .mem_read(ctrl_mem_read), .mem_to_reg(ctrl_mem_to_reg),
    .branch(ctrl_branch), .jal(ctrl_jal), .jalr(ctrl_jalr), .alu_op(ctrl_alu_op)
);

// direccion de depuracion para la VGA
wire [4:0]  vga_reg_debug_addr;
wire [31:0] vga_reg_debug_data;
wire [7:0]  vga_mem_debug_addr;
wire [31:0] vga_mem_debug_data;

// El banco de registros tiene su puerto de escritura sincronico (etapa WB) y el
// bypass write-first interno (cubre la dependencia a distancia 3).
register_file u_register_file (
    .clk(CLOCK_50), .rst(rst),
    .write_enable(cpu_enable & write_back_enable),
    .write_reg(write_back_rd), .write_data(write_back_data),
    .rs1(rs1), .rs2(rs2),
    .debug_addr(vga_reg_debug_addr),
    .read_data1(rs1_data), .read_data2(rs2_data),
    .debug_data(vga_reg_debug_data)
);

imm_gen u_imm_gen (.instr(if_id_instruction), .imm_out(imm));

// =====================================================================
//  Etapa EX (execute)
// =====================================================================
// Forwarding: elige el origen de cada operando (ID/EX, EX/MEM o MEM/WB).
wire [1:0] forward_a, forward_b;
forwarding_unit u_forwarding (
    .ex_rs1(id_ex_instruction[19:15]), .ex_rs2(id_ex_instruction[24:20]),
    .mem_reg_write(ex_mem_ctrl_reg_write), .mem_rd(ex_mem_instruction[11:7]),
    .wb_reg_write(mem_wb_ctrl_reg_write),  .wb_rd(mem_wb_instruction[11:7]),
    .forward_a(forward_a), .forward_b(forward_b)
);

// Deteccion de riesgo load-use (carga en EX cuyo destino lee la instr en ID).
hazard_unit u_hazard (
    .idex_valid(id_ex_valid), .idex_mem_read(id_ex_ctrl_mem_read),
    .idex_rd(id_ex_instruction[11:7]),
    .ifid_rs1(if_id_instruction[19:15]), .ifid_rs2(if_id_instruction[24:20]),
    .load_use_stall(load_use_stall)
);

// Valor adelantado desde EX/MEM: para JAL/JALR es PC+4, no el resultado de ALU.
wire [31:0] ex_mem_forward_value = (ex_mem_ctrl_jal | ex_mem_ctrl_jalr)
                                   ? ex_mem_pc_plus_4 : ex_mem_alu_result;

wire [31:0] rs1_forwarded = (forward_a == 2'b10) ? ex_mem_forward_value :
                            (forward_a == 2'b01) ? write_back_data      : id_ex_rs1_data;
wire [31:0] rs2_forwarded = (forward_b == 2'b10) ? ex_mem_forward_value :
                            (forward_b == 2'b01) ? write_back_data      : id_ex_rs2_data;

wire [31:0] alu_operand_a = id_ex_ctrl_alu_a_zero ? 32'b0    :
                            id_ex_ctrl_alu_a_src  ? id_ex_pc : rs1_forwarded;
wire [31:0] alu_operand_b = id_ex_ctrl_alu_src   ? id_ex_imm : rs2_forwarded;

wire [3:0]  alu_control;
wire [31:0] alu_result;
wire        alu_zero;

alu_control u_alu_control (
    .alu_op(id_ex_ctrl_alu_op),
    .func3(id_ex_instruction[14:12]), .func7(id_ex_instruction[31:25]),
    .alu_ctrl(alu_control)
);
alu u_alu (
    .a(alu_operand_a), .b(alu_operand_b), .alu_ctrl(alu_control),
    .result(alu_result), .zero(alu_zero)
);

// Objetivo de salto relativo al PC (PC + inmediato).
wire [31:0] branch_target_pcrel;
adder u_branch_adder (.a(id_ex_pc), .b(id_ex_imm), .out(branch_target_pcrel));

reg branch_condition;
always @(*) begin
    case (id_ex_instruction[14:12])
        3'b000:  branch_condition =  alu_zero;       // BEQ
        3'b001:  branch_condition = ~alu_zero;       // BNE
        3'b100:  branch_condition =  alu_result[0];  // BLT
        3'b101:  branch_condition = ~alu_result[0];  // BGE
        3'b110:  branch_condition =  alu_result[0];  // BLTU
        3'b111:  branch_condition = ~alu_result[0];  // BGEU
        default: branch_condition = 1'b0;
    endcase
end
// Decision de salto calculada en EX; se latchea en EX/MEM y se actua en MEM.
wire        branch_taken     = id_ex_valid & id_ex_ctrl_branch & branch_condition;
wire        pc_src_ex        = branch_taken | (id_ex_valid & (id_ex_ctrl_jal | id_ex_ctrl_jalr));
// JALR: RV32I exige (rs1+imm) con el bit 0 forzado a 0.
wire [31:0] branch_target_ex = id_ex_ctrl_jalr ? {alu_result[31:1], 1'b0}
                                               : branch_target_pcrel;

// dato a almacenar (store), con forwarding aplicado
wire [31:0] store_data_ex = rs2_forwarded;

// =====================================================================
//  Etapa MEM
// =====================================================================
wire [31:0] mem_read_data;
data_memory u_data_memory (
    .clk(CLOCK_50),
    .mem_write(cpu_enable & ex_mem_valid & ex_mem_ctrl_mem_write),
    .mem_read(ex_mem_ctrl_mem_read),
    .addr(ex_mem_alu_result),
    .write_data(ex_mem_store_data),
    .read_data(mem_read_data),
    .debug_addr(vga_mem_debug_addr),
    .debug_data(vga_mem_debug_data)
);

// =====================================================================
//  Registros de pipeline (modulos discretos, como los bloques del diagrama)
// =====================================================================
pipe_ifid u_if_id (
    .clk(CLOCK_50), .rst(rst), .enable(cpu_enable),
    .flush(flush), .stall(load_use_stall),
    .in_pc(pc_out), .in_pc_plus_4(if_pc_plus_4), .in_instruction(if_instruction),
    .pc(if_id_pc), .pc_plus_4(if_id_pc_plus_4),
    .instruction(if_id_instruction), .valid(if_id_valid)
);

pipe_idex u_id_ex (
    .clk(CLOCK_50), .rst(rst), .enable(cpu_enable),
    .bubble(flush | load_use_stall),
    .in_valid(if_id_valid),
    .in_pc(if_id_pc), .in_pc_plus_4(if_id_pc_plus_4), .in_instruction(if_id_instruction),
    .in_imm(imm), .in_rs1_data(rs1_data), .in_rs2_data(rs2_data),
    .in_ctrl_reg_write(ctrl_reg_write), .in_ctrl_alu_src(ctrl_alu_src),
    .in_ctrl_alu_a_src(ctrl_alu_a_src), .in_ctrl_alu_a_zero(ctrl_alu_a_zero),
    .in_ctrl_mem_write(ctrl_mem_write),
    .in_ctrl_mem_read(ctrl_mem_read), .in_ctrl_mem_to_reg(ctrl_mem_to_reg),
    .in_ctrl_branch(ctrl_branch), .in_ctrl_jal(ctrl_jal), .in_ctrl_jalr(ctrl_jalr),
    .in_ctrl_alu_op(ctrl_alu_op),
    .pc(id_ex_pc), .pc_plus_4(id_ex_pc_plus_4), .instruction(id_ex_instruction),
    .imm(id_ex_imm), .rs1_data(id_ex_rs1_data), .rs2_data(id_ex_rs2_data),
    .valid(id_ex_valid),
    .ctrl_reg_write(id_ex_ctrl_reg_write), .ctrl_alu_src(id_ex_ctrl_alu_src),
    .ctrl_alu_a_src(id_ex_ctrl_alu_a_src), .ctrl_alu_a_zero(id_ex_ctrl_alu_a_zero),
    .ctrl_mem_write(id_ex_ctrl_mem_write),
    .ctrl_mem_read(id_ex_ctrl_mem_read), .ctrl_mem_to_reg(id_ex_ctrl_mem_to_reg),
    .ctrl_branch(id_ex_ctrl_branch), .ctrl_jal(id_ex_ctrl_jal),
    .ctrl_jalr(id_ex_ctrl_jalr), .ctrl_alu_op(id_ex_ctrl_alu_op)
);

pipe_exmem u_ex_mem (
    .clk(CLOCK_50), .rst(rst), .enable(cpu_enable), .flush(flush),
    .in_valid(id_ex_valid),
    .in_alu_result(alu_result), .in_store_data(store_data_ex),
    .in_pc_plus_4(id_ex_pc_plus_4), .in_instruction(id_ex_instruction),
    .in_branch_target(branch_target_ex), .in_pc_src(pc_src_ex),
    .in_ctrl_reg_write(id_ex_ctrl_reg_write), .in_ctrl_mem_write(id_ex_ctrl_mem_write),
    .in_ctrl_mem_read(id_ex_ctrl_mem_read), .in_ctrl_mem_to_reg(id_ex_ctrl_mem_to_reg),
    .in_ctrl_jal(id_ex_ctrl_jal), .in_ctrl_jalr(id_ex_ctrl_jalr),
    .alu_result(ex_mem_alu_result), .store_data(ex_mem_store_data),
    .pc_plus_4(ex_mem_pc_plus_4), .instruction(ex_mem_instruction),
    .branch_target(ex_mem_branch_target), .pc_src(ex_mem_pc_src),
    .valid(ex_mem_valid),
    .ctrl_reg_write(ex_mem_ctrl_reg_write), .ctrl_mem_write(ex_mem_ctrl_mem_write),
    .ctrl_mem_read(ex_mem_ctrl_mem_read), .ctrl_mem_to_reg(ex_mem_ctrl_mem_to_reg),
    .ctrl_jal(ex_mem_ctrl_jal), .ctrl_jalr(ex_mem_ctrl_jalr)
);

pipe_memwb u_mem_wb (
    .clk(CLOCK_50), .rst(rst), .enable(cpu_enable),
    .in_valid(ex_mem_valid),
    .in_alu_result(ex_mem_alu_result), .in_mem_read_data(mem_read_data),
    .in_pc_plus_4(ex_mem_pc_plus_4), .in_instruction(ex_mem_instruction),
    .in_ctrl_reg_write(ex_mem_ctrl_reg_write), .in_ctrl_mem_to_reg(ex_mem_ctrl_mem_to_reg),
    .in_ctrl_jal(ex_mem_ctrl_jal), .in_ctrl_jalr(ex_mem_ctrl_jalr),
    .alu_result(mem_wb_alu_result), .mem_read_data(mem_wb_mem_read_data),
    .pc_plus_4(mem_wb_pc_plus_4), .instruction(mem_wb_instruction),
    .valid(mem_wb_valid),
    .ctrl_reg_write(mem_wb_ctrl_reg_write), .ctrl_mem_to_reg(mem_wb_ctrl_mem_to_reg),
    .ctrl_jal(mem_wb_ctrl_jal), .ctrl_jalr(mem_wb_ctrl_jalr)
);

// Halt: se activa cuando un ebreak/instr-nula valido llega a WB.
always @(posedge CLOCK_50 or posedge rst) begin
    if (rst)
        halted <= 1'b0;
    else if (cpu_enable && mem_wb_valid &&
             (mem_wb_instruction == EBREAK_INSTRUCTION ||
              mem_wb_instruction == 32'h00000000))
        halted <= 1'b1;
end

// =====================================================================
//  VGA: vista por etapas del pipeline
// =====================================================================
wire [10:0] vga_x, vga_y;
wire        vga_video_on;

vga_controller u_vga_controller (
    .clk_50MHz(CLOCK_50), .reset(rst),
    .video_on(vga_video_on), .hsync(VGA_HS), .vsync(VGA_VS),
    .clk(VGA_CLK), .x(vga_x), .y(vga_y)
);

vga_debug u_vga_debug (
    .video_on(vga_video_on), .x(vga_x), .y(vga_y),
    // FETCH
    .fetch_pc(pc_out), .fetch_instr(if_instruction),
    .fetch_next_pc(pc_next), .fetch_ebreak(ebreak_in_fetch),
    // DECODE
    .decode_pc(if_id_pc), .decode_instr(if_id_instruction), .decode_imm(imm),
    // EXECUTE
    .exec_instr(id_ex_instruction), .exec_alu_a(alu_operand_a),
    .exec_alu_b(alu_operand_b), .exec_alu_result(alu_result),
    .exec_alu_zero(alu_zero),
    // MEMORY
    .mem_instr(ex_mem_instruction), .mem_addr(ex_mem_alu_result),
    .mem_store_data(ex_mem_store_data), .mem_read_data(mem_read_data),
    // WRITEBACK
    .wb_instr(mem_wb_instruction), .wb_data(write_back_data),
    .wb_rd(write_back_rd), .wb_reg_write(write_back_enable),
    // bus de control (instruccion en EXECUTE / ID-EX)
    .ctrl_reg_write(id_ex_ctrl_reg_write), .ctrl_alu_src(id_ex_ctrl_alu_src),
    .ctrl_alu_a_src(id_ex_ctrl_alu_a_src), .ctrl_alu_a_zero(id_ex_ctrl_alu_a_zero),
    .ctrl_mem_read(id_ex_ctrl_mem_read), .ctrl_mem_write(id_ex_ctrl_mem_write),
    .ctrl_mem_to_reg(id_ex_ctrl_mem_to_reg), .ctrl_branch(id_ex_ctrl_branch),
    .ctrl_jal(id_ex_ctrl_jal), .ctrl_jalr(id_ex_ctrl_jalr),
    .ctrl_alu_op(id_ex_ctrl_alu_op),
    // unidad de salto / branch (instruccion en EXECUTE)
    .branch_condition(branch_condition), .branch_taken(branch_taken),
    .pc_src(pc_src_ex), .branch_target(branch_target_ex),
    .alu_control(alu_control),
    // riesgos / forwarding / valid / halt
    .stall(load_use_stall), .flush(flush),
    .forward_a(forward_a), .forward_b(forward_b),
    .valid_decode(if_id_valid), .valid_exec(id_ex_valid),
    .valid_mem(ex_mem_valid), .valid_wb(mem_wb_valid),
    .halted(halted),
    // PCs de etapa para etiquetas de la columna de programa
    .exec_pc_tag(id_ex_pc), .mem_pc4_tag(ex_mem_pc_plus_4),
    .wb_pc4_tag(mem_wb_pc_plus_4),
    // depuracion de registros / memoria / instrucciones
    // pagina de memoria de datos seleccionada por SW[3:1] (8 paginas de 32)
    .mem_page(SW[3:1]),
    .reg_debug_addr(vga_reg_debug_addr), .reg_debug_data(vga_reg_debug_data),
    .mem_debug_addr(vga_mem_debug_addr), .mem_debug_data(vga_mem_debug_data),
    .instr_debug_addr(vga_instr_debug_addr), .instr_debug_data(vga_instr_debug_data),
    .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B)
);

assign VGA_BLANK_N = vga_video_on;
assign VGA_SYNC_N  = 1'b0;

// --- LEDs ---
assign LEDR[0]   = SW[0];
assign LEDR[8:1] = 8'b0;
assign LEDR[9]   = halted;

endmodule
