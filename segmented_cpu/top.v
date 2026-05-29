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
//   KEY[2] : memoria de datos -> pagina siguiente (+1, da la vuelta 7->0)
//   KEY[3] : memoria de datos -> pagina anterior (-1, da la vuelta 0->7)
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

// --- Tamano de la RAM de datos: una sola perilla ---
// Cambiar DATA_WORDS reajusta solo la memoria, el puerto de depuracion, el
// ancho de mem_page y el numero de paginas. Debe ser potencia de 2 y multiplo
// de 32 (1 pagina = 32 palabras). Por defecto 256 palabras = 1 KB.
localparam DATA_WORDS = 1024;
localparam DM_AW      = $clog2(DATA_WORDS);       // bits de direccion de palabra
localparam DM_PAGES   = DATA_WORDS / 32;          // paginas de 32 palabras
localparam DM_PW      = $clog2(DM_PAGES);          // bits del indice de pagina

// --- Reset ---
wire rst = ~KEY[0];

// --- Pulsadores con anti-rebote: paso manual y navegacion de pagina ---
wire step_pulse, page_next_pulse, page_prev_pulse;
button_pulse #(.DEBOUNCE_LIMIT(DEBOUNCE_LIMIT)) u_key_step (
    .clk(CLOCK_50), .rst(rst), .btn(KEY[1]), .pulse(step_pulse));
button_pulse #(.DEBOUNCE_LIMIT(DEBOUNCE_LIMIT)) u_key_page_next (
    .clk(CLOCK_50), .rst(rst), .btn(KEY[2]), .pulse(page_next_pulse));
button_pulse #(.DEBOUNCE_LIMIT(DEBOUNCE_LIMIT)) u_key_page_prev (
    .clk(CLOCK_50), .rst(rst), .btn(KEY[3]), .pulse(page_prev_pulse));

// Pagina de la memoria de datos (0..DM_PAGES-1, 32 palabras c/u). KEY[2]=+1,
// KEY[3]=-1, con vuelta explicita en los extremos (sirve para cualquier DM_PAGES).
reg [DM_PW-1:0] mem_page;
always @(posedge CLOCK_50 or posedge rst) begin
    if      (rst)             mem_page <= 0;
    else if (page_next_pulse) mem_page <= (mem_page == DM_PAGES-1) ? 0 : mem_page + 1'b1;
    else if (page_prev_pulse) mem_page <= (mem_page == 0) ? DM_PAGES-1 : mem_page - 1'b1;
end

// --- Halt: se activa cuando un ebreak/instr-nula valido llega a WB ---
reg halted;
// clock-enable global: modo paso = un tick por pulsacion, libre = corre hasta halt
wire cpu_enable = SW[0] ? (step_pulse && ~halted) : ~halted;

// =====================================================================
//  Salidas de los registros de pipeline (manejadas por los modulos pipe_*)
// =====================================================================
// IF/ID  (la instruccion viene del registro de salida de la ROM, ver IF)
wire [31:0] if_id_pc, if_id_pc_plus_4;
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
wire [31:0] mem_wb_alu_result, mem_wb_pc_plus_4, mem_wb_instruction;
wire        mem_wb_valid;
// Salida REGISTRADA de la RAM de datos (lectura sincronica M10K). La RAM ya
// retarda el dato un ciclo, asi que llega en WB sin pasar por el latch MEM/WB.
wire [31:0] mem_read_data;
wire        mem_wb_ctrl_reg_write, mem_wb_ctrl_mem_to_reg, mem_wb_ctrl_jal,
            mem_wb_ctrl_jalr;

// =====================================================================
//  Etapa WB (combinacional) - se calcula primero porque alimenta a ID
// =====================================================================
wire [4:0]  write_back_rd        = mem_wb_instruction[11:7];
// Carga sub-palabra (lb/lh/lbu/lhu/lw) segun funct3 + addr[1:0] (ambos ya en MEM/WB).
wire [2:0]  wb_funct3 = mem_wb_instruction[14:12];
wire [4:0]  wb_sh     = {mem_wb_alu_result[1:0], 3'b0};   // 8 * offset de byte
wire [7:0]  wb_byte   = mem_read_data >> wb_sh;
wire [15:0] wb_half   = mem_read_data >> wb_sh;
reg  [31:0] wb_load;
always @(*) begin
    case (wb_funct3)
        3'b000:  wb_load = {{24{wb_byte[7]}},  wb_byte};   // lb
        3'b001:  wb_load = {{16{wb_half[15]}}, wb_half};   // lh
        3'b100:  wb_load = {24'b0, wb_byte};               // lbu
        3'b101:  wb_load = {16'b0, wb_half};               // lhu
        default: wb_load = mem_read_data;                  // lw
    endcase
