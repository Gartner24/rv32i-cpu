# CPU Debug Session - VGA Display

Program: `suma(3,4)=7`, `suma(7,-2)=5`, `r3=12`, `12==12 -> exit 0`

Source: `assembler/program.c` -> `assembler/program.hex` -> loaded as `program.hex`

---

## Behavior note (forwarding on VGA display)

The register file writes through a latch in `top.v` that samples on `cpu_clk`,
but the VGA display uses a forwarding mux: when the current instruction writes
to register X, the display shows the new value immediately (same step), not next
step. Reads are always combinational.

- A register write **appears on the VGA on the same step as the instruction** that causes it.
- Flip-flops initialize to 0 on FPGA (Quartus default), so all registers start at
  `00000000` after reset.

---

## Setup

1. Set **SW[0] = 1** (step mode ON)
2. All other switches: DOWN
3. Hold **KEY[0]** (reset active)
4. Release **KEY[0]** -- CPU ready at PC=0

The VGA screen has three info rows:
```
Row 0: PC:XXXXXXXX  INSTR:XXXXXXXX  ALU:XXXXXXXX  Z:X  HALT:X  MEM:XXXXXXXX
Row 1: OPC:XX  F3:X  F7:XX  RD:XX  RS1:XX  RS2:XX  IMM:XXXXXXXX
Row 2: CTL: RW=X MR=X MW=X M2R=X AS=X BR=X JL=X JR=X PCS=X
Rows 5-20: x00..x31 register values
```

Each KEY[1] press advances one instruction.

---

## STEP 0 - Initial state (no KEY[1] pressed)

```
PC:00000000  INSTR:0080006F  ALU:00000008  Z:0  HALT:0  MEM:00000000
```

All registers: **00000000** (flip-flop power-on default).

jal x0 writes to rd=x0 - forwarding suppressed, no visible change.

---

## --- CRT0 ---

### STEP 1 - PC=8 `addi sp, x0, 1024`

```
PC:00000008  INSTR:40000113  ALU:00000400  Z:0  HALT:0  MEM:00000000
```
**x02=00000400**

---

### STEP 2 - PC=C `auipc x6, 0`

```
PC:0000000C  INSTR:00000317  ALU:0000000C  Z:0  HALT:0  MEM:00000000
```
**x06=0000000C**

---

### STEP 3 - PC=10 `jalr x1, x6, 76`

```
PC:00000010  INSTR:04C300E7  ALU:00000058  Z:0  HALT:0  MEM:00000000
```
**x01=00000014** (return address = PC+4 = 0x14)

---

## --- MAIN PROLOGUE ---

### STEP 4 - PC=58 `addi sp, sp, -32`

```
PC:00000058  INSTR:FE010113  ALU:000003E0  Z:0  HALT:0  MEM:00000000
```
**x02=000003E0**

---

### STEP 5 - PC=5C `sw ra, 28(sp)`

```
PC:0000005C  INSTR:00112E23  ALU:000003FC  Z:0  HALT:0  MEM:00000000
```
No register change. (ra=0x14 written to mem[0x3FC])

---

### STEP 6 - PC=60 `sw s0, 24(sp)`

```
PC:00000060  INSTR:00812C23  ALU:000003F8  Z:0  HALT:0  MEM:00000000
```
No register change. (s0=0x00 written to mem[0x3F8])

---

### STEP 7 - PC=64 `addi s0, sp, 32`

```
PC:00000064  INSTR:02010413  ALU:00000400  Z:0  HALT:0  MEM:00000000
```
**x08=00000400**

---

### STEP 8 - PC=68 `addi a1, x0, 4`

```
PC:00000068  INSTR:00400593  ALU:00000004  Z:0  HALT:0  MEM:00000000
```
**x11=00000004**

---

### STEP 9 - PC=6C `addi a0, x0, 3`

```
PC:0000006C  INSTR:00300513  ALU:00000003  Z:0  HALT:0  MEM:00000000
```
**x10=00000003**

---

### STEP 10 - PC=70 `auipc x6, 0`

```
PC:00000070  INSTR:00000317  ALU:00000070  Z:0  HALT:0  MEM:00000000
```
**x06=00000070**

---

### STEP 11 - PC=74 `jalr x1, x6, -80`

```
PC:00000074  INSTR:FB0300E7  ALU:00000020  Z:0  HALT:0  MEM:00000000
```
**x01=00000078** (return address = PC+4 = 0x78)

