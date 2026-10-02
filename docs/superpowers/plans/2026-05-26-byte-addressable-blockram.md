# Byte-addressable memory + sub-word + M10K - Implementation Plan

Branch: `feat/byte-mem-blockram`
Spec: `docs/superpowers/specs/2026-05-26-byte-addressable-blockram-design.md`
Verify each phase with `make all` + `make programs` in `segmented_cpu/test`
(golden: `final_test -> halted, x10=0`). Quartus is compiled manually by the user.
No ad-hoc `iverilog` runs.

Memory stays a word-wide array of 4 byte lanes with per-byte write enables
(= byte storage, 4 bytes concatenated = a word). Little-endian. Sizes unchanged
(data 256 words = 1 KB, instr 1024 words = 4 KB).

---

## Phase A - byte storage + sub-word access (combinational read, no timing change)

Touches `data_memory.v` and `top.v`. `control_unit.v` needs NO change (size is
decoded from `funct3`, which already flows with the instruction). Instruction
memory is untouched in Phase A (a 32-bit word already = 4 concatenated bytes).

### A1. data_memory.v - byte-write-enables
Replace `mem_write`/single write with a 4-bit byte enable and aligned data:

```verilog
module data_memory #(parameter WORDS = 256) (
    input         clk,
    input         mem_read,
    input  [3:0]  byte_we,        // ya con cpu_enable & valid & mem_write
    input  [31:0] addr,
    input  [31:0] write_data,      // ya alineado al lane destino
    output [31:0] read_data,
    input  [$clog2(WORDS)-1:0] debug_addr,
    output [31:0] debug_data
);
localparam AW = $clog2(WORDS);
wire [AW-1:0] w = addr[AW+1:2];
reg [31:0] memory [0:WORDS-1];
always @(posedge clk) begin
    if (byte_we[0]) memory[w][7:0]   <= write_data[7:0];
    if (byte_we[1]) memory[w][15:8]  <= write_data[15:8];
    if (byte_we[2]) memory[w][23:16] <= write_data[23:16];
    if (byte_we[3]) memory[w][31:24] <= write_data[31:24];
end
assign read_data  = mem_read ? memory[w] : 32'b0;
assign debug_data = memory[debug_addr];
endmodule
```
(No `ramstyle` yet - read is still combinational in Phase A. M10K comes in B.)

### A2. top.v - store alignment (MEM stage)
Where `data_memory` is instantiated, replace the `mem_write` connection with
computed byte enables + aligned data:

```verilog
wire [2:0] dm_funct3 = ex_mem_instruction[14:12];
wire [1:0] dm_off    = ex_mem_alu_result[1:0];
wire       dm_store  = cpu_enable & ex_mem_valid & ex_mem_ctrl_mem_write;
reg  [3:0]  dm_be;
reg  [31:0] dm_wdata;
always @(*) begin
    case (dm_funct3)
        3'b000: begin dm_be = 4'b0001 << dm_off;  dm_wdata = ex_mem_store_data[7:0]  << (8*dm_off); end // sb
        3'b001: begin dm_be = 4'b0011 << dm_off;  dm_wdata = ex_mem_store_data[15:0] << (8*dm_off); end // sh
        default:begin dm_be = 4'b1111;            dm_wdata = ex_mem_store_data;                     end // sw
    endcase
end
data_memory #(.WORDS(DATA_WORDS)) u_data_memory (
    .clk(CLOCK_50), .mem_read(ex_mem_ctrl_mem_read),
    .byte_we(dm_store ? dm_be : 4'b0),
    .addr(ex_mem_alu_result), .write_data(dm_wdata),
    .read_data(mem_read_data),
    .debug_addr(vga_mem_debug_addr), .debug_data(vga_mem_debug_data)
);
```

### A3. top.v - load extend (WB stage)
Currently `write_back_value_pre = mem_wb_ctrl_mem_to_reg ? mem_wb_mem_read_data : mem_wb_alu_result;`
Add sub-word select + sign/zero extend (uses `funct3` + `addr[1:0]`, both already
in MEM/WB):

```verilog
wire [2:0]  wb_funct3 = mem_wb_instruction[14:12];
wire [4:0]  wb_sh     = {mem_wb_alu_result[1:0], 3'b0};   // 8*offset
wire [7:0]  wb_byte   = mem_wb_mem_read_data >> wb_sh;
wire [15:0] wb_half   = mem_wb_mem_read_data >> wb_sh;
reg  [31:0] wb_load;
always @(*) begin
    case (wb_funct3)
        3'b000: wb_load = {{24{wb_byte[7]}},  wb_byte};   // lb
        3'b001: wb_load = {{16{wb_half[15]}}, wb_half};   // lh
        3'b100: wb_load = {24'b0, wb_byte};               // lbu
        3'b101: wb_load = {16'b0, wb_half};               // lhu
        default:wb_load = mem_wb_mem_read_data;           // lw
    endcase
end
// replace the load side of write_back_value_pre with wb_load
wire [31:0] write_back_value_pre = mem_wb_ctrl_mem_to_reg ? wb_load : mem_wb_alu_result;
```

### A4. Sub-word test
Check whether `assembler/assembler.py` emits `lb/lh/lbu/lhu/sb/sh`. If yes, write
a tiny asm program that stores bytes/halves and loads them back with both sign
and zero extension and checks the result (sets `x10=0` on success); add a Make
target. If the assembler lacks them, hand-write a `.hex` testbench
(`subword_tb.v` + `subword.hex`).

**Verify A:** `make all` + `make programs` (existing lw/sw must still pass) and
the new sub-word test. Commit.

---

## Phase B - data memory -> M10K (synchronous read)

- `data_memory.v`: tag `(* ramstyle = "M10K" *) reg [31:0] memory [...]`; register
  the read: `reg [31:0] rd_q; always @(posedge clk) if (read_en) rd_q <= memory[w];`
  with `read_en = cpu_enable` (advances with the pipeline). `assign read_data = rd_q;`
  Same for `debug_data` (registered second port).
- `top.v`: the registered read now lands the value in WB directly, so drop the
  `mem_read_data` field from the MEM/WB latch (`pipe_memwb`) and feed the RAM's
  `read_data` straight into the WB load-extend logic. Forwarding (from WB) and the
  load-use stall are unchanged (load value still first available in WB).
- Watch: read-during-write and `cpu_enable` gating so step-mode/halt hold the
  value.

**Verify B:** `make all` + `make programs` + sub-word test. Commit.

---

## Phase C - instruction memory -> M10K (synchronous read)  [highest risk]

- `instruction_memory.v`: byte/word storage with `(* ramstyle="M10K" *)`,
  registered read: address = PC, output registered -> instruction valid one cycle
  later. Keep `$readmemh(program.hex)` init.
- `top.v` IF rework: the registered ROM output becomes the IF/ID instruction, so
  the existing `pipe_ifid` instruction latch is removed (the ROM register replaces
  it) while PC/pc+4 stay latched in step with it. A taken branch now costs one
  extra fetch bubble; extend the flush to cover the added fetch slot.
- The VGA program-column debug read (`instr_debug`) becomes a registered second
  port (fine - address is stable across a character row).

**Verify C:** `make all` + `make programs`; `final_test` still `x10=0` (cycle
counts grow from the extra fetch latency, results identical). Commit.

---

## After ABC
- Update the docs (`segmented-cpu-explicado.md`) for byte addressing, sub-word
  ops, and block RAM.
- Merge `feat/byte-mem-blockram` -> `main` once verified in sim and on the board.
