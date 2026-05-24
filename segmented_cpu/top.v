// =============================================================================
// top.v - CPU RV32I SEGMENTADA (pipeline de 5 etapas) para la DE1-SoC.
// Etapas: IF (fetch) -> ID (decode) -> EX (execute) -> MEM -> WB.
// Registros de pipeline (IF/ID, ID/EX, EX/MEM, MEM/WB) son flip-flops que
// viven en este modulo, igual que el banco de registros (regs) y la memoria
// de datos (dmem). Los submodulos de datapath son combinacionales y se reusan
// del diseno monociclo sin cambios.
//
// NOTA (Step 1): aun NO hay forwarding ni deteccion de riesgos. El salto se
// resuelve en EX y redirige el PC, pero las 2 instrucciones ya buscadas detras
// del salto se ejecutan (delay slots): los programas de prueba de esta etapa
// estan rellenados con NOPs para evitar riesgos. El forwarding (Step 2) y la
// unidad de riesgos con stall/flush (Step 3) se agregan despues.
//
// Controles fisicos (igual que el monociclo):
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

localparam [31:0] NOP_INSTR    = 32'h00000013; // addi x0,x0,0
localparam [31:0] EBREAK_INSTR = 32'h00100073;

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
wire cpu_en = SW[0] ? (step_pulse && ~halted) : ~halted;

// =====================================================================
//  Registros de pipeline (modulos pipe_*; salidas cableadas aqui)
// =====================================================================
// IF/ID
wire [31:0] IFID_pc, IFID_pc4, IFID_instr;
wire        IFID_valid;
// ID/EX
wire [31:0] IDEX_pc, IDEX_pc4, IDEX_instr, IDEX_imm, IDEX_rdata1, IDEX_rdata2;
wire        IDEX_valid;
wire        IDEX_reg_write, IDEX_alu_src, IDEX_alu_a_src, IDEX_mem_write,
            IDEX_mem_read, IDEX_mem_to_reg, IDEX_branch, IDEX_jal, IDEX_jalr;
wire [1:0]  IDEX_alu_op;
// EX/MEM
wire [31:0] EXMEM_alu_result, EXMEM_store_data, EXMEM_pc4, EXMEM_instr;
wire [31:0] EXMEM_branch_target;
wire        EXMEM_valid;
wire        EXMEM_reg_write, EXMEM_mem_write, EXMEM_mem_read, EXMEM_mem_to_reg,
            EXMEM_jal, EXMEM_jalr, EXMEM_pc_src;
// MEM/WB
wire [31:0] MEMWB_alu_result, MEMWB_mem_data, MEMWB_pc4, MEMWB_instr;
wire        MEMWB_valid;
wire        MEMWB_reg_write, MEMWB_mem_to_reg, MEMWB_jal, MEMWB_jalr;


