# VGA Debug Display Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the segmented_cpu VGA debug view at 800x600@72 (100x37 chars) with full signal names, all pipeline/control/jump/branch/hazard signals, 32 registers, 32 data-memory words shown as colored little-endian bytes, and a right-edge program column that scrolls around the fetch PC with per-stage occupancy tags.

**Architecture:** Pixel logic moves to a 50 MHz dot clock (VESA 800x600@72) driven straight from `CLOCK_50` - no PLL, no `clock_div`. `vga_debug` stays fully combinational (one character per pixel from `font128.hex`). A single combinational debug read port is added to `instruction_memory` so the program column can show the instruction word for the row being drawn. The CPU datapath is unchanged; only the debug view and VGA timing change.

**Tech Stack:** Verilog-2001, iverilog/vvp simulation (`segmented_cpu/test/Makefile`), Intel Quartus (Cyclone V, DE1-SoC).

**Spec:** `docs/superpowers/specs/2026-05-26-vga-debug-redisplay-design.md`

---

## File structure

| File | Responsibility | Change |
|---|---|---|
| `segmented_cpu/instruction_memory.v` | program ROM | add combinational debug read port |
| `segmented_cpu/vga_controller.v` | VGA timing | rewrite to 800x600@72 @ 50 MHz, x/y to [10:0], VGA_CLK = CLOCK_50 |
| `segmented_cpu/segmented.sdc` | timing constraints | drop divide-by-2 VGA_CLK25; VGA_CLK = CLOCK_50 1:1 |
| `segmented_cpu/vga_debug.v` | debug renderer | full rewrite (100x37 layout, byte color, program column) |
| `segmented_cpu/top.v` | top-level wiring | widen vga x/y, wire ~25 signals + instr debug port |

No new files. `segmented.qsf` unchanged (`clock_div.v` stays listed but unused). `test/Makefile` unchanged. `font128.hex` unchanged.

**Verification reality:** iverilog does not render VGA; simulation only proves the design *compiles* and the CPU still behaves (golden: `final_test` halts with `x10=0`). Visual correctness is confirmed on the DE1-SoC.

---

## Task 1: Add debug read port to instruction_memory

**Files:**
- Modify: `segmented_cpu/instruction_memory.v`

- [ ] **Step 1: Add the debug port**

Replace the whole module body with:

```verilog
module instruction_memory #(
    parameter HEX_FILE  = "program.hex",
    parameter MEM_DEPTH = 1024
) (
    input  [31:0] addr,         // direccion byte desde el PC
    output [31:0] instr,        // instruccion de 32 bits (fetch)
    input  [31:0] debug_addr,   // indice de palabra a mostrar en la VGA
    output [31:0] debug_instr   // instruccion en debug_addr (lectura combinacional)
);

reg [31:0] mem [0:MEM_DEPTH-1];

initial begin
    $readmemh(HEX_FILE, mem);
end

assign instr       = mem[addr[31:2]];
assign debug_instr = mem[debug_addr[9:0]];

endmodule
```

- [ ] **Step 2: Compile-check the module**

Run: `cd segmented_cpu/test && iverilog -o /tmp/imem.vvp ../instruction_memory.v`
Expected: no errors (a module with no top-level is fine; iverilog just compiles it).

- [ ] **Step 3: Commit**

```bash
cd /home/santiago/projects/uni/Computers_Arquitecture/rv32i-cpu
git add segmented_cpu/instruction_memory.v
git commit -m "feat(segmented): add combinational debug read port to instruction_memory"
```

---

## Task 2: Rewrite vga_controller for 800x600@72 (50 MHz dot clock)

**Files:**
- Modify: `segmented_cpu/vga_controller.v`

- [ ] **Step 1: Replace the entire file**

```verilog
// VGA timing generator for 800x600 @ 72 Hz (VESA), 50 MHz dot clock.
// The 50 MHz input IS the pixel clock (no PLL, no divider). VGA_CLK pin is
// driven directly from clk_50MHz. Character grid with the 8x16 font: 100x37.
module vga_controller (
    input         clk_50MHz,
    input         reset,
    output        video_on,
    output        hsync,
    output        vsync,
    output        clk,        // pixel clock out (= clk_50MHz, drives VGA_CLK pin)
    output [10:0] x,
    output [10:0] y
);
    // VESA 800x600 @ 72 Hz, dot clock 50.000 MHz
    parameter HD = 800;  // horizontal display
    parameter HF = 56;   // front porch
    parameter HR = 120;  // sync (retrace)
    parameter HB = 64;   // back porch
    parameter HMAX = HD + HF + HR + HB - 1; // 1039

    parameter VD = 600;
    parameter VF = 37;
    parameter VR = 6;
    parameter VB = 23;
    parameter VMAX = VD + VF + VR + VB - 1; // 665

    reg [10:0] h_count, v_count;
    reg        h_sync_reg, v_sync_reg;

    always @(posedge clk_50MHz or posedge reset) begin
        if (reset) begin
            h_count    <= 11'd0;
            v_count    <= 11'd0;
            h_sync_reg <= 1'b0;
            v_sync_reg <= 1'b0;
        end else begin
            if (h_count == HMAX) begin
                h_count <= 11'd0;
                v_count <= (v_count == VMAX) ? 11'd0 : v_count + 11'd1;
            end else begin
                h_count <= h_count + 11'd1;
            end
            // 800x600@72 uses POSITIVE sync polarity (pulse = 1)
            h_sync_reg <= (h_count >= (HD + HF)) && (h_count < (HD + HF + HR));
            v_sync_reg <= (v_count >= (VD + VF)) && (v_count < (VD + VF + VR));
        end
    end

    assign hsync    = h_sync_reg;
    assign vsync    = v_sync_reg;
    assign x        = h_count;
    assign y        = v_count;
    assign video_on = (h_count < HD) && (v_count < VD);
    assign clk      = clk_50MHz;
endmodule
```

