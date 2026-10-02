# VGA debug display redesign (segmented_cpu)

Date: 2026-05-26
Project: rv32i-cpu / segmented_cpu (5-stage pipeline, DE1-SoC)

## Goal

Rebuild the VGA debug view so it shows, on one screen:
- Every pipeline-relevant signal with non-abbreviated names (the ones the user
  forgets: FETCH/DECODE/EXECUTE/MEMORY/WRITEBACK, INSTR, RegWrite, valid bits,
  forwarding, jump and branch unit signals, control bus).
- The 32 registers and 32 data-memory words.
- Data memory shown as 4 colored bytes per word (little-endian), so the byte
  layout of each word is visually obvious.
- The whole program as a scrolling vertical column on the right edge, with the
  instruction currently being fetched highlighted; the column scrolls so the
  highlighted line stays centered as the PC moves.

## Resolution decision

Move from 640x480@60 (25 MHz pixel clock, 80x30 chars) to **800x600@72Hz**.

Rationale: VESA 800x600@72 uses a **50 MHz dot clock exactly**, so the pixel
logic runs directly off `CLOCK_50` - no PLL, no `clock_div` (simpler than the
current /2 divider). Character grid becomes **100x37** (8x16 font), giving a
wide left region for signals and a tall right column for the program.

### 800x600@72 timing (VESA)
- Pixel clock: 50.000 MHz (= CLOCK_50, drive VGA_CLK from it directly).
- Horizontal: active 800, front porch 56, sync 120, back porch 64 -> total 1040.
- Vertical: active 600, front porch 37, sync 6, back porch 23 -> total 666.
- Sync polarity: H positive, V positive (active-high).
- Counters and `x`,`y` must widen to **[10:0]** (htotal 1040 > 1023).

### Char grid math (100x37)
- `col = x[10:3]` (0..99), `glyph_col = x[2:0]`
- `row = y[9:4]` (0..36), `glyph_row = y[3:0]`
- Font ROM unchanged: `font128.hex`, 8x16, 128 glyphs.

## Screen layout (100 cols x 37 rows)

Left = cols 0..79 (signals + regs + data mem). Right = cols 80..99 (program).

```
LEFT (cols 0-79)                                              | RIGHT (cols 80-99)
row 0  ====== PIPELINE 5 ETAPAS ======                        | ===== PROGRAM =====
row 1  FETCH     PC INSTR nextPC ebreak                       | addr:instr
row 2  DECODE    PC INSTR rs1 rs2 rd imm                      | addr:instr
row 3  EXECUTE   INSTR A B ALU zero rd                        | addr:instr  < PC (highlight)
row 4  MEMORY    INSTR addr wdata rdata rd                    | addr:instr
row 5  WRITEBACK INSTR data rd RegWrite                       | addr:instr
row 6  CTRL  regW aluSrc aSrc aZero memR memW m2reg br jal jalr| ...
row 7  JUMP  brCond brTaken pcSrc target aluOp aluCtrl         | ...
row 8  HAZRD stall flush fwdA fwdB  valid F D E M W  HALT      | ... (scrolls so the
row 9  (blank)                                                | PC line stays
row 10 ====== REGISTERS ======                                | centered; whole
row 11-18  32 registers, 4 cols x 8 rows (x00..x31)           | program visible,
row 19 (blank)                                                | ~35 instr at once)
row 20 ====== DATA MEMORY (little-endian bytes) ======        | ...
row 21-28  32 words, 4 cols x 8 rows, each byte colored        | ...
row 29-36  (free / reserved)                                  | ...
```

### Naming map
| Old | New |
|---|---|
| IF / ID / EX / MEM / WB | FETCH / DECODE / EXECUTE / MEMORY / WRITEBACK |
| IR | INSTR |
| WE | RegWrite |
| FWDA / FWDB | fwdA / fwdB |
| rs1 rs2 rd ALU PC imm | kept (user knows these) |

### Per-stage signals shown
- FETCH: `pc_out`, `if_instruction`, `pc_next`, `ebreak_in_fetch`.
- DECODE: `if_id_pc`, `if_id_instruction`, `rs1`, `rs2`, `rd`, `imm`.
- EXECUTE: `id_ex_instruction`, `alu_operand_a`, `alu_operand_b`, `alu_result`,
  `alu_zero`, `rd`.
- MEMORY: `ex_mem_instruction`, `ex_mem_alu_result` (addr), `ex_mem_store_data`,
  `mem_read_data`, `rd`.
- WRITEBACK: `mem_wb_instruction`, `write_back_data`, `write_back_rd`,
  `write_back_enable` (RegWrite).
- CTRL row (ID/EX control bus): `reg_write, alu_src, alu_a_src, alu_a_zero,
  mem_read, mem_write, mem_to_reg, branch, jal, jalr`.
- JUMP row: `branch_condition, branch_taken, pc_src (ex_mem_pc_src),
  ex_mem_branch_target, alu_op, alu_control`.
- HAZRD row: `load_use_stall, flush, forward_a, forward_b`, per-stage valid
  (`if_id_valid, id_ex_valid, ex_mem_valid, mem_wb_valid`), `halted`.

