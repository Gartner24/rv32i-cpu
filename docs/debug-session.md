# CPU Debug Session - program.c

Program logic: `suma(3,4)=7`, `suma(7,-2)=5`, `r3=7+5=12`, `12==12 -> return 0`

---

## Initial Setup (do this once)

1. Set **SW[0] = 1** (step mode ON - rightmost switch UP)
2. Set **SW[1] through SW[9] = 0** (all other switches DOWN)
3. **Hold KEY[0]**, then release it (this is reset)

After reset you should see:
- **HEX display**: `000000`
- **LEDR[0]** = ON (confirms step mode is active)
- **LEDR[9:1]** = all OFF

---

## How to check a register

At any point (without pressing KEY[1]):
1. Set **SW[9]=1, SW[8]=1** (register mode)
2. Set **SW[7:3]** to the register index in binary
3. Set **SW[1]=0** to see bits [15:0], **SW[1]=1** for bits [31:16]
4. Read HEX: **HEX5:HEX4** = register number in decimal, **HEX3:HEX0** = value in hex
5. Set **SW[9]=0, SW[8]=0** again to return to PC mode

---

## Step-by-Step

---

### STEP 0 - After reset (no KEY[1] pressed yet)

PC is at `0x00`. The first instruction (`jal x0, 8`) is loaded but not yet executed.

- SW[9:8]=`00` -> HEX shows `000000`
- LEDR[8:1] = `00000000` (all off)

---

### STEP 1 - Press KEY[1] once

Executed: `jal x0, 8` (crt0 jump over trap vector)

- SW[9:8]=`00` -> HEX shows `000008`
- LEDR[8:1] = `00000010` (only LEDR[1] ON, PC/4 = 2)
- No register changed (x0 is always 0)

---

### STEP 2 - Press KEY[1] once

Executed: `addi sp, x0, 1024` (initialize stack pointer)

- SW[9:8]=`00` -> HEX shows `00000C`
- **Check sp (x2):** SW[9:8]=`11`, SW[7:3]=`00010`, SW[1]=0
  - HEX shows `020400` (register 02, value = 0x0400 = 1024)

---

### STEP 3 - Press KEY[1] once

Executed: `auipc x6, 0` (load PC into x6 for call)

- SW[9:8]=`00` -> HEX shows `000010`
- **Check x6:** SW[9:8]=`11`, SW[7:3]=`00110`, SW[1]=0
  - HEX shows `06000C` (register 06, value = 0x000C)

---

### STEP 4 - Press KEY[1] once

Executed: `jalr x1, x6, 76` (call main)

- SW[9:8]=`00` -> HEX shows `000058` (jumped into main)
- LEDR[8:1] = `00010110` (LEDR[4], LEDR[2], LEDR[1] ON, PC/4 = 22)
- **Check ra (x1):** SW[9:8]=`11`, SW[7:3]=`00001`, SW[1]=0
  - HEX shows `010014` (register 01, value = 0x0014, return address back to crt0)

---

### STEP 5 - Press KEY[1] once

Executed: `addi sp, sp, -32` (main() stack frame)

- SW[9:8]=`00` -> HEX shows `00005C`
- **Check sp (x2):** SW[9:8]=`11`, SW[7:3]=`00010`, SW[1]=0
  - HEX shows `0203E0` (register 02, value = 0x03E0 = 992)

---

### STEP 6 - Press KEY[1] once

Executed: `sw ra, 28(sp)` (save return address to stack)

- SW[9:8]=`00` -> HEX shows `000060`
- No register change (this is a memory write)

---

### STEP 7 - Press KEY[1] once

Executed: `sw s0, 24(sp)` (save frame pointer to stack)

- SW[9:8]=`00` -> HEX shows `000064`
- No register change (memory write)

---

### STEP 8 - Press KEY[1] once

Executed: `addi s0, sp, 32` (set frame pointer)

- SW[9:8]=`00` -> HEX shows `000068`
- **Check s0 (x8):** SW[9:8]=`11`, SW[7:3]=`01000`, SW[1]=0
  - HEX shows `080400` (register 08, value = 0x0400 = 1024)

---

### STEP 9 - Press KEY[1] once

Executed: `addi a1, x0, 4` (second arg = 4)

- SW[9:8]=`00` -> HEX shows `00006C`
- **Check a1 (x11):** SW[9:8]=`11`, SW[7:3]=`01011`, SW[1]=0
  - HEX shows `110004` (register 11, value = 4)

---

### STEP 10 - Press KEY[1] once

