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
//  Registros de pipeline
// =====================================================================
// IF/ID
reg [31:0] IFID_pc, IFID_pc4, IFID_instr;
reg        IFID_valid;
// ID/EX
reg [31:0] IDEX_pc, IDEX_pc4, IDEX_instr, IDEX_imm, IDEX_rdata1, IDEX_rdata2;
reg        IDEX_valid;
reg        IDEX_reg_write, IDEX_alu_src, IDEX_alu_a_src, IDEX_mem_write,
           IDEX_mem_read, IDEX_mem_to_reg, IDEX_branch, IDEX_jal, IDEX_jalr;
reg [1:0]  IDEX_alu_op;
// EX/MEM
reg [31:0] EXMEM_alu_result, EXMEM_store_data, EXMEM_pc4, EXMEM_instr;
reg        EXMEM_valid;
reg        EXMEM_reg_write, EXMEM_mem_write, EXMEM_mem_read, EXMEM_mem_to_reg,
           EXMEM_jal, EXMEM_jalr;
// MEM/WB
reg [31:0] MEMWB_alu_result, MEMWB_mem_data, MEMWB_pc4, MEMWB_instr;
reg        MEMWB_valid;
reg        MEMWB_reg_write, MEMWB_mem_to_reg, MEMWB_jal, MEMWB_jalr;

// --- Almacenamiento arquitectonico (FF en top) ---
reg [31:0] regs [0:31];
reg [31:0] dmem [0:255];
wire [32*32-1:0]  regs_flat;
wire [256*32-1:0] dmem_flat;
integer ri;

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

// senales de salto generadas en EX (declaradas aqui para el mux de PC)
wire        pc_src;
wire [31:0] branch_target;