### rd correctness
Each stage shows the `rd` of the instruction in that stage (correct, not a
duplicate bug). `rd` is only lit when that stage actually writes (gate by the
stage's reg_write where available) so stores/branches don't show a misleading
destination.

### Data memory bytes + color
Each word rendered as 4 byte pairs: `mNN=B0 B1 B2 B3` where the word =
{B3,B2,B1,B0} (little-endian, byte 0 = bits [7:0]). Colors: B0 red, B1 green,
B2 cyan, B3 yellow. Cell fits in a 4-column layout (`mNN=00 00 00 00` ~ 15 chars
per column, 4 cols across 80 left-cols).

### Program column (right, cols 80-99)
- One instruction per row. Format: `TAG AAA:IIIIIIII` (stage tag, addr = word*4
  in hex, instruction word). Current-PC line highlighted (inverse/yellow + `<`).
- Window scrolls with PC: `pc_word = pc_out[31:2]`. Center offset `K` = half the
  visible program rows. `base_word = (pc_word > K) ? pc_word - K : 0` (clamp at
  0). For program row `r`, `addr_word = base_word + (r - PROG_FIRST_ROW)`.
- Highlight row where `addr_word == pc_word`.
- One combinational debug read port on `instruction_memory` supplies the word
  for the row currently being drawn (addr is stable across a character row, same
  pattern as the register/data-memory debug ports).

### Stage-occupancy tags (program column)
Each program row shows which pipeline stage currently holds that address, so the
column doubles as a live pipeline-occupancy diagram. `TAG` is a short field
(up to 5 chars) showing the matching stage letters in order F D E M W:
- F: `if_id_valid?`/fetch - `addr_word == pc_out[31:2]` (always the fetch line).
- D: `if_id_valid  && addr_word == if_id_pc[31:2]`.
- E: `id_ex_valid  && addr_word == id_ex_pc[31:2]`.
- M: `ex_mem_valid && addr_word == ex_mem_pc_plus_4[31:2] - 1` (MEM/WB carry
  pc_plus_4, so pc_word = pc_plus_4_word - 1).
- W: `mem_wb_valid && addr_word == mem_wb_pc_plus_4[31:2] - 1`.
Letters are only shown for valid stages. Multiple letters may appear on one row
(e.g. a stall holds the same address in two stages). The fetch line keeps the
`<` highlight regardless of tags.

## Module changes (no new files)

1. **vga_controller.v** - rewrite timing to VESA 800x600@72, count at CLOCK_50
   directly, widen `x`,`y` to [10:0], set H/V sync active-high, `assign clk =
   clk_50MHz` (VGA_CLK pin). Remove the `clock_div` instance.
2. **clock_div.v** - no longer used; remove its instance and its `VERILOG_FILE`
   line from the qsf (file may remain on disk, unused).
3. **vga_debug.v** - full rewrite for 100x37, the layout above, new signal
   inputs, byte coloring, the program-column window + highlight, `x`,`y` [10:0],
   add `instr_debug_addr`/`instr_debug_data` ports.
4. **instruction_memory.v** - add combinational debug read port:
   `input [31:0] debug_addr` (word index), `output [31:0] debug_instr =
   mem[debug_addr]`.
5. **top.v** - wire ~15 new signals into `u_vga_debug`; wire the instruction-
   memory debug port; widen the `vga_x`,`vga_y` wires to [10:0]; VGA_CLK now
   sourced from CLOCK_50 via vga_controller.
6. **segmented.sdc** - drop the divide-by-2 `VGA_CLK25` generated clock. VGA_CLK
   is now CLOCK_50 (1:1). Keep `derive_clock_uncertainty`; update clock groups.
7. **segmented.qsf** - remove the `clock_div.v` VERILOG_FILE line only. **Pin
   assignments unchanged** -> DE1-SoC bring-up unaffected.

`font128.hex` unchanged. No new files added.

## Invariants preserved
- `top` module name and port list unchanged (board pins / qsf valid).
- CPU datapath unchanged - only the debug view and VGA timing change.
- `final_test` still ends `halted, x10=0` (architectural result identical).
- Simulation suite still builds `top` and passes.

## Risks / watch-items
- **Timing at 50 MHz:** the new render path is larger and combinational. If it
  fails setup at 20 ns, register the pipeline in two stages inside vga_debug
  (latch `ascii` then `pixel`) - a 1-2 pixel horizontal shift, harmless.
- **Monitor compatibility:** 800x600@72 is widely supported but if the lab
  monitor refuses it, fall back to 640x480 layout. Keep the timing params in
  one place for an easy switch.
- **x/y width:** every place using `x`/`y` (vga_controller outputs, vga_debug
  inputs, top wires) must widen to [10:0]; a missed [9:0] truncates at 1023.
- **Program-column arithmetic:** clamp `base_word` at 0 to avoid underflow near
  PC=0; bound `addr_word` to MEM_DEPTH so out-of-range rows render blank.

## Verification
- `cd segmented_cpu/test && make all` plus `make test_pipe_*` - golden:
  `final_test -> halted, x10=0`.
- Confirm `monocicle_cpu` untouched.
- Quartus compile: 0 errors, timing meets at 50 MHz for both the CPU and the VGA
  path; confirm 800x600@72 output on the board.