---

## --- SUMA (first call: a=3, b=4) ---

### STEP 12 - PC=20 `addi sp, sp, -32`

```
PC:00000020  INSTR:FE010113  ALU:000003C0  Z:0  HALT:0  MEM:00000000
```
**x02=000003C0**

---

### STEP 13 - PC=24 `sw ra, 28(sp)`

```
PC:00000024  INSTR:00112E23  ALU:000003DC  Z:0  HALT:0  MEM:00000000
```
No register change. (ra=0x78 written to mem[0x3DC])

---

### STEP 14 - PC=28 `sw s0, 24(sp)`

```
PC:00000028  INSTR:00812C23  ALU:000003D8  Z:0  HALT:0  MEM:00000000
```
No register change. (s0=0x400 written to mem[0x3D8])

---

### STEP 15 - PC=2C `addi s0, sp, 32`

```
PC:0000002C  INSTR:02010413  ALU:000003E0  Z:0  HALT:0  MEM:00000000
```
**x08=000003E0**

---

### STEP 16 - PC=30 `sw a0, -20(s0)`

```
PC:00000030  INSTR:FEA42623  ALU:000003CC  Z:0  HALT:0  MEM:00000000
```
No register change. (a0=3 written to mem[0x3CC])

---

### STEP 17 - PC=34 `sw a1, -24(s0)`

```
PC:00000034  INSTR:FEB42423  ALU:000003C8  Z:0  HALT:0  MEM:00000000
```
No register change. (a1=4 written to mem[0x3C8])

---

### STEP 18 - PC=38 `lw a4, -20(s0)`

```
PC:00000038  INSTR:FEC42703  ALU:000003CC  Z:0  HALT:0  MEM:00000003
```
**x14=00000003**

---

### STEP 19 - PC=3C `lw a5, -24(s0)`

```
PC:0000003C  INSTR:FE842783  ALU:000003C8  Z:0  HALT:0  MEM:00000004
```
**x15=00000004**

---

### STEP 20 - PC=40 `add a5, a4, a5`

```
PC:00000040  INSTR:00F707B3  ALU:00000007  Z:0  HALT:0  MEM:00000000
```
**x15=00000007** <- KEY CHECK: 3+4=7

---

### STEP 21 - PC=44 `addi a0, a5, 0` (mv a0, a5)

```
PC:00000044  INSTR:00078513  ALU:00000007  Z:0  HALT:0  MEM:00000000
```
**x10=00000007** <- KEY CHECK: suma(3,4)=7 confirmed

---

### STEP 22 - PC=48 `lw ra, 28(sp)`

```
PC:00000048  INSTR:01C12083  ALU:000003DC  Z:0  HALT:0  MEM:00000078
```
**x01=00000078**

---

### STEP 23 - PC=4C `lw s0, 24(sp)`

```
PC:0000004C  INSTR:01812403  ALU:000003D8  Z:0  HALT:0  MEM:00000400
```
**x08=00000400**

---

### STEP 24 - PC=50 `addi sp, sp, 32`

```
PC:00000050  INSTR:02010113  ALU:000003E0  Z:0  HALT:0  MEM:00000000
```
**x02=000003E0**

---

### STEP 25 - PC=54 `jalr x0, ra, 0` (jr ra)

```
PC:00000054  INSTR:00008067  ALU:00000078  Z:0  HALT:0  MEM:00000000
```
No register change. (jr ra writes rd=x0, forwarding suppressed)

---

## --- BACK IN MAIN ---

### STEP 26 - PC=78 `sw a0, -20(s0)`

```
PC:00000078  INSTR:FEA42623  ALU:000003EC  Z:0  HALT:0  MEM:00000000
```
No register change. (a0=7 written to mem[0x3EC])

---

### STEP 27 - PC=7C `addi a1, x0, -2`

```
PC:0000007C  INSTR:FFE00593  ALU:FFFFFFFE  Z:0  HALT:0  MEM:00000000
```
**x11=FFFFFFFE**

---

### STEP 28 - PC=80 `lw a0, -20(s0)`

```
PC:00000080  INSTR:FEC42503  ALU:000003EC  Z:0  HALT:0  MEM:00000007
```
**x10=00000007**

---

### STEP 29 - PC=84 `auipc x6, 0`

```
PC:00000084  INSTR:00000317  ALU:00000084  Z:0  HALT:0  MEM:00000000
```
**x06=00000084**