end
wire [31:0] write_back_value_pre = mem_wb_ctrl_mem_to_reg ? wb_load
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

// El registro de salida de la memoria de instrucciones (lectura sincronica M10K)
// hace de registro de instruccion IF/ID. Avanza con el fetch igual que pipe_ifid
// (cpu_enable y sin stall); el flush se aplica via el bit valid -> NOP.
wire        fetch_en = cpu_enable & ~load_use_stall;
wire [31:0] if_id_instruction = if_id_valid ? if_instruction : NOP_INSTRUCTION;

assign pc_next = flush ? ex_mem_branch_target : if_pc_plus_4;

pc u_pc (
    .clk(CLOCK_50), .rst(rst), .en(pc_enable),
    .pc_next(pc_next), .pc_out(pc_out)
);
adder u_pc_plus_4_adder (.a(pc_out), .b(32'd4), .out(if_pc_plus_4));
// puerto de depuracion de la memoria de instrucciones (columna de programa)
wire [31:0] vga_instr_debug_addr, vga_instr_debug_data;
instruction_memory u_instruction_memory (
    .clk(CLOCK_50), .rst(rst), .read_en(fetch_en),
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
wire [DM_AW-1:0] vga_mem_debug_addr;
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
// Store sub-palabra (sb/sh/sw): byte-enables + dato alineado al carril destino.
// El shift coloca el dato; byte_we enmascara los carriles no escritos.
wire [2:0]  dm_funct3 = ex_mem_instruction[14:12];
wire [1:0]  dm_off    = ex_mem_alu_result[1:0];
wire        dm_store  = cpu_enable & ex_mem_valid & ex_mem_ctrl_mem_write;
reg  [3:0]  dm_be;
reg  [31:0] dm_wdata;
always @(*) begin
    case (dm_funct3)
        3'b000:  begin dm_be = 4'b0001 << dm_off; dm_wdata = ex_mem_store_data << (8*dm_off); end // sb
        3'b001:  begin dm_be = 4'b0011 << dm_off; dm_wdata = ex_mem_store_data << (8*dm_off); end // sh
        default: begin dm_be = 4'b1111;           dm_wdata = ex_mem_store_data;               end // sw
    endcase
end

data_memory #(.WORDS(DATA_WORDS)) u_data_memory (
    .clk(CLOCK_50),
    .read_en(cpu_enable),
    .mem_read(ex_mem_ctrl_mem_read),
    .byte_we(dm_store ? dm_be : 4'b0),
    .addr(ex_mem_alu_result),
    .write_data(dm_wdata),
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
    .in_pc(pc_out), .in_pc_plus_4(if_pc_plus_4),
    .pc(if_id_pc), .pc_plus_4(if_id_pc_plus_4),
    .valid(if_id_valid)
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
    .in_alu_result(ex_mem_alu_result),
    .in_pc_plus_4(ex_mem_pc_plus_4), .in_instruction(ex_mem_instruction),
    .in_ctrl_reg_write(ex_mem_ctrl_reg_write), .in_ctrl_mem_to_reg(ex_mem_ctrl_mem_to_reg),
    .in_ctrl_jal(ex_mem_ctrl_jal), .in_ctrl_jalr(ex_mem_ctrl_jalr),
    .alu_result(mem_wb_alu_result),
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

vga_debug #(.DATA_WORDS(DATA_WORDS)) u_vga_debug (
    .clk(CLOCK_50),
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
    // pagina de memoria de datos (KEY[2]=+1, KEY[3]=-1), 8 paginas de 32
    .mem_page(mem_page),
    .reg_debug_addr(vga_reg_debug_addr), .reg_debug_data(vga_reg_debug_data),
    .mem_debug_addr(vga_mem_debug_addr), .mem_debug_data(vga_mem_debug_data),
    .instr_debug_addr(vga_instr_debug_addr), .instr_debug_data(vga_instr_debug_data),
    .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B)
);

assign VGA_BLANK_N = vga_video_on;
assign VGA_SYNC_N  = 1'b0;

// --- LEDs ---
assign LEDR[0]   = SW[0];        // modo paso
wire [2:0] mem_page_led = mem_page;  // 3 bits bajos de la pagina (indicador)
assign LEDR[3:1] = mem_page_led; // pagina de memoria de datos visible
assign LEDR[8:4] = 5'b0;
assign LEDR[9]   = halted;

endmodule
