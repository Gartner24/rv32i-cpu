# VGA Debug Guide - DE1-SoC RV32I CPU

## Controls

| Input | Function |
|-------|----------|
| KEY[0] | **Reset** (active-low). Hold to reset: PC=0, registers=0. Release to run. |
| KEY[1] | **Step** (active-low). In step mode (SW[0]=1): one press = one instruction executed. |
| SW[0] | **Mode**. 0=auto (50 MHz), 1=step-by-step. |

| Output | Meaning |
|--------|---------|
| LEDR[0] | Mode indicator: 1 when SW[0]=1 (step mode). |
| LEDR[9] | Halt: CPU reached ebreak or empty instruction. Registers frozen. |
| LEDR[8:1] | Running: PC[9:2] (instruction index). Halted: x10[7:0] (exit code, 0x00 = success). |
| HEX5-HEX0 | Lower 24 bits of PC in hex: `HEX5[23:20] ... HEX0[3:0]`. |

---

## VGA Screen Layout (640x480, 80x30 chars, 8x16 font)

```
Row 0:  PC:XXXXXXXX  INSTR:XXXXXXXX  ALU:XXXXXXXX  Z:X  HALT:X  MEM:XXXXXXXX
Row 1:  OPC:XX  F3:X  F7:XX  RD:XX  RS1:XX  RS2:XX  IMM:XXXXXXXX
Row 2:  CTL: RW=X MR=X MW=X M2R=X AS=X BR=X JL=X JR=X PCS=X
Row 4:  REGISTERS
Rows 5-20: x00..x15 (left column), x16..x31 (right column)
```

### Row 0 - Current instruction state

| Field | Source | Meaning |
|-------|--------|---------|
| PC | `pc_out` | Program counter (hex) |
| INSTR | `instr` | Raw instruction word (hex) |
| ALU | `alu_result` | ALU output (hex). For branches: 0 or 1 (SLT/SLTU result). |
| Z | `alu_zero` | 1 when ALU result is zero |
| HALT | `halted` | 1 when CPU is halted |
| MEM | `mem_data_out` | Value read from data memory |

### Row 1 - Decoded instruction fields

| Field | Bits | Meaning |
|-------|------|---------|
| OPC | [6:0] | Opcode in hex |
| F3 | [14:12] | funct3 |
| F7 | [31:25] | funct7 |
| RD | [11:7] | Destination register number |
| RS1 | [19:15] | Source register 1 number |
| RS2 | [24:20] | Source register 2 number |
| IMM | - | Sign-extended immediate |

### Row 2 - Control unit signals

| Signal | Meaning |
|--------|---------|
| RW | reg_write |
| MR | mem_read |
| MW | mem_write |
| M2R | mem_to_reg (1 = write memory data to register) |
| AS | alu_src (1 = ALU uses immediate) |
| BR | branch |
| JL | jal |
| JR | jalr |
| PCS | pc_src (1 = PC takes branch/jump target) |

### Rows 5-20 - Register file

All 32 registers displayed as 8-digit hex values. x0 is always 0. x10/a0 shows the program exit code when halted.

---

## Quick Start

1. Load `program.hex` via Quartus programmer.
2. Hold **KEY[0]** (reset), then release. VGA shows PC=00000000, all registers 00000000.
3. **SW[0]=0**: CPU runs at 50 MHz automatically. Watch VGA for HALT=1.
4. When HALT=1: LEDR[9] on, LEDR[8:1] shows x10[7:0] (0x00 = success).

## Step-by-Step Debug

1. Set **SW[0]=1**. LEDR[0] turns on.
2. Hold **KEY[0]** to reset, release.
3. Press **KEY[1]** once per instruction.
4. VGA updates after each press: check PC, ALU, registers on screen.
5. Compare x10 (a0) at halt to expected exit code.