---

### STEP 30 - PC=88 `jalr x1, x6, -100`

```
PC:00000088  INSTR:F9C300E7  ALU:00000020  Z:0  HALT:0  MEM:00000000
```
**x01=0000008C** (return address = PC+4 = 0x8C)

---

## --- SUMA (second call: a=7, b=-2) ---

### STEP 31 - PC=20 `addi sp, sp, -32`

```
PC:00000020  INSTR:FE010113  ALU:000003C0  Z:0  HALT:0  MEM:00000000
```
**x02=000003C0**

---

### STEP 32 - PC=24 `sw ra, 28(sp)`

```
PC:00000024  INSTR:00112E23  ALU:000003DC  Z:0  HALT:0  MEM:00000000
```
No register change. (ra=0x8C written to mem[0x3DC])

---

### STEP 33 - PC=28 `sw s0, 24(sp)`

```
PC:00000028  INSTR:00812C23  ALU:000003D8  Z:0  HALT:0  MEM:00000000
```
No register change. (s0=0x400 written to mem[0x3D8])

---

### STEP 34 - PC=2C `addi s0, sp, 32`

```
PC:0000002C  INSTR:02010413  ALU:000003E0  Z:0  HALT:0  MEM:00000000
```
**x08=000003E0**

---

### STEP 35 - PC=30 `sw a0, -20(s0)`

```
PC:00000030  INSTR:FEA42623  ALU:000003CC  Z:0  HALT:0  MEM:00000000
```
No register change. (a0=7 written to mem[0x3CC])

---

### STEP 36 - PC=34 `sw a1, -24(s0)`

```
PC:00000034  INSTR:FEB42423  ALU:000003C8  Z:0  HALT:0  MEM:00000000
```
No register change. (a1=-2 written to mem[0x3C8])

---

### STEP 37 - PC=38 `lw a4, -20(s0)`

```
PC:00000038  INSTR:FEC42703  ALU:000003CC  Z:0  HALT:0  MEM:00000007
```
**x14=00000007**

---

### STEP 38 - PC=3C `lw a5, -24(s0)`

```
PC:0000003C  INSTR:FE842783  ALU:000003C8  Z:0  HALT:0  MEM:FFFFFFFE
```
**x15=FFFFFFFE**

---

### STEP 39 - PC=40 `add a5, a4, a5`

```
PC:00000040  INSTR:00F707B3  ALU:00000005  Z:0  HALT:0  MEM:00000000
```
**x15=00000005** <- KEY CHECK: 7+(-2)=5

---

### STEP 40 - PC=44 `addi a0, a5, 0` (mv a0, a5)

```
PC:00000044  INSTR:00078513  ALU:00000005  Z:0  HALT:0  MEM:00000000
```
**x10=00000005** <- KEY CHECK: suma(7,-2)=5 confirmed

---

### STEP 41 - PC=48 `lw ra, 28(sp)`

```
PC:00000048  INSTR:01C12083  ALU:000003DC  Z:0  HALT:0  MEM:0000008C
```
**x01=0000008C**

---

### STEP 42 - PC=4C `lw s0, 24(sp)`

```
PC:0000004C  INSTR:01812403  ALU:000003D8  Z:0  HALT:0  MEM:00000400
```
**x08=00000400**

---

### STEP 43 - PC=50 `addi sp, sp, 32`

```
PC:00000050  INSTR:02010113  ALU:000003E0  Z:0  HALT:0  MEM:00000000
```
**x02=000003E0**

---

### STEP 44 - PC=54 `jalr x0, ra, 0` (jr ra)

```
PC:00000054  INSTR:00008067  ALU:0000008C  Z:0  HALT:0  MEM:00000000
```
No register change. (jr ra writes rd=x0, forwarding suppressed)

---

## --- MAIN: COMPUTE R3 AND COMPARE ---

### STEP 45 - PC=8C `sw a0, -24(s0)`

```
PC:0000008C  INSTR:FEA42423  ALU:000003E8  Z:0  HALT:0  MEM:00000000
```
No register change. (a0=5 written to mem[0x3E8])

---

### STEP 46 - PC=90 `lw a4, -20(s0)`

```
PC:00000090  INSTR:FEC42703  ALU:000003EC  Z:0  HALT:0  MEM:00000007
```
**x14=00000007**

---

