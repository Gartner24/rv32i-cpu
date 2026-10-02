# Byte-addressable memory + sub-word access + M10K block RAM (segmented_cpu)

Date: 2026-05-26
Project: rv32i-cpu / segmented_cpu (5-stage pipeline, DE1-SoC)

## Goal

Make the memory subsystem standard RV32I:
1. **Byte-addressable, byte-stored memory** - store bytes, concatenate 4 (little
   endian) into a 32-bit word/instruction. (Teacher requirement.)
2. **Sub-word loads/stores** - `lb lh lw lbu lhu` (sign/zero-extended loads) and
   `sb sh sw` (byte/halfword stores). Currently only `lw/sw` work (`funct3`
   ignored). (RV32I standard.)
3. **M10K block RAM** - synchronous read so Quartus infers M10K instead of
   ~16k logic cells. (Teacher requirement.)

RV32I is byte-addressed and little-endian (load-store ISA). Confirmed against the
official spec.

## Decisions (defaults - correct if wrong)

- **Both** instruction and data memory become M10K (sync read).
- Done on a **feature branch** (`feat/byte-mem-blockram`); `main` stays
  demo-ready. Phased; can stop at any phase.
- **Sizes unchanged:** data memory 1 KB (1024 bytes), instruction memory 4 KB
  (1024 words). Program memory must stay ~4 KB - `final_test` is 923
  instructions (~3.7 KB), so 1 KB is impossible.
- **Little-endian** byte order.
- **Verification is simulation-only via `make` targets** in `segmented_cpu/test`
  (no ad-hoc iverilog). Quartus compile is done manually by the user.

## How the pieces fit (the standard FPGA form)

Memory = a **word-wide block RAM split into 4 byte lanes** with **per-byte write
enables**. That *is* "store bytes, concatenate 4 into a word," and it is exactly
what infers a byte-enabled M10K. Tag the array `(* ramstyle = "M10K" *)`.

- **Load:** read the full word; in WB, use `funct3` + `addr[1:0]` to select the
  byte/halfword and sign- or zero-extend. `funct3` and the address are already
  available in WB (`mem_wb_instruction[14:12]`, `mem_wb_alu_result[1:0]`), so no
  new pipeline plumbing for loads.
- **Store:** in MEM, from `funct3` + `addr[1:0]` build a 4-bit byte-write-enable
  mask and align the store data to the right byte lane(s).

### Sub-word semantics
- `lb`  (f3=000): byte  -> sign-extend
- `lh`  (f3=001): half  -> sign-extend
- `lw`  (f3=010): word
- `lbu` (f3=100): byte  -> zero-extend
- `lhu` (f3=101): half  -> zero-extend
- `sb`  (f3=000): write 1 byte ; `sh` (f3=001): 2 bytes ; `sw` (f3=010): 4 bytes
- Misaligned half/word accesses are out of scope (assume aligned, as today).

## The one real risk: synchronous read (+1 cycle)

M10K requires a **registered** read.
- **Data memory:** nearly free. Today the read is combinational in MEM and
  latched into MEM/WB, so the value already arrives in WB. A registered block-RAM
  read also delivers it in WB - we just move the register into the RAM. Load
  extension stays in WB. Forwarding (from WB) and the load-use stall are
  unchanged.
- **Instruction memory:** the disruptive one. A registered fetch makes the
  instruction arrive one cycle after the PC, so IF and the branch/flush logic
  must be reworked so the fetched instruction lines up (taken branches cost one
  extra fetch bubble). Done last and isolated.

## Phased plan

- **Phase A - byte storage + sub-word access (combinational read, NO timing
  change).** Delivers full standard RV32I memory behavior at low risk.
  - `data_memory`: byte-addressable storage (4 byte lanes), per-byte write
    enables for `sb/sh/sw`, returns the full word on read.
  - `instruction_memory`: byte-addressable storage, fetch concatenates 4 bytes
    (still combinational).
  - `top.v`: WB load-align/extend logic (`funct3` + `addr[1:0]`); MEM store
    byte-enable + data alignment. `.hex` files unchanged - split each loaded
    word into bytes at `initial`.
- **Phase B - data memory -> M10K (sync read).** Move the read register into the
  RAM; drop the MEM/WB read-data latch; gate the read register with `cpu_enable`.
  Low risk (timing-equivalent).
- **Phase C - instruction memory -> M10K (sync read).** Registered fetch; rework
  IF + branch/flush so the registered instruction aligns. Highest risk, isolated.

Each phase: verify with `make all` + `make programs` (golden `final_test`
-> `halted, x10=0`) before the next. Add a directed sub-word test program
(`lb/lh/lbu/lhu/sb/sh`) in Phase A.

## Invariants
- `top` port list unchanged (DE1-SoC pins / qsf valid).
- All existing programs still pass (`x10=0`).
- VGA debug panels (registers, data memory paging, program column) keep working;
  the data-memory debug read becomes registered (1-cycle), harmless for display.

## Open question for the user
- Does the teacher require M10K for **both** memories, or is **data memory**
  enough? If data-only, we stop after Phase B and skip the risky fetch rework.