- [ ] **Step 2: Compile-check**

Run: `cd segmented_cpu/test && iverilog -o /tmp/vgac.vvp ../vga_controller.v`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
cd /home/santiago/projects/uni/Computers_Arquitecture/rv32i-cpu
git add segmented_cpu/vga_controller.v
git commit -m "feat(segmented): VGA controller 800x600@72 on 50MHz dot clock (no divider)"
```

---

## Task 3: Update SDC for the single 50 MHz pixel clock

**Files:**
- Modify: `segmented_cpu/segmented.sdc`

- [ ] **Step 1: Replace the entire file**

The old file constrains a generated 25 MHz clock on `u_clkdiv|state[0]`, which no longer exists. VGA_CLK is now `CLOCK_50` forwarded to the pin.

```tcl
# Reloj principal de 50 MHz (entrada CLOCK_50).
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]

# VGA_CLK ahora se maneja directamente desde CLOCK_50 (800x600@72, 50 MHz).
# Reloj generado 1:1 sobre el pin de salida para acotar el clock-forwarding.
create_generated_clock -name VGA_CLK \
    -source [get_ports CLOCK_50] \
    [get_ports VGA_CLK]

derive_clock_uncertainty
```

- [ ] **Step 2: Sanity check the references**

Run: `grep -n "u_clkdiv\|VGA_CLK25\|divide_by" segmented_cpu/segmented.sdc`
Expected: no matches (all stale references removed).

- [ ] **Step 3: Commit**

```bash
cd /home/santiago/projects/uni/Computers_Arquitecture/rv32i-cpu
git add segmented_cpu/segmented.sdc
git commit -m "chore(segmented): SDC for single 50MHz pixel clock (VGA_CLK = CLOCK_50)"
```

---

## Task 4: Rewrite vga_debug (100x37 layout, byte color, program column)

**Files:**
- Modify: `segmented_cpu/vga_debug.v`

This is the bulk of the work. The module stays combinational. Grid is 100x37:
`col = x[10:3]` (0..99), `row = y[10:4]` (0..36), glyph `x[2:0]`/`y[3:0]`.

Left region = `col < 80`. Program column = `col >= 80`.

- [ ] **Step 1: Replace the entire file**

```verilog
// =============================================================================
// vga_debug.v - Vista de depuracion del pipeline de 5 etapas (800x600@72).
// Grilla de 100x37 caracteres (fuente 8x16, font128.hex). Combinacional.
//
//   IZQUIERDA (col 0-79): etapas con nombres completos, bus de control,
//     unidad de salto/branch, riesgos, 32 registros, 32 palabras de memoria
//     (mostradas como 4 bytes little-endian con color por byte).
//   DERECHA  (col 80-99): el programa como columna; se desplaza alrededor del
//     PC de fetch, resalta la instruccion actual y etiqueta cada linea con las
//     etapas que la contienen (F D E M W).
// =============================================================================
module vga_debug (
    input         video_on,
    input  [10:0] x, y,

    // ---- FETCH ----
    input  [31:0] fetch_pc, fetch_instr, fetch_next_pc,
    input         fetch_ebreak,
    // ---- DECODE ----
    input  [31:0] decode_pc, decode_instr, decode_imm,
    // ---- EXECUTE ----
    input  [31:0] exec_instr, exec_alu_a, exec_alu_b, exec_alu_result,
    input         exec_alu_zero,
    // ---- MEMORY ----
    input  [31:0] mem_instr, mem_addr, mem_store_data, mem_read_data,
    // ---- WRITEBACK ----
    input  [31:0] wb_instr, wb_data,
    input  [4:0]  wb_rd,
    input         wb_reg_write,

    // ---- bus de control (instruccion en EXECUTE / ID-EX) ----
    input         ctrl_reg_write, ctrl_alu_src, ctrl_alu_a_src, ctrl_alu_a_zero,
    input         ctrl_mem_read, ctrl_mem_write, ctrl_mem_to_reg,
    input         ctrl_branch, ctrl_jal, ctrl_jalr,
    input  [1:0]  ctrl_alu_op,
    // ---- unidad de salto / branch ----
    input         branch_condition, branch_taken, pc_src,
    input  [31:0] branch_target,
    input  [3:0]  alu_control,
    // ---- riesgos / forwarding / halt ----
    input         stall, flush,
    input  [1:0]  forward_a, forward_b,
    input         valid_decode, valid_exec, valid_mem, valid_wb,
    input         halted,

    // ---- PCs de etapa para las etiquetas de la columna de programa ----
    input  [31:0] exec_pc_tag,    // id_ex_pc
    input  [31:0] mem_pc4_tag,    // ex_mem_pc_plus_4
    input  [31:0] wb_pc4_tag,     // mem_wb_pc_plus_4

    // ---- puertos de depuracion ----
    output [4:0]  reg_debug_addr,
    input  [31:0] reg_debug_data,
    output [4:0]  mem_debug_addr,
    input  [31:0] mem_debug_data,
    output [31:0] instr_debug_addr,
    input  [31:0] instr_debug_data,

    output reg [7:0] vga_r, vga_g, vga_b
);

    localparam [6:0] SP = 7'h20;
    localparam [7:0] PCOL = 8'd80;   // primera columna de la zona de programa

    reg [7:0] font_rom [0:2047];
    initial $readmemh("font128.hex", font_rom);

    wire [7:0] col       = x[10:3];
    wire [2:0] glyph_col = x[2:0];
    wire [6:0] row       = y[10:4];
    wire [3:0] glyph_row = y[3:0];

    // ---------------- funciones auxiliares ----------------
    function [6:0] hn;
        input [3:0] n;
        begin
            if (n < 4'd10) hn = 7'h30 + {3'b0, n};
            else           hn = 7'h37 + {3'b0, n};
        end
    endfunction

    function [6:0] bit_ch;
        input b;
        bit_ch = b ? 7'h31 : 7'h30;
    endfunction

    function [6:0] dec_tens;
        input [4:0] n;
        begin
            if      (n >= 30) dec_tens = 7'h33;
            else if (n >= 20) dec_tens = 7'h32;
            else if (n >= 10) dec_tens = 7'h31;
            else              dec_tens = 7'h30;
        end
    endfunction

    function [6:0] dec_ones;
        input [4:0] n;
        reg [4:0] v;
        begin
            if      (n >= 30) v = n - 5'd30;
            else if (n >= 20) v = n - 5'd20;
            else if (n >= 10) v = n - 5'd10;
            else              v = n;
            dec_ones = 7'h30 + {2'b0, v};
        end
    endfunction

    // 8 digitos hex de un valor de 32 bits a partir de la columna 'base'
    function [6:0] hx;
        input [31:0] val;
        input [7:0]  base;
        input [7:0]  c;
        reg   [2:0]  k;
        begin
            hx = SP;
            if (c >= base && c <= base + 8'd7) begin
                k  = c - base;
                hx = hn(val[(7 - k) * 4 +: 4]);
            end
        end
    endfunction

    // caracter de una etiqueta de texto colocada en la columna 'base'
    function [6:0] lbl;
        input [7:0]   c;
        input [7:0]   base;
        input [255:0] text;
        input [5:0]   len;
        reg   [5:0]   i;
        begin
            lbl = SP;
            if (c >= base && c < base + len) begin
                i   = c - base;
                lbl = text[(len - 1 - i) * 8 +: 8];
            end
        end
    endfunction

    // ---------------- zona de programa (columna derecha) ----------
    localparam [6:0]  PROG_FIRST = 7'd1;
    localparam [6:0]  PROG_LAST  = 7'd36;
    localparam [31:0] PROG_K     = 32'd18;   // offset de centrado

    wire [31:0] pc_word        = fetch_pc >> 2;
    wire [31:0] prog_line      = {25'b0, row} - PROG_FIRST;
    wire [31:0] base_word      = (pc_word >= PROG_K) ? (pc_word - PROG_K) : 32'd0;
    wire [31:0] prog_addr_word = base_word + prog_line;
    wire [31:0] prog_byte_addr = prog_addr_word << 2;
    assign instr_debug_addr    = prog_addr_word;

    wire tag_f = (prog_addr_word == pc_word);
    wire tag_d = valid_decode && (prog_addr_word == (decode_pc   >> 2));
    wire tag_e = valid_exec   && (prog_addr_word == (exec_pc_tag >> 2));
    wire tag_m = valid_mem    && (prog_addr_word == ((mem_pc4_tag >> 2) - 32'd1));
    wire tag_w = valid_wb     && (prog_addr_word == ((wb_pc4_tag  >> 2) - 32'd1));
    wire in_prog = (col >= PCOL) && (row >= PROG_FIRST) && (row <= PROG_LAST);

    // ---------------- paneles de registros / memoria (4 columnas) ----------
    wire        in_reg_rows = (row >= 7'd11) && (row <= 7'd18) && (col < PCOL);
    wire        in_mem_rows = (row >= 7'd21) && (row <= 7'd28) && (col < PCOL);
    wire [4:0]  ridx        = row - 7'd11;
    wire [4:0]  midx        = row - 7'd21;
    wire [1:0]  gcol        = (col < 8'd20) ? 2'd0 :
                              (col < 8'd40) ? 2'd1 :
                              (col < 8'd60) ? 2'd2 : 2'd3;
    wire [7:0]  gbase       = {6'b0, gcol} * 8'd20;
    wire [7:0]  moff        = col - gbase;       // offset dentro de la celda mem

    assign reg_debug_addr = {gcol, 3'b0} + ridx;
    assign mem_debug_addr = {gcol, 3'b0} + midx;

    // campos decodificados de la instruccion en DECODE
    wire [4:0] dc_rs1 = decode_instr[19:15];
    wire [4:0] dc_rs2 = decode_instr[24:20];
    wire [4:0] dc_rd  = decode_instr[11:7];

    // ---------------- caracter de la celda actual ----------
    reg [6:0] ascii;
    reg [6:0] t;

    always @(*) begin
        ascii = SP;
        t     = SP;

        if (col >= PCOL) begin
            // ===================== columna de programa =====================
            if (row == 7'd0) begin
                t = lbl(col, PCOL, "===== PROGRAM =====", 6'd19);
                if (t != SP) ascii = t;
            end else if (in_prog) begin
                case (col - PCOL)
                    8'd0: ascii = tag_f ? "F" : SP;
                    8'd1: ascii = tag_d ? "D" : SP;
                    8'd2: ascii = tag_e ? "E" : SP;
                    8'd3: ascii = tag_m ? "M" : SP;
                    8'd4: ascii = tag_w ? "W" : SP;
                    8'd6: ascii = hn(prog_byte_addr[11:8]);
                    8'd7: ascii = hn(prog_byte_addr[7:4]);
                    8'd8: ascii = hn(prog_byte_addr[3:0]);
                    8'd9: ascii = ":";
                    8'd18: ascii = tag_f ? "<" : SP;
                    default: begin
                        t = hx(instr_debug_data, PCOL + 8'd10, col);
                        if (t != SP) ascii = t;
                    end
                endcase
            end
        end else begin
            // ========================= zona izquierda ======================
            case (row)

            // ---- titulo ----
            7'd0: begin
                t = lbl(col, 8'd0, "===== PIPELINE 5 ETAPAS =====", 6'd29);
                if (t != SP) ascii = t;
            end

            // ---- FETCH ----
            7'd1: begin
                t = lbl(col, 8'd0,  "FETCH", 6'd5);      if (t != SP) ascii = t;
                t = lbl(col, 8'd10, "PC:", 6'd3);        if (t != SP) ascii = t;
                t = hx(fetch_pc, 8'd13, col);            if (t != SP) ascii = t;
                t = lbl(col, 8'd23, "INSTR:", 6'd6);     if (t != SP) ascii = t;
                t = hx(fetch_instr, 8'd29, col);         if (t != SP) ascii = t;
                t = lbl(col, 8'd39, "nextPC:", 6'd7);    if (t != SP) ascii = t;
                t = hx(fetch_next_pc, 8'd46, col);       if (t != SP) ascii = t;
                t = lbl(col, 8'd56, "ebreak:", 6'd7);    if (t != SP) ascii = t;
                if (col == 8'd63) ascii = bit_ch(fetch_ebreak);
            end

            // ---- DECODE ----
            7'd2: begin
                t = lbl(col, 8'd0,  "DECODE", 6'd6);     if (t != SP) ascii = t;
                t = lbl(col, 8'd10, "PC:", 6'd3);        if (t != SP) ascii = t;
                t = hx(decode_pc, 8'd13, col);           if (t != SP) ascii = t;
                t = lbl(col, 8'd23, "INSTR:", 6'd6);     if (t != SP) ascii = t;
                t = hx(decode_instr, 8'd29, col);        if (t != SP) ascii = t;
                t = lbl(col, 8'd39, "rs1:", 6'd4);       if (t != SP) ascii = t;
                if      (col == 8'd43) ascii = dec_tens(dc_rs1);
                else if (col == 8'd44) ascii = dec_ones(dc_rs1);
                t = lbl(col, 8'd47, "rs2:", 6'd4);       if (t != SP) ascii = t;
                if      (col == 8'd51) ascii = dec_tens(dc_rs2);
                else if (col == 8'd52) ascii = dec_ones(dc_rs2);
                t = lbl(col, 8'd55, "rd:", 6'd3);        if (t != SP) ascii = t;
                if      (col == 8'd58) ascii = dec_tens(dc_rd);
                else if (col == 8'd59) ascii = dec_ones(dc_rd);
                t = lbl(col, 8'd62, "imm:", 6'd4);       if (t != SP) ascii = t;
                t = hx(decode_imm, 8'd66, col);          if (t != SP) ascii = t;
            end

            // ---- EXECUTE ----
            7'd3: begin
                t = lbl(col, 8'd0,  "EXECUTE", 6'd7);    if (t != SP) ascii = t;
                t = lbl(col, 8'd10, "INSTR:", 6'd6);     if (t != SP) ascii = t;
                t = hx(exec_instr, 8'd16, col);          if (t != SP) ascii = t;
                t = lbl(col, 8'd26, "A:", 6'd2);         if (t != SP) ascii = t;
                t = hx(exec_alu_a, 8'd28, col);          if (t != SP) ascii = t;
                t = lbl(col, 8'd38, "B:", 6'd2);         if (t != SP) ascii = t;
                t = hx(exec_alu_b, 8'd40, col);          if (t != SP) ascii = t;
                t = lbl(col, 8'd50, "ALU:", 6'd4);       if (t != SP) ascii = t;
                t = hx(exec_alu_result, 8'd54, col);     if (t != SP) ascii = t;
                t = lbl(col, 8'd64, "zero:", 6'd5);      if (t != SP) ascii = t;
                if (col == 8'd69) ascii = bit_ch(exec_alu_zero);
                t = lbl(col, 8'd72, "rd:", 6'd3);        if (t != SP) ascii = t;
                if      (col == 8'd75) ascii = dec_tens(exec_instr[11:7]);
                else if (col == 8'd76) ascii = dec_ones(exec_instr[11:7]);
            end

            // ---- MEMORY ----
            7'd4: begin
                t = lbl(col, 8'd0,  "MEMORY", 6'd6);     if (t != SP) ascii = t;
                t = lbl(col, 8'd10, "INSTR:", 6'd6);     if (t != SP) ascii = t;
                t = hx(mem_instr, 8'd16, col);           if (t != SP) ascii = t;
                t = lbl(col, 8'd26, "addr:", 6'd5);      if (t != SP) ascii = t;
                t = hx(mem_addr, 8'd31, col);            if (t != SP) ascii = t;
                t = lbl(col, 8'd41, "wdata:", 6'd6);     if (t != SP) ascii = t;
                t = hx(mem_store_data, 8'd47, col);      if (t != SP) ascii = t;
                t = lbl(col, 8'd57, "rdata:", 6'd6);     if (t != SP) ascii = t;
                t = hx(mem_read_data, 8'd63, col);       if (t != SP) ascii = t;
                t = lbl(col, 8'd73, "rd:", 6'd3);        if (t != SP) ascii = t;
                if      (col == 8'd76) ascii = dec_tens(mem_instr[11:7]);
                else if (col == 8'd77) ascii = dec_ones(mem_instr[11:7]);
            end

            // ---- WRITEBACK ----
            7'd5: begin
                t = lbl(col, 8'd0,  "WRITEBACK", 6'd9);  if (t != SP) ascii = t;
                t = lbl(col, 8'd10, "INSTR:", 6'd6);     if (t != SP) ascii = t;
                t = hx(wb_instr, 8'd16, col);            if (t != SP) ascii = t;
                t = lbl(col, 8'd26, "data:", 6'd5);      if (t != SP) ascii = t;
                t = hx(wb_data, 8'd31, col);             if (t != SP) ascii = t;
                t = lbl(col, 8'd41, "rd:", 6'd3);        if (t != SP) ascii = t;
                if      (col == 8'd44) ascii = dec_tens(wb_rd);
                else if (col == 8'd45) ascii = dec_ones(wb_rd);
                t = lbl(col, 8'd48, "RegWrite:", 6'd9);  if (t != SP) ascii = t;
                if (col == 8'd57) ascii = bit_ch(wb_reg_write);
            end

            // ---- bus de control ----
            7'd6: begin
                t = lbl(col, 8'd0,  "CTRL", 6'd4);       if (t != SP) ascii = t;
                t = lbl(col, 8'd6,  "regW:", 6'd5);      if (t != SP) ascii = t;
                if (col == 8'd11) ascii = bit_ch(ctrl_reg_write);
                t = lbl(col, 8'd13, "aluSrc:", 6'd7);    if (t != SP) ascii = t;
                if (col == 8'd20) ascii = bit_ch(ctrl_alu_src);
                t = lbl(col, 8'd22, "aSrc:", 6'd5);      if (t != SP) ascii = t;
                if (col == 8'd27) ascii = bit_ch(ctrl_alu_a_src);
                t = lbl(col, 8'd29, "aZero:", 6'd6);     if (t != SP) ascii = t;
                if (col == 8'd35) ascii = bit_ch(ctrl_alu_a_zero);
                t = lbl(col, 8'd37, "memR:", 6'd5);      if (t != SP) ascii = t;
                if (col == 8'd42) ascii = bit_ch(ctrl_mem_read);
                t = lbl(col, 8'd44, "memW:", 6'd5);      if (t != SP) ascii = t;
                if (col == 8'd49) ascii = bit_ch(ctrl_mem_write);
                t = lbl(col, 8'd51, "m2reg:", 6'd6);     if (t != SP) ascii = t;
                if (col == 8'd57) ascii = bit_ch(ctrl_mem_to_reg);
                t = lbl(col, 8'd59, "br:", 6'd3);        if (t != SP) ascii = t;
                if (col == 8'd62) ascii = bit_ch(ctrl_branch);
                t = lbl(col, 8'd64, "jal:", 6'd4);       if (t != SP) ascii = t;
                if (col == 8'd68) ascii = bit_ch(ctrl_jal);
                t = lbl(col, 8'd70, "jalr:", 6'd5);      if (t != SP) ascii = t;
                if (col == 8'd75) ascii = bit_ch(ctrl_jalr);
            end

            // ---- unidad de salto / branch ----
            7'd7: begin
                t = lbl(col, 8'd0,  "JUMP", 6'd4);       if (t != SP) ascii = t;
                t = lbl(col, 8'd6,  "brCond:", 6'd7);    if (t != SP) ascii = t;
                if (col == 8'd13) ascii = bit_ch(branch_condition);
                t = lbl(col, 8'd15, "brTaken:", 6'd8);   if (t != SP) ascii = t;
                if (col == 8'd23) ascii = bit_ch(branch_taken);
                t = lbl(col, 8'd25, "pcSrc:", 6'd6);     if (t != SP) ascii = t;
                if (col == 8'd31) ascii = bit_ch(pc_src);
                t = lbl(col, 8'd33, "target:", 6'd7);    if (t != SP) ascii = t;
                t = hx(branch_target, 8'd40, col);       if (t != SP) ascii = t;
                t = lbl(col, 8'd50, "aluOp:", 6'd6);     if (t != SP) ascii = t;
                if      (col == 8'd56) ascii = bit_ch(ctrl_alu_op[1]);
                else if (col == 8'd57) ascii = bit_ch(ctrl_alu_op[0]);
                t = lbl(col, 8'd60, "aluCtrl:", 6'd8);   if (t != SP) ascii = t;
                if (col == 8'd68) ascii = hn(alu_control);
            end

            // ---- riesgos / forwarding / valid / halt ----
            7'd8: begin
                t = lbl(col, 8'd0,  "HAZRD", 6'd5);      if (t != SP) ascii = t;
                t = lbl(col, 8'd6,  "stall:", 6'd6);     if (t != SP) ascii = t;
                if (col == 8'd12) ascii = bit_ch(stall);
                t = lbl(col, 8'd14, "flush:", 6'd6);     if (t != SP) ascii = t;
                if (col == 8'd20) ascii = bit_ch(flush);
                t = lbl(col, 8'd22, "fwdA:", 6'd5);      if (t != SP) ascii = t;
                if (col == 8'd27) ascii = hn({2'b0, forward_a});
                t = lbl(col, 8'd29, "fwdB:", 6'd5);      if (t != SP) ascii = t;
                if (col == 8'd34) ascii = hn({2'b0, forward_b});
                t = lbl(col, 8'd37, "valid", 6'd5);      if (t != SP) ascii = t;
                t = lbl(col, 8'd43, "D:", 6'd2);         if (t != SP) ascii = t;
                if (col == 8'd45) ascii = bit_ch(valid_decode);
                t = lbl(col, 8'd47, "E:", 6'd2);         if (t != SP) ascii = t;
                if (col == 8'd49) ascii = bit_ch(valid_exec);
                t = lbl(col, 8'd51, "M:", 6'd2);         if (t != SP) ascii = t;
                if (col == 8'd53) ascii = bit_ch(valid_mem);
                t = lbl(col, 8'd55, "W:", 6'd2);         if (t != SP) ascii = t;
                if (col == 8'd57) ascii = bit_ch(valid_wb);
                t = lbl(col, 8'd64, "HALT:", 6'd5);      if (t != SP) ascii = t;
                if (col == 8'd69) ascii = bit_ch(halted);
            end

            // ---- encabezado registros ----
            7'd10: begin
                t = lbl(col, 8'd0, "===== REGISTERS =====", 6'd21);
                if (t != SP) ascii = t;
            end

            // ---- encabezado memoria ----
            7'd20: begin
                t = lbl(col, 8'd0, "===== DATA MEMORY (bytes) =====", 6'd31);
                if (t != SP) ascii = t;
            end

            // ---- registros (11-18) y memoria (21-28), 4 columnas ----
            default: begin
                if (in_reg_rows) begin
                    if      (col == gbase)        ascii = "x";
                    else if (col == gbase + 8'd1) ascii = dec_tens(reg_debug_addr);
                    else if (col == gbase + 8'd2) ascii = dec_ones(reg_debug_addr);
                    else if (col == gbase + 8'd3) ascii = "=";
                    else begin
                        t = hx(reg_debug_data, gbase + 8'd4, col);
                        if (t != SP) ascii = t;
                    end
                end else if (in_mem_rows) begin
                    if      (col == gbase)        ascii = "m";
                    else if (col == gbase + 8'd1) ascii = dec_tens(mem_debug_addr);
                    else if (col == gbase + 8'd2) ascii = dec_ones(mem_debug_addr);
                    else if (col == gbase + 8'd3) ascii = "=";
                    // bytes little-endian: B0=[7:0] B1=[15:8] B2=[23:16] B3=[31:24]
                    else if (moff == 8'd4)  ascii = hn(mem_debug_data[7:4]);
                    else if (moff == 8'd5)  ascii = hn(mem_debug_data[3:0]);
                    else if (moff == 8'd7)  ascii = hn(mem_debug_data[15:12]);
                    else if (moff == 8'd8)  ascii = hn(mem_debug_data[11:8]);
                    else if (moff == 8'd10) ascii = hn(mem_debug_data[23:20]);
                    else if (moff == 8'd11) ascii = hn(mem_debug_data[19:16]);
                    else if (moff == 8'd13) ascii = hn(mem_debug_data[31:28]);
                    else if (moff == 8'd14) ascii = hn(mem_debug_data[27:24]);
                end
            end

            endcase
        end
    end

    // ---------------- pixel y color ----------------
    wire [7:0] font_byte = font_rom[{ascii[6:0], glyph_row}];
    wire       pixel     = font_byte[7 - glyph_col];

    // color base por region
    reg [7:0] fr, fg, fb;
    always @(*) begin
        if (col >= PCOL) begin
            // columna de programa: linea actual en amarillo, etiquetas en cyan,
            // resto blanco. Encabezado en verde.
            if (row == 7'd0)            {fr, fg, fb} = {8'h00, 8'hFF, 8'h00};
            else if (tag_f)             {fr, fg, fb} = {8'hFF, 8'hFF, 8'h00};
            else if ((col - PCOL) < 8'd5) {fr, fg, fb} = {8'h00, 8'hFF, 8'hFF};
            else                        {fr, fg, fb} = {8'hFF, 8'hFF, 8'hFF};
        end else if (row == 7'd0)       {fr, fg, fb} = {8'hFF, 8'hFF, 8'h00}; // amarillo
        else if (row >= 7'd1 && row <= 7'd5) {fr, fg, fb} = {8'hFF, 8'hFF, 8'hFF};
        else if (row == 7'd6)           {fr, fg, fb} = {8'h00, 8'hFF, 8'hFF}; // cyan
        else if (row == 7'd7)           {fr, fg, fb} = {8'hFF, 8'h00, 8'hFF}; // magenta
        else if (row == 7'd8)           {fr, fg, fb} = {8'h00, 8'hFF, 8'hFF}; // cyan
        else if (row == 7'd10 || row == 7'd20) {fr, fg, fb} = {8'h00, 8'hFF, 8'h00};
        else if (in_mem_rows) begin
            // color por byte: B0 rojo, B1 verde, B2 cyan, B3 amarillo; prefijo blanco
            if      (moff == 8'd4  || moff == 8'd5)  {fr, fg, fb} = {8'hFF, 8'h40, 8'h40};
            else if (moff == 8'd7  || moff == 8'd8)  {fr, fg, fb} = {8'h40, 8'hFF, 8'h40};
            else if (moff == 8'd10 || moff == 8'd11) {fr, fg, fb} = {8'h40, 8'hFF, 8'hFF};
            else if (moff == 8'd13 || moff == 8'd14) {fr, fg, fb} = {8'hFF, 8'hFF, 8'h40};
            else                                     {fr, fg, fb} = {8'hFF, 8'hFF, 8'hFF};
        end else                        {fr, fg, fb} = {8'hFF, 8'hFF, 8'hFF};
    end

    // HALT en rojo cuando esta detenido (fila 8, col 69)
    wire halt_cell = (row == 7'd8) && (col == 8'd69);
    wire [7:0] pr  = (halt_cell && halted) ? 8'hFF : fr;
    wire [7:0] pg  = (halt_cell && halted) ? 8'h00 : fg;
    wire [7:0] pb  = (halt_cell && halted) ? 8'h00 : fb;

    always @(*) begin
        if (~video_on)
            {vga_r, vga_g, vga_b} = 24'h0;
        else if (pixel)
            {vga_r, vga_g, vga_b} = {pr, pg, pb};
        else
            {vga_r, vga_g, vga_b} = 24'h0;
    end

endmodule
```

- [ ] **Step 2: Compile-check the module against its dependency**

Run: `cd segmented_cpu/test && iverilog -o /tmp/vgad.vvp ../vga_debug.v`
Expected: no errors. (The `font128.hex` `$readmemh` warning at runtime only; compile is clean.)

- [ ] **Step 3: Commit**

```bash
cd /home/santiago/projects/uni/Computers_Arquitecture/rv32i-cpu
git add segmented_cpu/vga_debug.v
git commit -m "feat(segmented): rewrite vga_debug for 100x37 (full signals, byte color, program column)"
```

---

## Task 5: Wire the new signals in top.v

**Files:**
- Modify: `segmented_cpu/top.v`

- [ ] **Step 1: Widen the VGA coordinate wires**

Find (around line 356):

```verilog
wire [9:0] vga_x, vga_y;
wire       vga_video_on;
```

Replace with:

```verilog
wire [10:0] vga_x, vga_y;
wire        vga_video_on;
// puerto de depuracion de la memoria de instrucciones (columna de programa)
wire [31:0] vga_instr_debug_addr, vga_instr_debug_data;
```

- [ ] **Step 2: Add the instruction-memory debug port**

Find (line 147):

```verilog
instruction_memory u_instruction_memory (.addr(pc_out), .instr(if_instruction));
```

Replace with:

```verilog
instruction_memory u_instruction_memory (
    .addr(pc_out), .instr(if_instruction),
    .debug_addr(vga_instr_debug_addr), .debug_instr(vga_instr_debug_data)
);
```

- [ ] **Step 3: Replace the vga_debug instantiation**

Replace the whole `vga_debug u_vga_debug ( ... );` block (lines 365-385) with:

```verilog
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
    .reg_debug_addr(vga_reg_debug_addr), .reg_debug_data(vga_reg_debug_data),
    .mem_debug_addr(vga_mem_debug_addr), .mem_debug_data(vga_mem_debug_data),
    .instr_debug_addr(vga_instr_debug_addr), .instr_debug_data(vga_instr_debug_data),
    .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B)
);
```

- [ ] **Step 4: Compile-check the full top via iverilog**

Run:
```bash
cd segmented_cpu/test && make test_top 2>&1 | tail -20
```
Expected: compiles and runs; `test_top` prints its existing PASS output (no port/width errors). If you see "port ... not found" or width-mismatch errors, fix the offending connection.

- [ ] **Step 5: Commit**

```bash
cd /home/santiago/projects/uni/Computers_Arquitecture/rv32i-cpu
git add segmented_cpu/top.v
git commit -m "feat(segmented): wire all debug signals + instr-mem debug port into vga_debug"
```

---

## Task 6: Full simulation regression

**Files:** none (verification only)

- [ ] **Step 1: Run the full suite**

Run:
```bash
cd segmented_cpu/test && make all 2>&1 | tail -30
```
Expected: all 10 unit tests + `test_top` + `test_final_test` report PASS. `final_test` golden: ends `halted` with `x10 == 0`.

- [ ] **Step 2: Run the pipeline + program tests**

Run:
```bash
cd segmented_cpu/test && make programs 2>&1 | tail -30
```
Expected: `test_pipe_smoke/forward/hazard/lui` and the assembler programs all PASS (`x10 == 0`).

- [ ] **Step 3: Restore the font symlink if Make changed it**

Run: `cd /home/santiago/projects/uni/Computers_Arquitecture/rv32i-cpu && git status --short segmented_cpu/test/font128.hex`
If it shows as modified (the `make` target relinks it), restore: `git checkout -- segmented_cpu/test/font128.hex`

- [ ] **Step 4: Confirm the monocycle is untouched**

Run: `cd /home/santiago/projects/uni/Computers_Arquitecture/rv32i-cpu && git status --short monocicle_cpu/`
Expected: no changes under `monocicle_cpu/`.

---

## Task 7: Quartus compile + on-board check (DE1-SoC, manual)

**Files:** none (hardware verification, performed by the user)

- [ ] **Step 1: Full Quartus compilation**

Open `segmented_cpu/segmented.qpf` in Quartus and run a full compile.
Expected: 0 errors; bitstream generated. The SDC now reports two relationships
on a single 50 MHz domain (CLOCK_50 and the VGA_CLK generated clock).

- [ ] **Step 2: Check timing at 50 MHz**

In the Timing Analyzer, confirm setup slack is positive for the 20 ns (50 MHz)
clock in the slow corner.
**If setup fails** (the combinational render path is now larger): register the
render inside `vga_debug` - add `always @(posedge clk) ascii_q <= ascii;` and
use `ascii_q` for the font lookup (pass `clk_50MHz` into `vga_debug`). This adds
a 1-pixel horizontal shift, harmless. Re-run timing.

- [ ] **Step 3: Program the board and verify the display**

Program the DE1-SoC. With `SW[0]=0` (free run): expect the 100x37 layout, the
program column on the right with the `<` highlight tracking the fetched
instruction and `F/D/E/M/W` tags moving down as instructions flow, data memory
shown as colored bytes, and `LEDR[9]` lit when halted.
**If the monitor rejects 800x600@72:** revert the resolution by restoring the
640x480 `vga_controller`/`segmented.sdc` from git and re-fit the 80x30 layout
(out of scope for this plan; flag back for a follow-up).

- [ ] **Step 4: Final commit (if any timing fix was applied)**

```bash
cd /home/santiago/projects/uni/Computers_Arquitecture/rv32i-cpu
git add segmented_cpu/vga_debug.v segmented_cpu/top.v
git commit -m "fix(segmented): register vga_debug render to meet 50MHz timing"
```

---

## Self-review notes

- **Spec coverage:** resolution change (Task 2/3), full names + new signals
  (Task 4 left rows + Task 5 wiring), byte+color data memory (Task 4 mem rows +
  color block), program column scroll/highlight (Task 4 program branch),
  stage-occupancy tags F/D/E/M/W (Task 4 tag wires), instr-mem debug port
  (Task 1). All covered.
- **Type/name consistency:** `vga_debug` port names match the `top.v`
  instantiation in Task 5 one-for-one; `instr_debug_addr/instr_debug_data`
  match Task 1's `debug_addr/debug_instr` (note: top wires
  `vga_instr_debug_addr/data` bridge them). `x`,`y` are `[10:0]` in
  vga_controller (Task 2), top wires (Task 5 Step 1), and vga_debug (Task 4).
- **No placeholders:** every code step shows the full code.
- **Watch-item:** `prog_addr_word` can exceed the program size; `instruction_memory`
  masks with `debug_addr[9:0]` so reads stay in-array (shows zero-filled words,
  which render as `00000000` - acceptable).
```