### STEP 47 - PC=94 `lw a5, -24(s0)`

```
PC:00000094  INSTR:FE842783  ALU:000003E8  Z:0  HALT:0  MEM:00000005
```
**x15=00000005**

---

### STEP 48 - PC=98 `add a5, a4, a5`

```
PC:00000098  INSTR:00F707B3  ALU:0000000C  Z:0  HALT:0  MEM:00000000
```
**x15=0000000C** <- KEY CHECK: r3=12

---

### STEP 49 - PC=9C `sw a5, -28(s0)`

```
PC:0000009C  INSTR:FEF42223  ALU:000003E4  Z:0  HALT:0  MEM:00000000
```
No register change. (r3=12 written to mem[0x3E4])

---

### STEP 50 - PC=A0 `lw a4, -28(s0)`

```
PC:000000A0  INSTR:FE442703  ALU:000003E4  Z:0  HALT:0  MEM:0000000C
```
**x14=0000000C**

---

### STEP 51 - PC=A4 `addi a5, x0, 12`

```
PC:000000A4  INSTR:00C00793  ALU:0000000C  Z:0  HALT:0  MEM:00000000
```
**x15=0000000C**

---

### STEP 52 - PC=A8 `bne a4, a5, 12`

```
PC:000000A8  INSTR:00F71663  ALU:00000000  Z:1  HALT:0  MEM:00000000
```
No register change. (bne has no register write)

Note: ALU=0 (12-12=0), Z=1. BNE falls through because a4==a5.

**KEY CHECK: next PC=000000AC confirms branch NOT taken. If PC=000000B4, something is wrong.**

---

### STEP 53 - PC=AC `addi a5, x0, 0`

```
PC:000000AC  INSTR:00000793  ALU:00000000  Z:1  HALT:0  MEM:00000000
```
**x15=00000000** (success exit value prepared)

---

### STEP 54 - PC=B0 `jal x0, 8`

```
PC:000000B0  INSTR:0080006F  ALU:00000008  Z:0  HALT:0  MEM:00000000
```
No register change. (jal x0 writes rd=x0, forwarding suppressed. PC skips to 0xB8)

---

## --- MAIN EPILOGUE ---

### STEP 55 - PC=B8 `addi a0, a5, 0` (mv a0, a5)

```
PC:000000B8  INSTR:00078513  ALU:00000000  Z:1  HALT:0  MEM:00000000
```
**x10=00000000** <- KEY CHECK: exit code = 0 = SUCCESS

---

### STEP 56 - PC=BC `lw ra, 28(sp)`

```
PC:000000BC  INSTR:01C12083  ALU:000003FC  Z:0  HALT:0  MEM:00000014
```
**x01=00000014** (return address to crt0's ebreak)

---

### STEP 57 - PC=C0 `lw s0, 24(sp)`

```
PC:000000C0  INSTR:01812403  ALU:000003F8  Z:0  HALT:0  MEM:00000000
```
**x08=00000000** (s0 restored to its power-on value of 0)

---

### STEP 58 - PC=C4 `addi sp, sp, 32`

```
PC:000000C4  INSTR:02010113  ALU:00000400  Z:0  HALT:0  MEM:00000000
```
**x02=00000400** (stack fully restored to initial 1024)

---

### STEP 59 - PC=C8 `jalr x0, ra, 0` (jr ra)

```
PC:000000C8  INSTR:00008067  ALU:00000014  Z:0  HALT:0  MEM:00000000
```
No register change. (jr ra writes rd=x0, forwarding suppressed)

---

### STEP 60 - `ebreak` (CPU freezes automatically after step 59's press)

After pressing KEY[1] for step 59, PC jumps to 0x14. The halt detector on CLOCK_50
fires within one cycle (20 ns) without another key press:

```
PC:00000014  INSTR:00100073  ALU:00000014  Z:0  HALT:1  MEM:00000000
```
**HALT=1** - CPU frozen. No further key presses advance the PC.

**LEDR[9] = ON**
**LEDR[0] = ON** (SW[0]=1, step mode)

---

## Success Criteria

| After step 60 | Expected |
|---|---|
| HALT on VGA | 1 |
| PC on VGA | 00000014 |
| x10 on VGA | 00000000 |
| LEDR[9] | ON |

If x10 is not 00000000: it shows the failure code.
- x10=FFFFFFFF (-1): r3 != 12 (one of the suma calls returned wrong result)
