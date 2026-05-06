# CPU Debug Session - VGA Display

Program: `suma(3,4)=7`, `suma(7,-2)=5`, `r3=12`, `12==12 -> exit 0`

---

## Setup

1. Set **SW[0] = 1** (step mode ON)
2. All other switches: DOWN
3. Hold **KEY[0]** (reset active) - VGA shows all registers as `00000000`
4. Release **KEY[0]** - CPU ready at PC=0

The VGA screen has three info rows:
```
Row 0: PC:XXXXXXXX  INSTR:XXXXXXXX  ALU:XXXXXXXX  Z:X  HALT:X  MEM:XXXXXXXX
Row 1: OPC:XX  F3:X  F7:XX  RD:XX  RS1:XX  RS2:XX  IMM:XXXXXXXX
Row 2: CTL: RW=X MR=X MW=X M2R=X AS=X BR=X JL=X JR=X PCS=X
Rows 5-20: x00..x31 register values
```

Each KEY[1] press executes one instruction and advances the PC.

---

## STEP 0 - Initial state (no KEY[1] pressed)

```
PC:00000000  INSTR:0080006F  ALU:00000008  Z:0  HALT:0  MEM:00000000
```
All registers: `00000000`. The first instruction (jal x0, 8) is loaded.

---

## --- CRT0 ---

### STEP 1 - `jal x0, 8` (jump over trap vector to handle_reset)

```
PC:00000008  INSTR:40000113  ALU:00000400  Z:0  HALT:0  MEM:00000000
```
No register change (rd=x0).

---

### STEP 2 - `addi sp, x0, 1024` (initialize stack pointer)

```
PC:0000000C  INSTR:00000317  ALU:0000000C  Z:0  HALT:0  MEM:00000000
```
**x02=00000400**

---

### STEP 3 - `auipc x6, 0` (load PC into x6 for call)

```
PC:00000010  INSTR:04C300E7  ALU:00000058  Z:0  HALT:0  MEM:00000000
```
**x06=0000000C**

---

### STEP 4 - `jalr x1, x6, 76` (call main at 0x58)

```
PC:00000058  INSTR:FE010113  ALU:000003E0  Z:0  HALT:0  MEM:00000000
```
**x01=00000014** (return address back to ebreak)

---

## --- MAIN PROLOGUE ---

### STEP 5 - `addi sp, sp, -32` (main stack frame)

```
PC:0000005C  INSTR:00112E23  ALU:000003FC  Z:0  HALT:0  MEM:00000000
```
**x02=000003E0**

---

### STEP 6 - `sw ra, 28(sp)` (save return address)

```
PC:00000060  INSTR:00812C23  ALU:000003F8  Z:0  HALT:0  MEM:00000000
```
No register change. (ra=0x14 written to mem[0x3FC])

---

### STEP 7 - `sw s0, 24(sp)` (save frame pointer)

```
PC:00000064  INSTR:02010413  ALU:00000400  Z:0  HALT:0  MEM:00000000
```
No register change. (s0=0 written to mem[0x3F8])

---

### STEP 8 - `addi s0, sp, 32` (set frame pointer)

```
PC:00000068  INSTR:00400593  ALU:00000004  Z:0  HALT:0  MEM:00000000
```
**x08=00000400**

---

### STEP 9 - `addi a1, x0, 4` (second arg = 4)

```
PC:0000006C  INSTR:00300513  ALU:00000003  Z:0  HALT:0  MEM:00000000
```
**x11=00000004**

---

### STEP 10 - `addi a0, x0, 3` (first arg = 3)

```
PC:00000070  INSTR:00000317  ALU:00000070  Z:0  HALT:0  MEM:00000000
```
**x10=00000003**

---

### STEP 11 - `auipc x6, 0` (load PC for suma call)

```
PC:00000074  INSTR:FB0300E7  ALU:00000020  Z:0  HALT:0  MEM:00000000
```
**x06=00000070**

---

### STEP 12 - `jalr x1, x6, -80` (call suma(3,4) at 0x20)

```
PC:00000020  INSTR:FE010113  ALU:000003C0  Z:0  HALT:0  MEM:00000000
```
**x01=00000078** (return address into main)

---

## --- SUMA (first call: a=3, b=4) ---