// freno de fetch al ver ebreak/nula (no busca mas alla del fin del programa)
wire        ebreak_IF = (instr_IF == EBREAK_INSTR) || (instr_IF == 32'h00000000);

// control de riesgos: stall por load-use, flush por salto tomado en EX
wire        load_use_stall;          // de hazard_unit (instanciada abajo)
wire        flush = pc_src;          // salto/branch tomado resuelto en EX
wire        pc_en = cpu_en & ~load_use_stall & ~ebreak_IF;

assign pc_next = pc_src ? branch_target : pc4_IF;

pc u_pc (.clk(CLOCK_50), .rst(rst), .en(pc_en), .pc_next(pc_next), .pc_out(pc_out));
adder u_pc_plus4 (.a(pc_out), .b(32'd4), .out(pc4_IF));
instruction_memory u_imem (.addr(pc_out), .instr(instr_IF));

// =====================================================================
//  Etapa ID (decode + lectura de registros + inmediato)
// =====================================================================
wire [4:0]  rs1_ID = IFID_instr[19:15];
wire [4:0]  rs2_ID = IFID_instr[24:20];
wire [31:0] rf_rdata1, rf_rdata2, imm_ID, exit_code;

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

register_file u_regfile (
    .regs_flat(regs_flat),
    .rs1(rs1_ID), .rs2(rs2_ID),
    .debug_addr(vga_dbg_addr),
    .read_data1(rf_rdata1), .read_data2(rf_rdata2),
    .debug_data(vga_dbg_data), .exit_code(exit_code)
);

imm_gen u_immgen (.instr(IFID_instr), .imm_out(imm_ID));

// Bypass WB->ID: si la instruccion en WB escribe el mismo registro que se lee
// aqui, se usa wb_data directamente (cubre la dependencia a distancia 3, que el
// forwarding EX/MEM y MEM/WB no alcanza por la escritura sincronica del banco).
wire [31:0] rdata1_ID = (wb_we && (wb_rd == rs1_ID)) ? wb_data : rf_rdata1;
wire [31:0] rdata2_ID = (wb_we && (wb_rd == rs2_ID)) ? wb_data : rf_rdata2;

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
wire branch_taken = IDEX_valid & IDEX_branch & branch_cond;
assign pc_src        = branch_taken | (IDEX_valid & (IDEX_jal | IDEX_jalr));
assign branch_target = IDEX_jalr ? alu_result : pc_branch_EX;

// dato a almacenar (store) - Step 1 sin forwarding
wire [31:0] store_data_EX = fwd_b;

// =====================================================================
//  Etapa MEM
// =====================================================================
wire [31:0] mem_data_MEM;
data_memory u_dmem (
    .mem_flat(dmem_flat),
    .mem_read(EXMEM_mem_read),
    .addr(EXMEM_alu_result),
    .read_data(mem_data_MEM),
    .debug_addr(vga_mem_addr),
    .debug_data(vga_mem_data)
);

// =====================================================================
//  Registros de pipeline: avance, escrituras arquitectonicas, halt
// =====================================================================
always @(posedge CLOCK_50 or posedge rst) begin
    if (rst) begin
        IFID_valid  <= 1'b0; IFID_instr <= NOP_INSTR; IFID_pc <= 32'b0; IFID_pc4 <= 32'b0;
        IDEX_valid  <= 1'b0; IDEX_instr <= NOP_INSTR;
        IDEX_reg_write <= 1'b0; IDEX_mem_write <= 1'b0;
        EXMEM_valid <= 1'b0; EXMEM_instr <= NOP_INSTR;
        EXMEM_reg_write <= 1'b0; EXMEM_mem_write <= 1'b0;
        MEMWB_valid <= 1'b0; MEMWB_instr <= NOP_INSTR;
        MEMWB_reg_write <= 1'b0;
        halted      <= 1'b0;
        for (ri = 0; ri < 32; ri = ri + 1) regs[ri] <= 32'b0;
    end else if (cpu_en) begin
        // IF -> IF/ID
        //   flush (salto tomado): burbuja; stall (load-use): congelar (mantener)
        if (flush) begin
            IFID_valid <= 1'b0;
            IFID_instr <= NOP_INSTR;
        end else if (load_use_stall) begin
            // mantener IF/ID sin cambios (la misma instruccion espera en ID)
        end else begin
            IFID_pc    <= pc_out;
            IFID_pc4   <= pc4_IF;
            IFID_instr <= instr_IF;
            IFID_valid <= 1'b1;
        end

        // ID -> ID/EX
        //   flush o stall: inyectar burbuja (instr nula, sin efectos)
        if (flush || load_use_stall) begin
            IDEX_valid     <= 1'b0;
            IDEX_instr     <= NOP_INSTR;
            IDEX_reg_write <= 1'b0;
            IDEX_mem_write <= 1'b0;
            IDEX_mem_read  <= 1'b0;
            IDEX_mem_to_reg<= 1'b0;
            IDEX_branch    <= 1'b0;
            IDEX_jal       <= 1'b0;
            IDEX_jalr      <= 1'b0;
        end else begin
            IDEX_pc        <= IFID_pc;
            IDEX_pc4       <= IFID_pc4;
            IDEX_instr     <= IFID_instr;
            IDEX_imm       <= imm_ID;
            IDEX_rdata1    <= rdata1_ID;
            IDEX_rdata2    <= rdata2_ID;
            IDEX_valid     <= IFID_valid;
            IDEX_reg_write <= c_reg_write;
            IDEX_alu_src   <= c_alu_src;
            IDEX_alu_a_src <= c_alu_a_src;
            IDEX_mem_write <= c_mem_write;
            IDEX_mem_read  <= c_mem_read;
            IDEX_mem_to_reg<= c_mem_to_reg;
            IDEX_branch    <= c_branch;
            IDEX_jal       <= c_jal;
            IDEX_jalr      <= c_jalr;
            IDEX_alu_op    <= c_alu_op;
        end

        // EX -> EX/MEM
        EXMEM_alu_result <= alu_result;
        EXMEM_store_data <= store_data_EX;
        EXMEM_pc4        <= IDEX_pc4;
        EXMEM_instr      <= IDEX_instr;
        EXMEM_valid      <= IDEX_valid;
        EXMEM_reg_write  <= IDEX_reg_write;
        EXMEM_mem_write  <= IDEX_mem_write;
        EXMEM_mem_read   <= IDEX_mem_read;
        EXMEM_mem_to_reg <= IDEX_mem_to_reg;
        EXMEM_jal        <= IDEX_jal;
        EXMEM_jalr       <= IDEX_jalr;

        // MEM -> MEM/WB
        MEMWB_alu_result <= EXMEM_alu_result;
        MEMWB_mem_data   <= mem_data_MEM;
        MEMWB_pc4        <= EXMEM_pc4;
        MEMWB_instr      <= EXMEM_instr;
        MEMWB_valid      <= EXMEM_valid;
        MEMWB_reg_write  <= EXMEM_reg_write;
        MEMWB_mem_to_reg <= EXMEM_mem_to_reg;
        MEMWB_jal        <= EXMEM_jal;
        MEMWB_jalr       <= EXMEM_jalr;

        // WB: escritura al banco de registros
        if (wb_we) regs[wb_rd] <= wb_data;

        // halt cuando un ebreak/instr-nula valido llega a WB
        if (MEMWB_valid && (MEMWB_instr == EBREAK_INSTR || MEMWB_instr == 32'h00000000))
            halted <= 1'b1;
    end
end

// escritura a memoria de datos (etapa MEM)
always @(posedge CLOCK_50) begin
    if (cpu_en && EXMEM_valid && EXMEM_mem_write)
        dmem[EXMEM_alu_result[31:2]] <= EXMEM_store_data;
end

// empaquetado de regs y dmem hacia los submodulos combinacionales
genvar gri;
generate
    for (gri = 0; gri < 32; gri = gri + 1) begin : pack_regs
        assign regs_flat[32*gri +: 32] = regs[gri];
    end
endgenerate
genvar gmi;
generate
    for (gmi = 0; gmi < 256; gmi = gmi + 1) begin : pack_dmem
        assign dmem_flat[32*gmi +: 32] = dmem[gmi];
    end
endgenerate

// =====================================================================
//  VGA (vista provisional; el rediseno por etapas es el Step 5)
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
    .pc_out(pc_out), .instr(IFID_instr), .imm_ext(IDEX_imm),
    .alu_result(alu_result),
    .alu_operand_a(alu_a), .alu_operand_b(alu_b),
    .reg_data1(rdata1_ID), .reg_data2(rdata2_ID),
    .wb_data(wb_data), .mem_data_out(mem_data_MEM),
    .alu_zero(alu_zero), .halted(halted), .branch_taken(branch_taken),
    .alu_op(IDEX_alu_op), .alu_ctrl(alu_ctrl),
    .reg_write(c_reg_write), .mem_read(c_mem_read), .mem_write(c_mem_write),
    .mem_to_reg(c_mem_to_reg), .alu_src(c_alu_src), .alu_a_src(c_alu_a_src),
    .branch(c_branch), .jal(c_jal), .jalr(c_jalr), .pc_src(pc_src),
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