Executed: `addi a0, x0, 3` (first arg = 3)

- SW[9:8]=`00` -> HEX shows `000070`
- **Check a0 (x10):** SW[9:8]=`11`, SW[7:3]=`01010`, SW[1]=0
  - HEX shows `100003` (register 10, value = 3)

---

### STEP 11 - Press KEY[1] once

Executed: `auipc x6, 0` (load PC for suma() call)

- SW[9:8]=`00` -> HEX shows `000074`
- **Check x6:** SW[9:8]=`11`, SW[7:3]=`00110`, SW[1]=0
  - HEX shows `060070` (register 06, value = 0x0070)

---

### STEP 12 - Press KEY[1] once

Executed: `jalr x1, x6, -80` (call suma for the first time)

- SW[9:8]=`00` -> HEX shows `000020` (jumped into suma)
- LEDR[8:1] = `00001000` (only LEDR[4] ON, PC/4 = 8)
- **Check ra (x1):** SW[9:8]=`11`, SW[7:3]=`00001`, SW[1]=0
  - HEX shows `010078` (register 01, value = 0x0078, return address in main)

---

### STEP 13 - Press KEY[1] once

Executed: `addi sp, sp, -32` (suma() stack frame)

- SW[9:8]=`00` -> HEX shows `000024`
- **Check sp (x2):** SW[9:8]=`11`, SW[7:3]=`00010`, SW[1]=0
  - HEX shows `0203C0` (register 02, value = 0x03C0 = 960)

---

### STEP 14 - Press KEY[1] once

Executed: `sw ra, 28(sp)` (save ra inside suma)

- SW[9:8]=`00` -> HEX shows `000028`
- No register change (memory write)

---

### STEP 15 - Press KEY[1] once

Executed: `sw s0, 24(sp)` (save s0 inside suma)

- SW[9:8]=`00` -> HEX shows `00002C`
- No register change (memory write)

---

### STEP 16 - Press KEY[1] once