### STEP 13 - `addi sp, sp, -32` (suma stack frame)

```
PC:00000024  INSTR:00112E23  ALU:000003DC  Z:0  HALT:0  MEM:00000000
```
**x02=000003C0**

---

### STEP 14 - `sw ra, 28(sp)` (save ra)

```
PC:00000028  INSTR:00812C23  ALU:000003D8  Z:0  HALT:0  MEM:00000000
```
No register change. (ra=0x78 written to mem[0x3DC])

---

### STEP 15 - `sw s0, 24(sp)` (save s0)

```
PC:0000002C  INSTR:02010413  ALU:000003E0  Z:0  HALT:0  MEM:00000000
```
No register change. (s0=0x400 written to mem[0x3D8])

---

### STEP 16 - `addi s0, sp, 32` (suma frame pointer)

```
PC:00000030  INSTR:FEA42623  ALU:000003CC  Z:0  HALT:0  MEM:00000000
```
**x08=000003E0**

---

### STEP 17 - `sw a0, -20(s0)` (spill a=3 to stack)

```
PC:00000034  INSTR:FEB42423  ALU:000003C8  Z:0  HALT:0  MEM:00000000
```
No register change.

---

### STEP 18 - `sw a1, -24(s0)` (spill b=4 to stack)

```
PC:00000038  INSTR:FEC42703  ALU:000003CC  Z:0  HALT:0  MEM:00000000
```
No register change.

---

### STEP 19 - `lw a4, -20(s0)` (reload a=3)

```
PC:0000003C  INSTR:FE842783  ALU:000003C8  Z:0  HALT:0  MEM:00000003
```
**x14=00000003**

---

### STEP 20 - `lw a5, -24(s0)` (reload b=4)

```
PC:00000040  INSTR:00F707B3  ALU:00000007  Z:0  HALT:0  MEM:00000004
```
**x15=00000004**

---

### STEP 21 - `add a5, a4, a5` (compute 3+4)

```
PC:00000044  INSTR:00078513  ALU:00000007  Z:0  HALT:0  MEM:00000000
```
**x15=00000007** <- KEY CHECK: ALU computed 3+4=7

---

### STEP 22 - `addi a0, a5, 0` (move result to return register)

```
PC:00000048  INSTR:01C12083  ALU:000003DC  Z:0  HALT:0  MEM:00000000
```
**x10=00000007** <- KEY CHECK: suma(3,4)=7 confirmed

---

### STEP 23 - `lw ra, 28(sp)` (restore return address)

```
PC:0000004C  INSTR:01812403  ALU:000003D8  Z:0  HALT:0  MEM:00000078
```
**x01=00000078**

---

### STEP 24 - `lw s0, 24(sp)` (restore frame pointer)

```
PC:00000050  INSTR:02010113  ALU:000003E0  Z:0  HALT:0  MEM:00000400
```
**x08=00000400**

---

### STEP 25 - `addi sp, sp, 32` (tear down suma frame)

```
PC:00000054  INSTR:00008067  ALU:00000078  Z:0  HALT:0  MEM:00000000
```
**x02=000003E0**

---

### STEP 26 - `jalr x0, ra, 0` (return from suma to main)

```
PC:00000078  INSTR:FEA42623  ALU:000003EC  Z:0  HALT:0  MEM:00000000
```
No register change (rd=x0). Back in main.

---

## --- BACK IN MAIN ---

### STEP 27 - `sw a0, -20(s0)` (store r1=7)

```
PC:0000007C  INSTR:FFE00593  ALU:FFFFFFFE  Z:0  HALT:0  MEM:00000000
```
No register change. (a0=7 stored to stack)

---

### STEP 28 - `addi a1, x0, -2` (second arg = -2)

```
PC:00000080  INSTR:FEC42503  ALU:000003EC  Z:0  HALT:0  MEM:00000000
```
**x11=FFFFFFFE**

---

### STEP 29 - `lw a0, -20(s0)` (reload r1=7 as first arg)

```
PC:00000084  INSTR:00000317  ALU:00000084  Z:0  HALT:0  MEM:00000007
```
**x10=00000007**

---

### STEP 30 - `auipc x6, 0` (load PC for second suma call)

