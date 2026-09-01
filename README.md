# RV32I CPU

Two RISC-V RV32I processors written from scratch in Verilog, plus the assembler that
feeds them. Both run on a Terasic DE1-SoC (Cyclone V, 5CSEMA5F31C6) and both are
simulated by their own testbenches before they ever touch the board.

- **`monocicle_cpu/`** - single-cycle implementation. One instruction per clock, no
  pipeline, no hazards. The reference the pipelined version is checked against.
- **`segmented_cpu/`** - 5-stage pipeline (IF, ID, EX, MEM, WB) with a forwarding unit
  and a hazard detection unit, so back-to-back dependent instructions and load-use
  stalls behave correctly instead of silently reading stale registers.
- **`assembler/`** - a 707-line Python assembler that takes `.asm` and emits `.hex` and
  `.mif` for the instruction memory.

## What it supports

The full RV32I base integer set:

```
add addi sub and andi or ori xor xori
sll slli srl srli sra srai slt slti sltu sltiu
lw lh lhu lb lbu  sw sh sb
beq bne blt bge bltu bgeu  jal jalr
lui auipc  ecall ebreak
```

plus the usual pseudo-instructions (`li`, `mv`, `nop`, `j`).

## Verification

28 testbenches across the two designs. The pipelined CPU has dedicated benches for the
parts that are actually hard to get right:

| Testbench | What it pins down |
|---|---|
| `pipe_forward_tb.v` | EX/MEM and MEM/WB forwarding paths |
| `pipe_hazard_tb.v` | load-use stall and pipeline flush |
| `pipe_smoke_tb.v` | end-to-end instruction flow |
| `trace_tb.v` | cycle-by-cycle register and memory trace |
| `top_final_test_tb.v` | full program against expected final state |

The rest cover each module in isolation: ALU, ALU control, control unit, immediate
generator, register file, data memory, PC, adder, mux.

Test programs live in `assembler/` as matched `.c` / `.asm` / `.hex` triples
(`test_arith`, `test_bits`, `test_loops`, `test_memory`, `subword_test`,
`pipeline-demo`, `final_test`), so the intended behaviour of each program is readable
in C next to the machine code it assembles to.

## On the board

Both designs drive the DE1-SoC seven-segment displays through `hex_display.v` and a VGA
debug view through `vga_controller.v` / `vga_debug.v`, so register and memory state is
visible while a program runs. `clock_div.v` slows the clock enough to watch execution
step by step. Build with `build.tcl` in either CPU directory (Quartus).

## Layout

```
assembler/          Python assembler, test programs (.c/.asm/.hex/.mif)
monocicle_cpu/      single-cycle CPU, testbenches, Quartus project
segmented_cpu/      pipelined CPU, testbenches, Quartus project
Diagrams/           Digital (.dig) schematics per datapath block
docs/               design notes, assembler reference, DE1-SoC pinout, debug traces
```

## Docs

- [Assembler reference](docs/01-assembler.md)
- [DE1-SoC controls: switches, buttons, displays](docs/de1-soc.md)
- [Single-cycle CPU, explained](docs/monocicle-cpu-explicado.md) (Spanish)
- [Pipelined CPU, explained](docs/segmented-cpu-explicado.md) (Spanish)
- [Debug session walkthrough](docs/monocicle-debug-session.md) and
  [instruction trace](docs/monocicle-trace-program-adder.md)

Built for the Computer Architecture course at Universidad Tecnologica de Pereira.