Executed: `addi s0, sp, 32` (suma's frame pointer)

- SW[9:8]=`00` -> HEX shows `000030`
- **Check s0 (x8):** SW[9:8]=`11`, SW[7:3]=`01000`, SW[1]=0
  - HEX shows `0803E0` (register 08, value = 0x03E0 = 992)

---

### STEP 17 - Press KEY[1] once

Executed: `sw a0, -20(s0)` (spill arg a=3 to stack)

- SW[9:8]=`00` -> HEX shows `000034`
- No register change (memory write)

---

### STEP 18 - Press KEY[1] once

Executed: `sw a1, -24(s0)` (spill arg b=4 to stack)

- SW[9:8]=`00` -> HEX shows `000038`
- No register change (memory write)

---

### STEP 19 - Press KEY[1] once

Executed: `lw a4, -20(s0)` (reload a=3 from stack)

- SW[9:8]=`00` -> HEX shows `00003C`
- **Check a4 (x14):** SW[9:8]=`11`, SW[7:3]=`01110`, SW[1]=0
  - HEX shows `140003` (register 14, value = 3)

---

### STEP 20 - Press KEY[1] once

Executed: `lw a5, -24(s0)` (reload b=4 from stack)

- SW[9:8]=`00` -> HEX shows `000040`
- **Check a5 (x15):** SW[9:8]=`11`, SW[7:3]=`01111`, SW[1]=0
  - HEX shows `150004` (register 15, value = 4)

---

### STEP 21 - Press KEY[1] once

Executed: `add a5, a4, a5` (compute 3+4)

- SW[9:8]=`00` -> HEX shows `000044`
- **Check a5 (x15):** SW[9:8]=`11`, SW[7:3]=`01111`, SW[1]=0
  - HEX shows `150007` **(register 15, value = 7 -- KEY CHECK)**

---

### STEP 22 - Press KEY[1] once

Executed: `addi a0, a5, 0` (move result into return register)

- SW[9:8]=`00` -> HEX shows `000048`
- **Check a0 (x10):** SW[9:8]=`11`, SW[7:3]=`01010`, SW[1]=0
  - HEX shows `100007` **(register 10, value = 7 -- KEY CHECK: suma(3,4) = 7)**

---

### STEP 23 - Press KEY[1] once

Executed: `lw ra, 28(sp)` (restore return address)

- SW[9:8]=`00` -> HEX shows `00004C`
- **Check ra (x1):** SW[9:8]=`11`, SW[7:3]=`00001`, SW[1]=0
  - HEX shows `010078` (register 01, value = 0x0078)

---

### STEP 24 - Press KEY[1] once

Executed: `lw s0, 24(sp)` (restore frame pointer)

- SW[9:8]=`00` -> HEX shows `000050`
- **Check s0 (x8):** SW[9:8]=`11`, SW[7:3]=`01000`, SW[1]=0
  - HEX shows `080400` (register 08, value = 0x0400 = 1024, restored)

---

### STEP 25 - Press KEY[1] once

Executed: `addi sp, sp, 32` (tear down suma stack frame)

- SW[9:8]=`00` -> HEX shows `000054`
- **Check sp (x2):** SW[9:8]=`11`, SW[7:3]=`00010`, SW[1]=0
  - HEX shows `0203E0` (register 02, value = 0x03E0 = 992, restored)

---

### STEP 26 - Press KEY[1] once

Executed: `jalr x0, ra, 0` (return from suma to main)

- SW[9:8]=`00` -> HEX shows `000078` (back in main)
- LEDR[8:1] = `00011110` (LEDR[4], LEDR[3], LEDR[2], LEDR[1] ON, PC/4 = 30)

---

### STEP 27 - Press KEY[1] once

Executed: `sw a0, -20(s0)` (store r1=7 to stack)

- SW[9:8]=`00` -> HEX shows `00007C`
- No register change (memory write, storing a0=7)

---

### STEP 28 - Press KEY[1] once

Executed: `addi a1, x0, -2` (second arg = -2)

- SW[9:8]=`00` -> HEX shows `000080`
- **Check a1 (x11):** SW[9:8]=`11`, SW[7:3]=`01011`, SW[1]=0
  - HEX shows `11FFFE` (register 11, low 16 bits of -2 = 0xFFFE)
- If you want to confirm: SW[1]=1 -> HEX shows `11FFFF` (high 16 bits of -2)

---

### STEP 29 - Press KEY[1] once

Executed: `lw a0, -20(s0)` (reload r1=7 as first arg)

- SW[9:8]=`00` -> HEX shows `000084`
- **Check a0 (x10):** SW[9:8]=`11`, SW[7:3]=`01010`, SW[1]=0
  - HEX shows `100007` (register 10, value = 7)

---

### STEP 30 - Press KEY[1] once

Executed: `auipc x6, 0` (load PC for second suma call)

- SW[9:8]=`00` -> HEX shows `000088`
- **Check x6:** SW[9:8]=`11`, SW[7:3]=`00110`, SW[1]=0
  - HEX shows `060084` (register 06, value = 0x0084)

---

### STEP 31 - Press KEY[1] once

Executed: `jalr x1, x6, -100` (call suma second time)

- SW[9:8]=`00` -> HEX shows `000020` (jumped into suma again)
- LEDR[8:1] = `00001000` (same as first call, PC/4 = 8)
- **Check ra (x1):** SW[9:8]=`11`, SW[7:3]=`00001`, SW[1]=0
  - HEX shows `01008C` (register 01, value = 0x008C, return address to main)

---

### STEP 32 - Press KEY[1] once

Executed: `addi sp, sp, -32` (suma stack frame again)

- SW[9:8]=`00` -> HEX shows `000024`
- **Check sp (x2):** SW[9:8]=`11`, SW[7:3]=`00010`, SW[1]=0
  - HEX shows `0203C0` (register 02, value = 0x03C0 = 960)

---

### STEP 33 - Press KEY[1] once

Executed: `sw ra, 28(sp)` (save ra inside suma)

- SW[9:8]=`00` -> HEX shows `000028`
- No register change (memory write)

---

### STEP 34 - Press KEY[1] once

Executed: `sw s0, 24(sp)` (save s0 inside suma)

- SW[9:8]=`00` -> HEX shows `00002C`
- No register change (memory write)

---

### STEP 35 - Press KEY[1] once

Executed: `addi s0, sp, 32` (suma's frame pointer)

- SW[9:8]=`00` -> HEX shows `000030`
- **Check s0 (x8):** SW[9:8]=`11`, SW[7:3]=`01000`, SW[1]=0
  - HEX shows `0803E0` (register 08, value = 0x03E0 = 992)

---

### STEP 36 - Press KEY[1] once

Executed: `sw a0, -20(s0)` (spill a=7 to stack)

- SW[9:8]=`00` -> HEX shows `000034`
- No register change (memory write)

---

### STEP 37 - Press KEY[1] once

Executed: `sw a1, -24(s0)` (spill b=-2 to stack)

- SW[9:8]=`00` -> HEX shows `000038`
- No register change (memory write)

---

### STEP 38 - Press KEY[1] once

Executed: `lw a4, -20(s0)` (reload a=7 from stack)

- SW[9:8]=`00` -> HEX shows `00003C`
- **Check a4 (x14):** SW[9:8]=`11`, SW[7:3]=`01110`, SW[1]=0
  - HEX shows `140007` (register 14, value = 7)

---

### STEP 39 - Press KEY[1] once

Executed: `lw a5, -24(s0)` (reload b=-2 from stack)

- SW[9:8]=`00` -> HEX shows `000040`
- **Check a5 (x15):** SW[9:8]=`11`, SW[7:3]=`01111`, SW[1]=0
  - HEX shows `15FFFE` (register 15, low 16 bits of -2)

---

### STEP 40 - Press KEY[1] once

Executed: `add a5, a4, a5` (compute 7+(-2))

- SW[9:8]=`00` -> HEX shows `000044`
- **Check a5 (x15):** SW[9:8]=`11`, SW[7:3]=`01111`, SW[1]=0
  - HEX shows `150005` **(register 15, value = 5 -- KEY CHECK)**

---

### STEP 41 - Press KEY[1] once

Executed: `addi a0, a5, 0` (move result into return register)

- SW[9:8]=`00` -> HEX shows `000048`
- **Check a0 (x10):** SW[9:8]=`11`, SW[7:3]=`01010`, SW[1]=0
  - HEX shows `100005` **(register 10, value = 5 -- KEY CHECK: suma(7,-2) = 5)**

---

### STEP 42 - Press KEY[1] once

Executed: `lw ra, 28(sp)` (restore return address)

- SW[9:8]=`00` -> HEX shows `00004C`
- **Check ra (x1):** SW[9:8]=`11`, SW[7:3]=`00001`, SW[1]=0
  - HEX shows `01008C` (register 01, value = 0x008C)

---

### STEP 43 - Press KEY[1] once

Executed: `lw s0, 24(sp)` (restore frame pointer)

- SW[9:8]=`00` -> HEX shows `000050`
- **Check s0 (x8):** SW[9:8]=`11`, SW[7:3]=`01000`, SW[1]=0
  - HEX shows `080400` (register 08, value = 0x0400 = 1024, restored)

---

### STEP 44 - Press KEY[1] once

Executed: `addi sp, sp, 32` (tear down suma stack frame)

- SW[9:8]=`00` -> HEX shows `000054`
- **Check sp (x2):** SW[9:8]=`11`, SW[7:3]=`00010`, SW[1]=0
  - HEX shows `0203E0` (register 02, value = 0x03E0 = 992, restored)

---

### STEP 45 - Press KEY[1] once

Executed: `jalr x0, ra, 0` (return from suma to main)

- SW[9:8]=`00` -> HEX shows `00008C` (back in main)
- LEDR[8:1] = `00100011` (LEDR[5], LEDR[1], LEDR[0] ON... wait: 0x8C/4=35=0b00100011)

---

### STEP 46 - Press KEY[1] once

Executed: `sw a0, -24(s0)` (store r2=5 to stack)

- SW[9:8]=`00` -> HEX shows `000090`
- No register change (memory write, storing a0=5)

---

### STEP 47 - Press KEY[1] once

Executed: `lw a4, -20(s0)` (load r1=7)

- SW[9:8]=`00` -> HEX shows `000094`
- **Check a4 (x14):** SW[9:8]=`11`, SW[7:3]=`01110`, SW[1]=0
  - HEX shows `140007` (register 14, value = 7)

---

### STEP 48 - Press KEY[1] once

Executed: `lw a5, -24(s0)` (load r2=5)

- SW[9:8]=`00` -> HEX shows `000098`
- **Check a5 (x15):** SW[9:8]=`11`, SW[7:3]=`01111`, SW[1]=0
  - HEX shows `150005` (register 15, value = 5)

---

### STEP 49 - Press KEY[1] once

Executed: `add a5, a4, a5` (compute r3 = 7+5)

- SW[9:8]=`00` -> HEX shows `00009C`
- **Check a5 (x15):** SW[9:8]=`11`, SW[7:3]=`01111`, SW[1]=0
  - HEX shows `15000C` **(register 15, value = 12 = 0xC -- KEY CHECK)**

---

### STEP 50 - Press KEY[1] once

Executed: `sw a5, -28(s0)` (store r3=12 to stack)

- SW[9:8]=`00` -> HEX shows `0000A0`
- No register change (memory write)

---

### STEP 51 - Press KEY[1] once

Executed: `lw a4, -28(s0)` (load r3=12 for comparison)

- SW[9:8]=`00` -> HEX shows `0000A4`
- **Check a4 (x14):** SW[9:8]=`11`, SW[7:3]=`01110`, SW[1]=0
  - HEX shows `14000C` (register 14, value = 12 = 0xC)

---

### STEP 52 - Press KEY[1] once

Executed: `addi a5, x0, 12` (load constant 12 to compare against)

- SW[9:8]=`00` -> HEX shows `0000A8`
- **Check a5 (x15):** SW[9:8]=`11`, SW[7:3]=`01111`, SW[1]=0
  - HEX shows `15000C` (register 15, value = 12)
- Both a4 and a5 are 12 - the branch next should NOT be taken

---

### STEP 53 - Press KEY[1] once

Executed: `bne a4, a5, 12` (branch if r3 != 12 -- should NOT branch)

- SW[9:8]=`00` -> HEX shows `0000AC` **(KEY CHECK: must be AC, not B4. If it shows B4 the branch was wrongly taken)**
- The CPU fell through because a4 == a5

---

### STEP 54 - Press KEY[1] once

Executed: `addi a5, x0, 0` (prepare return value 0 = success)

- SW[9:8]=`00` -> HEX shows `0000B0`
- **Check a5 (x15):** SW[9:8]=`11`, SW[7:3]=`01111`, SW[1]=0
  - HEX shows `150000` (register 15, value = 0)

---

### STEP 55 - Press KEY[1] once

Executed: `jal x0, 8` (jump over the failure path)

- SW[9:8]=`00` -> HEX shows `0000B8` **(skipped 0xB4: the `addi a5, x0, -1` failure line)**

---

### STEP 56 - Press KEY[1] once

Executed: `addi a0, a5, 0` (set return value = 0)

- SW[9:8]=`00` -> HEX shows `0000BC`
- **Check a0 (x10):** SW[9:8]=`11`, SW[7:3]=`01010`, SW[1]=0
  - HEX shows `100000` **(register 10, value = 0 -- KEY CHECK: exit code = 0 = success)**

---

### STEP 57 - Press KEY[1] once

Executed: `lw ra, 28(sp)` (restore return address for main)

- SW[9:8]=`00` -> HEX shows `0000C0`
- **Check ra (x1):** SW[9:8]=`11`, SW[7:3]=`00001`, SW[1]=0
  - HEX shows `010014` (register 01, value = 0x0014, back to crt0)

---

### STEP 58 - Press KEY[1] once

Executed: `lw s0, 24(sp)` (restore s0)

- SW[9:8]=`00` -> HEX shows `0000C4`
- **Check s0 (x8):** SW[9:8]=`11`, SW[7:3]=`01000`, SW[1]=0
  - HEX shows `080000` (register 08, value = 0, original s0 before main)

---

### STEP 59 - Press KEY[1] once

Executed: `addi sp, sp, 32` (tear down main's stack frame)

- SW[9:8]=`00` -> HEX shows `0000C8`
- **Check sp (x2):** SW[9:8]=`11`, SW[7:3]=`00010`, SW[1]=0
  - HEX shows `020400` (register 02, value = 0x0400 = 1024, fully restored)

---

### STEP 60 - Press KEY[1] once

Executed: `jalr x0, ra, 0` (return from main to crt0)

- SW[9:8]=`00` -> HEX shows `000014` (ebreak instruction is next)

---

### STEP 61 - Press KEY[1] once

Executed: `ebreak` (program done)

- **LEDR[9] = ON** (halted)
- **LEDR[8:1] = all OFF** (exit code = 0 = success)
- SW[9:8]=`00` -> HEX shows `000018` (PC froze here, CPU locked)

---

## Success Criteria

If everything worked:
- After step 61: **LEDR[9] ON**, **LEDR[8:1] all OFF**
- a0 = 0 (confirmed at step 56)

If LEDR[8:1] is not all off after halt, read a0:
SW[9:8]=`11`, SW[7:3]=`01010`, SW[1]=0 -> HEX shows the failure code on HEX3:0

---

## Register Index Quick Reference

| Register | ABI name | SW[7:3] |
|---|---|---|
| x1  | ra (return addr)   | `00001` |
| x2  | sp (stack pointer) | `00010` |
| x6  | t1 (temp)          | `00110` |
| x8  | s0 / fp            | `01000` |
| x10 | a0 (return value)  | `01010` |
| x11 | a1 (2nd arg)       | `01011` |
| x14 | a4 (temp)          | `01110` |
| x15 | a5 (temp)          | `01111` |