```
PC:00000088  INSTR:F9C300E7  ALU:00000020  Z:0  HALT:0  MEM:00000000
```
**x06=00000084**

---

### STEP 31 - `jalr x1, x6, -100` (call suma(7,-2) at 0x20)

```
PC:00000020  INSTR:FE010113  ALU:000003C0  Z:0  HALT:0  MEM:00000000
```
**x01=0000008C** (return address into main)

---

## --- SUMA (second call: a=7, b=-2) ---

### STEP 32 - `addi sp, sp, -32`

```
PC:00000024  INSTR:00112E23  ALU:000003DC  Z:0  HALT:0  MEM:00000000
```
**x02=000003C0**

---

### STEP 33 - `sw ra, 28(sp)`

```
PC:00000028  INSTR:00812C23  ALU:000003D8  Z:0  HALT:0  MEM:00000000
```
No register change. (ra=0x8C saved)

---

### STEP 34 - `sw s0, 24(sp)`

```
PC:0000002C  INSTR:02010413  ALU:000003E0  Z:0  HALT:0  MEM:00000000
```
No register change.

---

### STEP 35 - `addi s0, sp, 32`

```
PC:00000030  INSTR:FEA42623  ALU:000003CC  Z:0  HALT:0  MEM:00000000
```
**x08=000003E0**

---

### STEP 36 - `sw a0, -20(s0)` (spill a=7)

```
PC:00000034  INSTR:FEB42423  ALU:000003C8  Z:0  HALT:0  MEM:00000000
```
No register change.

---

### STEP 37 - `sw a1, -24(s0)` (spill b=-2)

```
PC:00000038  INSTR:FEC42703  ALU:000003CC  Z:0  HALT:0  MEM:00000000
```
No register change.

---

### STEP 38 - `lw a4, -20(s0)` (reload a=7)

```
PC:0000003C  INSTR:FE842783  ALU:000003C8  Z:0  HALT:0  MEM:00000007
```
**x14=00000007**

---

### STEP 39 - `lw a5, -24(s0)` (reload b=-2)

```
PC:00000040  INSTR:00F707B3  ALU:00000005  Z:0  HALT:0  MEM:FFFFFFFE
```
**x15=FFFFFFFE**

---

### STEP 40 - `add a5, a4, a5` (compute 7+(-2))

```
PC:00000044  INSTR:00078513  ALU:00000005  Z:0  HALT:0  MEM:00000000
```
**x15=00000005** <- KEY CHECK: ALU computed 7+(-2)=5

---

### STEP 41 - `addi a0, a5, 0` (move result to return register)

```
PC:00000048  INSTR:01C12083  ALU:000003DC  Z:0  HALT:0  MEM:00000000
```
**x10=00000005** <- KEY CHECK: suma(7,-2)=5 confirmed

---

### STEP 42 - `lw ra, 28(sp)` (restore return address)

```
PC:0000004C  INSTR:01812403  ALU:000003D8  Z:0  HALT:0  MEM:0000008C
```
**x01=0000008C**

---

### STEP 43 - `lw s0, 24(sp)` (restore frame pointer)

```
PC:00000050  INSTR:02010113  ALU:000003E0  Z:0  HALT:0  MEM:00000400
```
**x08=00000400**

---

### STEP 44 - `addi sp, sp, 32` (tear down suma frame)

```
PC:00000054  INSTR:00008067  ALU:0000008C  Z:0  HALT:0  MEM:00000000
```
**x02=000003E0**

---

### STEP 45 - `jalr x0, ra, 0` (return from suma to main)

```
PC:0000008C  INSTR:FEA42423  ALU:000003E8  Z:0  HALT:0  MEM:00000000
```
No register change. Back in main.

---

## --- MAIN: COMPUTE R3 AND COMPARE ---

### STEP 46 - `sw a0, -24(s0)` (store r2=5)

```
PC:00000090  INSTR:FEC42703  ALU:000003EC  Z:0  HALT:0  MEM:00000000
```
No register change. (a0=5 stored)

---

### STEP 47 - `lw a4, -20(s0)` (load r1=7)

```
PC:00000094  INSTR:FE842783  ALU:000003E8  Z:0  HALT:0  MEM:00000007
```
**x14=00000007**

---