// =====================================================================
//  Etapa WB (combinacional) - se calcula primero porque alimenta a ID
// =====================================================================
wire [4:0]  wb_rd   = MEMWB_instr[11:7];
wire [31:0] wb_pre  = MEMWB_mem_to_reg ? MEMWB_mem_data : MEMWB_alu_result;
wire [31:0] wb_data = (MEMWB_jal | MEMWB_jalr) ? MEMWB_pc4 : wb_pre;
wire        wb_we   = MEMWB_valid & MEMWB_reg_write & (wb_rd != 5'b0);

// =====================================================================
//  Etapa IF (fetch)
// =====================================================================
wire [31:0] pc_out, instr_IF, pc4_IF;
wire [31:0] pc_next;

// freno de fetch al ver ebreak/nula (no busca mas alla del fin del programa)
wire        ebreak_IF = (instr_IF == EBREAK_INSTR) || (instr_IF == 32'h00000000);

// Control de riesgos:
//   - stall por load-use (carga en EX).
//   - flush por salto tomado, resuelto en MEM (como el diagrama): PCSrc viene
//     de la etapa MEM (EX/MEM). Un salto tomado descarta 3 instrucciones jovenes.
//   - Prioridad flush > stall: un salto tomado en MEM anula el stall de una
//     carga mas joven (que de todos modos se descarta).
wire        load_use_stall;                       // de hazard_unit
wire        flush     = EXMEM_valid & EXMEM_pc_src;
wire        stall_eff = load_use_stall & ~flush;
// El flush (salto tomado) tiene prioridad sobre el freno por ebreak: si se
// busco especulativamente un ebreak detras del salto, el redireccion debe
// ganar para no congelar el PC en una instruccion que no se debe ejecutar.
wire        pc_en     = cpu_en & ~stall_eff & (flush | ~ebreak_IF);

assign pc_next = flush ? EXMEM_branch_target : pc4_IF;

pc u_pc (.clk(CLOCK_50), .rst(rst), .en(pc_en), .pc_next(pc_next), .pc_out(pc_out));
adder u_pc_plus4 (.a(pc_out), .b(32'd4), .out(pc4_IF));
instruction_memory u_imem (.addr(pc_out), .instr(instr_IF));

// =====================================================================
//  Etapa ID (decode + lectura de registros + inmediato)
// =====================================================================
wire [4:0]  rs1_ID = IFID_instr[19:15];
wire [4:0]  rs2_ID = IFID_instr[24:20];
wire [31:0] rdata1_ID, rdata2_ID, imm_ID;

wire        c_reg_write, c_alu_src, c_alu_a_src, c_mem_write, c_mem_read,
            c_mem_to_reg, c_branch, c_jal, c_jalr;
wire [1:0]  c_alu_op;

control_unit u_ctrl (
    .opcode(IFID_instr[6:0]),
    .reg_write(c_reg_write), .alu_src(c_alu_src), .alu_a_src(c_alu_a_src),
    .mem_write(c_mem_write), .mem_read(c_mem_read), .mem_to_reg(c_mem_to_reg),
    .branch(c_branch), .jal(c_jal), .jalr(c_jalr), .alu_op(c_alu_op)
);

// direccion de depuracion para la VGA
wire [4:0]  vga_dbg_addr;
wire [31:0] vga_dbg_data;
wire [4:0]  vga_mem_addr;
wire [31:0] vga_mem_data;

// El banco de registros tiene su puerto de escritura sincronico (etapa WB) y el
// bypass write-first interno (cubre la dependencia a distancia 3).
register_file u_regfile (
    .clk(CLOCK_50), .rst(rst),
    .we(cpu_en & wb_we), .wa(wb_rd), .wd(wb_data),
    .rs1(rs1_ID), .rs2(rs2_ID),
    .debug_addr(vga_dbg_addr),
    .read_data1(rdata1_ID), .read_data2(rdata2_ID),
    .debug_data(vga_dbg_data)
);

imm_gen u_immgen (.instr(IFID_instr), .imm_out(imm_ID));

// =====================================================================
//  Etapa EX (execute)
// =====================================================================
// Forwarding: selecciona el origen de cada operando (ID/EX, EX/MEM o MEM/WB)
wire [1:0] forward_a, forward_b;
forwarding_unit u_fwd (
    .ex_rs1(IDEX_instr[19:15]), .ex_rs2(IDEX_instr[24:20]),
    .mem_reg_write(EXMEM_reg_write), .mem_rd(EXMEM_instr[11:7]),
    .wb_reg_write(MEMWB_reg_write),  .wb_rd(MEMWB_instr[11:7]),
    .forward_a(forward_a), .forward_b(forward_b)
);

// Deteccion de riesgo load-use (carga en EX cuyo destino lee la instr en ID)
hazard_unit u_hzd (
    .idex_valid(IDEX_valid), .idex_mem_read(IDEX_mem_read),
    .idex_rd(IDEX_instr[11:7]),
    .ifid_rs1(IFID_instr[19:15]), .ifid_rs2(IFID_instr[24:20]),
    .load_use_stall(load_use_stall)
);

// Valor adelantado desde EX/MEM: para JAL/JALR es PC+4, no el resultado de ALU.
// (Una carga en EX/MEM aun no tiene el dato; ese caso lo resuelve el stall del Step 3.)
wire [31:0] exmem_fwd_val = (EXMEM_jal | EXMEM_jalr) ? EXMEM_pc4 : EXMEM_alu_result;

wire [31:0] fwd_a = (forward_a == 2'b10) ? exmem_fwd_val :
                    (forward_a == 2'b01) ? wb_data        : IDEX_rdata1;
wire [31:0] fwd_b = (forward_b == 2'b10) ? exmem_fwd_val :
                    (forward_b == 2'b01) ? wb_data        : IDEX_rdata2;

wire [31:0] alu_a = IDEX_alu_a_src ? IDEX_pc  : fwd_a;
wire [31:0] alu_b = IDEX_alu_src   ? IDEX_imm : fwd_b;

wire [3:0]  alu_ctrl;
wire [31:0] alu_result;
wire        alu_zero;

alu_control u_alu_ctrl (
    .alu_op(IDEX_alu_op), .func3(IDEX_instr[14:12]), .func7(IDEX_instr[31:25]),
    .alu_ctrl(alu_ctrl)
);
alu u_alu (.a(alu_a), .b(alu_b), .alu_ctrl(alu_ctrl),
           .result(alu_result), .zero(alu_zero));

wire [31:0] pc_branch_EX;
adder u_pc_branch (.a(IDEX_pc), .b(IDEX_imm), .out(pc_branch_EX));

reg branch_cond;
always @(*) begin
    case (IDEX_instr[14:12])
        3'b000:  branch_cond =  alu_zero;       // BEQ
        3'b001:  branch_cond = ~alu_zero;       // BNE
        3'b100:  branch_cond =  alu_result[0];  // BLT
        3'b101:  branch_cond = ~alu_result[0];  // BGE
        3'b110:  branch_cond =  alu_result[0];  // BLTU
        3'b111:  branch_cond = ~alu_result[0];  // BGEU
        default: branch_cond = 1'b0;
    endcase
end
// Decision de salto calculada en EX; se LATCHEA en EX/MEM y se actua en MEM.
wire branch_taken    = IDEX_valid & IDEX_branch & branch_cond;
wire pc_src_EX       = branch_taken | (IDEX_valid & (IDEX_jal | IDEX_jalr));
wire [31:0] branch_target_EX = IDEX_jalr ? alu_result : pc_branch_EX;

// dato a almacenar (store)
wire [31:0] store_data_EX = fwd_b;

// =====================================================================
//  Etapa MEM
// =====================================================================
wire [31:0] mem_data_MEM;
data_memory u_dmem (
    .clk(CLOCK_50),
    .mem_write(cpu_en & EXMEM_valid & EXMEM_mem_write),
    .mem_read(EXMEM_mem_read),
    .addr(EXMEM_alu_result),
    .write_data(EXMEM_store_data),
    .read_data(mem_data_MEM),
    .debug_addr(vga_mem_addr),
    .debug_data(vga_mem_data)
);

// =====================================================================
//  Registros de pipeline (modulos discretos, como los bloques del diagrama)
// =====================================================================
pipe_ifid u_ifid (
    .clk(CLOCK_50), .rst(rst), .en(cpu_en),
    .flush(flush), .stall(load_use_stall),
    .in_pc(pc_out), .in_pc4(pc4_IF), .in_instr(instr_IF),
    .pc(IFID_pc), .pc4(IFID_pc4), .instr(IFID_instr), .valid(IFID_valid)
);

pipe_idex u_idex (
    .clk(CLOCK_50), .rst(rst), .en(cpu_en),
    .bubble(flush | load_use_stall),
    .in_valid(IFID_valid),
    .in_pc(IFID_pc), .in_pc4(IFID_pc4), .in_instr(IFID_instr),
    .in_imm(imm_ID), .in_rdata1(rdata1_ID), .in_rdata2(rdata2_ID),
    .in_reg_write(c_reg_write), .in_alu_src(c_alu_src), .in_alu_a_src(c_alu_a_src),
    .in_mem_write(c_mem_write), .in_mem_read(c_mem_read), .in_mem_to_reg(c_mem_to_reg),
    .in_branch(c_branch), .in_jal(c_jal), .in_jalr(c_jalr), .in_alu_op(c_alu_op),
    .pc(IDEX_pc), .pc4(IDEX_pc4), .instr(IDEX_instr), .imm(IDEX_imm),
    .rdata1(IDEX_rdata1), .rdata2(IDEX_rdata2), .valid(IDEX_valid),
    .reg_write(IDEX_reg_write), .alu_src(IDEX_alu_src), .alu_a_src(IDEX_alu_a_src),
    .mem_write(IDEX_mem_write), .mem_read(IDEX_mem_read), .mem_to_reg(IDEX_mem_to_reg),
    .branch(IDEX_branch), .jal(IDEX_jal), .jalr(IDEX_jalr), .alu_op(IDEX_alu_op)
);

pipe_exmem u_exmem (
    .clk(CLOCK_50), .rst(rst), .en(cpu_en), .flush(flush),
    .in_valid(IDEX_valid),
    .in_alu_result(alu_result), .in_store_data(store_data_EX),
    .in_pc4(IDEX_pc4), .in_instr(IDEX_instr),
    .in_branch_target(branch_target_EX), .in_pc_src(pc_src_EX),
    .in_reg_write(IDEX_reg_write), .in_mem_write(IDEX_mem_write),
    .in_mem_read(IDEX_mem_read), .in_mem_to_reg(IDEX_mem_to_reg),
    .in_jal(IDEX_jal), .in_jalr(IDEX_jalr),
    .alu_result(EXMEM_alu_result), .store_data(EXMEM_store_data),
    .pc4(EXMEM_pc4), .instr(EXMEM_instr),
    .branch_target(EXMEM_branch_target), .pc_src(EXMEM_pc_src),
    .valid(EXMEM_valid), .reg_write(EXMEM_reg_write), .mem_write(EXMEM_mem_write),
    .mem_read(EXMEM_mem_read), .mem_to_reg(EXMEM_mem_to_reg),
    .jal(EXMEM_jal), .jalr(EXMEM_jalr)
);

pipe_memwb u_memwb (
    .clk(CLOCK_50), .rst(rst), .en(cpu_en),
    .in_valid(EXMEM_valid),
    .in_alu_result(EXMEM_alu_result), .in_mem_data(mem_data_MEM),
    .in_pc4(EXMEM_pc4), .in_instr(EXMEM_instr),
    .in_reg_write(EXMEM_reg_write), .in_mem_to_reg(EXMEM_mem_to_reg),
    .in_jal(EXMEM_jal), .in_jalr(EXMEM_jalr),
    .alu_result(MEMWB_alu_result), .mem_data(MEMWB_mem_data),
    .pc4(MEMWB_pc4), .instr(MEMWB_instr), .valid(MEMWB_valid),
    .reg_write(MEMWB_reg_write), .mem_to_reg(MEMWB_mem_to_reg),
    .jal(MEMWB_jal), .jalr(MEMWB_jalr)
);

// Halt: se activa cuando un ebreak/instr-nula valido llega a WB.
always @(posedge CLOCK_50 or posedge rst) begin
    if (rst)
        halted <= 1'b0;
    else if (cpu_en && MEMWB_valid &&
             (MEMWB_instr == EBREAK_INSTR || MEMWB_instr == 32'h00000000))
        halted <= 1'b1;
end

// =====================================================================
//  VGA: vista por etapas del pipeline (Step 5)
// =====================================================================
wire [9:0] vga_x, vga_y;
wire       vga_video_on;

vga_controller u_vgac (
    .clk_50MHz(CLOCK_50), .reset(rst),
    .video_on(vga_video_on), .hsync(VGA_HS), .vsync(VGA_VS),
    .clk(VGA_CLK), .x(vga_x), .y(vga_y)
);

vga_debug u_vgad (
    .video_on(vga_video_on), .x(vga_x), .y(vga_y),
    // IF
    .if_pc(pc_out),       .if_instr(instr_IF),
    // ID
    .id_pc(IFID_pc),      .id_instr(IFID_instr),
    // EX
    .ex_pc(IDEX_pc),      .ex_instr(IDEX_instr), .ex_alu(alu_result),
    // MEM
    .mem_instr(EXMEM_instr), .mem_alu(EXMEM_alu_result),
    // WB
    .wb_instr(MEMWB_instr), .wb_data(wb_data), .wb_rd(wb_rd), .wb_we(wb_we),
    // riesgos / forwarding / halt
    .stall(load_use_stall), .flush(flush),
    .forward_a(forward_a), .forward_b(forward_b), .halted(halted),
    // depuracion de registros y memoria
    .reg_debug_addr(vga_dbg_addr), .reg_debug_data(vga_dbg_data),
    .mem_debug_addr(vga_mem_addr), .mem_debug_data(vga_mem_data),
    .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B)
);

assign VGA_BLANK_N = vga_video_on;
assign VGA_SYNC_N  = 1'b0;

// --- LEDs ---
assign LEDR[0]   = SW[0];
assign LEDR[8:1] = 8'b0;
assign LEDR[9]   = halted;

endmodule