### STEP 48 - `lw a5, -24(s0)` (load r2=5)

```
PC:00000098  INSTR:00F707B3  ALU:0000000C  Z:0  HALT:0  MEM:00000005
```
**x15=00000005**

---

### STEP 49 - `add a5, a4, a5` (r3 = 7+5)

```
PC:0000009C  INSTR:FEF42223  ALU:000003E4  Z:0  HALT:0  MEM:00000000
```
**x15=0000000C** <- KEY CHECK: r3=12

---

### STEP 50 - `sw a5, -28(s0)` (store r3=12)

```
PC:000000A0  INSTR:FE442703  ALU:000003E4  Z:0  HALT:0  MEM:00000000
```
No register change.

---

### STEP 51 - `lw a4, -28(s0)` (load r3 for comparison)

```
PC:000000A4  INSTR:00C00793  ALU:0000000C  Z:0  HALT:0  MEM:0000000C
```
**x14=0000000C**

---

### STEP 52 - `addi a5, x0, 12` (load constant 12)

```
PC:000000A8  INSTR:00F71663  ALU:00000000  Z:1  HALT:0  MEM:00000000
```
**x15=0000000C**

Note: VGA now shows the BNE instruction. ALU=0 (a4-a5=12-12=0), Z=1.
PCS=0 confirms branch will NOT be taken (a4==a5, BNE falls through).

---

### STEP 53 - `bne a4, a5, 12` (branch if r3 != 12 -- should NOT branch)

```
PC:000000AC  INSTR:00000793  ALU:00000000  Z:1  HALT:0  MEM:00000000
```
No register change.

**KEY CHECK: PC must be 000000AC (fell through). If it shows 000000B4 the BNE fix is missing.**

---

### STEP 54 - `addi a5, x0, 0` (prepare success return value)

```
PC:000000B0  INSTR:0080006F  ALU:00000008  Z:0  HALT:0  MEM:00000000
```
**x15=00000000**

---

### STEP 55 - `jal x0, 8` (jump over failure path)

```
PC:000000B8  INSTR:00078513  ALU:00000000  Z:1  HALT:0  MEM:00000000
```
No register change. (PC skipped 0xB4: `addi a5, x0, -1`)

---

## --- MAIN EPILOGUE ---

### STEP 56 - `addi a0, a5, 0` (set exit code = 0)

```
PC:000000BC  INSTR:01C12083  ALU:000003FC  Z:0  HALT:0  MEM:00000000
```
**x10=00000000** <- KEY CHECK: exit code = 0 = SUCCESS

---

### STEP 57 - `lw ra, 28(sp)` (restore return address)

```
PC:000000C0  INSTR:01812403  ALU:000003F8  Z:0  HALT:0  MEM:00000014
```
**x01=00000014** (crt0 return address)

---

### STEP 58 - `lw s0, 24(sp)` (restore s0)

```
PC:000000C4  INSTR:02010113  ALU:00000400  Z:0  HALT:0  MEM:00000000
```
**x08=00000000**

---

### STEP 59 - `addi sp, sp, 32` (tear down main frame)

```
PC:000000C8  INSTR:00008067  ALU:00000014  Z:0  HALT:0  MEM:00000000
```
**x02=00000400** (stack fully restored to initial 1024)

---

### STEP 60 - `jalr x0, ra, 0` (return from main to crt0)

```
PC:00000014  INSTR:00100073  ALU:00000000  Z:1  HALT:0  MEM:00000000
```
No register change. ebreak is next.

---

### STEP 61 - `ebreak` (program done)

```
PC:00000018  INSTR:12300513  ALU:00000123  Z:0  HALT:1  MEM:00000000
```
**HALT=1** - CPU frozen. PC stopped at 0x18 (trap handler body, never executes).

**LEDR[9] = ON**
**LEDR[8:1] = all OFF** (exit code 0 = success)

---

## Success Criteria

| After step 61 | Expected |
|---|---|
| HALT on VGA | 1 |
| PC on VGA | 00000018 |
| x10 on VGA | 00000000 |
| LEDR[9] | ON |
| LEDR[8:1] | all OFF |

If LEDR[8:1] are not all OFF: x10 shows the failure code. Non-zero means the comparison at step 53 went wrong.
