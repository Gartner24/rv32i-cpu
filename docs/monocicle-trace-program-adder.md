# Traza completa de ejecucion: program (adder 2+2)

Ejecucion instruccion por instruccion del programa mas simple de la CPU:

```c
int adder(int a, int b) { return a + b; }
int main() { return adder(2, 2); }
```

El ensamblador inyecta un crt0 automaticamente. El hex resultante tiene 37 instrucciones.
La traza cubre cada instruccion desde el reset hasta el halt, indicando que modulo
procesa que, que registros cambian, y por que.

---

## Mapa de instrucciones en memoria

| PC     | Hex        | Instruccion              | Seccion       |
|--------|------------|--------------------------|---------------|
| 0x00   | 0080006f   | j handle_reset           | crt0          |
| 0x04   | 0140006f   | j handle_trap            | crt0          |
| 0x08   | 40000113   | addi sp, x0, 1024        | crt0          |
| 0x0C   | 00000317   | auipc x6, 0              | crt0 call main|
| 0x10   | 04c300e7   | jalr ra, x6, 76          | crt0 call main|
| 0x14   | 00100073   | ebreak                   | crt0          |
| 0x18   | 12300513   | addi x10, x0, 0x123      | crt0 trap     |
| 0x1C   | ffdff06f   | j handle_trap            | crt0 trap     |
| 0x20   | fe010113   | addi sp, sp, -32         | adder         |
| 0x24   | 00112e23   | sw ra, 28(sp)            | adder         |
| 0x28   | 00812c23   | sw s0, 24(sp)            | adder         |
| 0x2C   | 02010413   | addi s0, sp, 32          | adder         |
| 0x30   | fea42623   | sw a0, -20(s0)           | adder         |
| 0x34   | feb42423   | sw a1, -24(s0)           | adder         |
| 0x38   | fec42703   | lw a4, -20(s0)           | adder         |
| 0x3C   | fe842783   | lw a5, -24(s0)           | adder         |
| 0x40   | 00f707b3   | add a5, a4, a5           | adder         |
| 0x44   | 00078513   | addi a0, a5, 0           | adder         |
| 0x48   | 01c12083   | lw ra, 28(sp)            | adder         |
| 0x4C   | 01812403   | lw s0, 24(sp)            | adder         |
| 0x50   | 02010113   | addi sp, sp, 32          | adder         |
| 0x54   | 00008067   | jalr x0, ra, 0           | adder         |
| 0x58   | fe010113   | addi sp, sp, -32         | main          |
| 0x5C   | 00112e23   | sw ra, 28(sp)            | main          |
| 0x60   | 00812c23   | sw s0, 24(sp)            | main          |
| 0x64   | 02010413   | addi s0, sp, 32          | main          |
| 0x68   | 00200593   | addi a1, x0, 2           | main          |
| 0x6C   | 00200513   | addi a0, x0, 2           | main          |
| 0x70   | 00000317   | auipc x6, 0              | main call adder|
| 0x74   | fb0300e7   | jalr ra, x6, -80         | main call adder|
| 0x78   | fea42623   | sw a0, -20(s0)           | main          |
| 0x7C   | fec42783   | lw a5, -20(s0)           | main          |
| 0x80   | 00078513   | addi a0, a5, 0           | main          |
| 0x84   | 01c12083   | lw ra, 28(sp)            | main          |
| 0x88   | 01812403   | lw s0, 24(sp)            | main          |
| 0x8C   | 02010113   | addi sp, sp, 32          | main          |
| 0x90   | 00008067   | jalr x0, ra, 0           | main          |

---

## Estado inicial tras reset

- PC = 0x00000000
- Todos los registros = 0x00000000
- dmem = sin inicializar

---

## Traza instruccion por instruccion

### INSTRUCCION 1 — PC=0x00: `j handle_reset`
*(jal x0, 8 — primer salto del crt0)*

```
instruction_memory  -> instr = 0x0080006f
control_unit        -> jal=1, reg_write=1 (rd=x0, ignorado)
imm_gen             -> imm_ext = 8
u_pc_branch         -> pc_out(0) + imm_ext(8) = 8
mux_jump            -> jalr=0, toma pc_branch = 8
mux_pc              -> pc_src=1 (jal), pc_next = 8
─────────────────────────────────────────────────────
posedge:  PC <- 0x08
```

---

### INSTRUCCION 2 — PC=0x08: `addi sp, x0, 1024`
*(inicializa el stack pointer al tope de la data memory)*

```
instruction_memory  -> instr = 0x40000113
control_unit        -> reg_write=1, alu_src=1 (usar imm)
register_file       -> lee rs1=x0 = 0
imm_gen             -> imm_ext = 1024 = 0x400
mux_alu_b           -> alu_src=1, operand_b = 1024
alu                 -> 0 + 1024 = 1024
mux_wb              -> mem_to_reg=0, wb_data = alu_result = 1024
mux_jal             -> jal|jalr=0, wb_data = 1024
─────────────────────────────────────────────────────
posedge:  regs[2] (sp) <- 0x00000400    PC <- 0x0C
```

---

### INSTRUCCION 3 — PC=0x0C: `auipc x6, 0`
*(1a mitad de `call main` — carga PC en x6 como base de salto)*

```
instruction_memory  -> instr = 0x00000317
control_unit        -> reg_write=1, alu_a_src=1 (usar PC), alu_src=1
imm_gen             -> imm_ext = 0  (U-type, {0<<12})
mux_alu_a           -> alu_a_src=1, operand_a = pc_out = 0x0C
alu                 -> 0x0C + 0 = 0x0C
─────────────────────────────────────────────────────
posedge:  regs[6] (t1) <- 0x0000000C    PC <- 0x10
```

---

### INSTRUCCION 4 — PC=0x10: `jalr ra, x6, 76`
*(2a mitad de `call main` — salta a main, guarda retorno al ebreak)*

```
instruction_memory  -> instr = 0x04c300e7
control_unit        -> jalr=1, reg_write=1, alu_src=1
register_file       -> lee rs1=x6 = 0x0C
imm_gen             -> imm_ext = 76 = 0x4C
alu                 -> 0x0C + 76 = 0x58  (direccion de main)
mux_jump            -> jalr=1, pc_jump = alu_result = 0x58
mux_pc              -> pc_src=1, pc_next = 0x58
mux_jal             -> jal|jalr=1, wb_data = pc_plus4 = 0x14
─────────────────────────────────────────────────────
posedge:  regs[1] (ra) <- 0x00000014    PC <- 0x58
```

---

## ENTRAMOS A `main`

Estado: sp=0x400, ra=0x14, todos los demas = 0

---

### INSTRUCCION 5 — PC=0x58: `addi sp, sp, -32`
*(reserva 32 bytes de stack para el frame de main)*

```
register_file       -> lee rs1=sp = 0x400
imm_gen             -> imm_ext = -32
alu                 -> 0x400 + (-32) = 0x3E0
─────────────────────────────────────────────────────
posedge:  regs[2] (sp) <- 0x000003E0    PC <- 0x5C
```

---

### INSTRUCCION 6 — PC=0x5C: `sw ra, 28(sp)`
*(salva ra=0x14 en el stack en dmem[0xFF])*

```
register_file       -> reg_data1=sp=0x3E0,  reg_data2=ra=0x14
imm_gen             -> imm_ext = 28
alu                 -> 0x3E0 + 28 = 0x3FC   (direccion de escritura)
control_unit        -> mem_write=1
─────────────────────────────────────────────────────
posedge:  dmem[0xFF] <- 0x00000014    PC <- 0x60
```

---

### INSTRUCCION 7 — PC=0x60: `sw s0, 24(sp)`
*(salva s0=0 en el stack en dmem[0xFE])*

```
register_file       -> reg_data2=s0=0x00
alu                 -> 0x3E0 + 24 = 0x3F8
─────────────────────────────────────────────────────
posedge:  dmem[0xFE] <- 0x00000000    PC <- 0x64
```

---

### INSTRUCCION 8 — PC=0x64: `addi s0, sp, 32`
*(establece frame pointer de main al inicio del frame)*

```
alu                 -> 0x3E0 + 32 = 0x400
─────────────────────────────────────────────────────
posedge:  regs[8] (s0) <- 0x00000400    PC <- 0x68
```

---

### INSTRUCCION 9 — PC=0x68: `addi a1, x0, 2`
*(li a1, 2 — segundo argumento para adder)*

```
register_file       -> lee rs1=x0 = 0
alu                 -> 0 + 2 = 2
─────────────────────────────────────────────────────
posedge:  regs[11] (a1) <- 0x00000002    PC <- 0x6C
```

---

### INSTRUCCION 10 — PC=0x6C: `addi a0, x0, 2`
*(li a0, 2 — primer argumento para adder)*

```
alu                 -> 0 + 2 = 2
─────────────────────────────────────────────────────
posedge:  regs[10] (a0) <- 0x00000002    PC <- 0x70
```

---

### INSTRUCCION 11 — PC=0x70: `auipc x6, 0`
*(1a mitad de `call adder` — carga PC=0x70 en x6)*

```
mux_alu_a           -> alu_a_src=1, operand_a = pc_out = 0x70
alu                 -> 0x70 + 0 = 0x70
─────────────────────────────────────────────────────
posedge:  regs[6] (t1) <- 0x00000070    PC <- 0x74
```

---

### INSTRUCCION 12 — PC=0x74: `jalr ra, x6, -80`
*(2a mitad de `call adder` — salta a adder, guarda retorno a 0x78)*

```
register_file       -> lee rs1=x6 = 0x70
imm_gen             -> imm_ext = -80 = -0x50
alu                 -> 0x70 + (-80) = 0x20  (direccion de adder)
mux_jump            -> jalr=1, pc_jump = 0x20
mux_jal             -> jal|jalr=1, wb_data = pc_plus4 = 0x78
─────────────────────────────────────────────────────
posedge:  regs[1] (ra) <- 0x00000078    PC <- 0x20
```

---

## ENTRAMOS A `adder`

Estado: a0=2, a1=2, sp=0x3E0, s0=0x400, ra=0x78

---

### INSTRUCCION 13 — PC=0x20: `addi sp, sp, -32`
*(reserva 32 bytes de stack para el frame de adder)*

```
alu                 -> 0x3E0 + (-32) = 0x3C0
─────────────────────────────────────────────────────
posedge:  regs[2] (sp) <- 0x000003C0    PC <- 0x24
```

---

### INSTRUCCION 14 — PC=0x24: `sw ra, 28(sp)`
*(salva ra=0x78 en stack de adder en dmem[0xF7])*

```
alu                 -> 0x3C0 + 28 = 0x3DC
─────────────────────────────────────────────────────
posedge:  dmem[0xF7] <- 0x00000078    PC <- 0x28
```

---

### INSTRUCCION 15 — PC=0x28: `sw s0, 24(sp)`
*(salva s0=0x400 en stack de adder en dmem[0xF6])*

```
alu                 -> 0x3C0 + 24 = 0x3D8
─────────────────────────────────────────────────────
posedge:  dmem[0xF6] <- 0x00000400    PC <- 0x2C
```

---

### INSTRUCCION 16 — PC=0x2C: `addi s0, sp, 32`
*(establece frame pointer de adder)*

```
alu                 -> 0x3C0 + 32 = 0x3E0
─────────────────────────────────────────────────────
posedge:  regs[8] (s0) <- 0x000003E0    PC <- 0x30
```

---

### INSTRUCCION 17 — PC=0x30: `sw a0, -20(s0)`
*(derrama el parametro a=2 al stack en dmem[0xF3])*

```
register_file       -> reg_data2=a0=2,  reg_data1=s0=0x3E0
alu                 -> 0x3E0 + (-20) = 0x3CC
─────────────────────────────────────────────────────
posedge:  dmem[0xF3] <- 0x00000002    PC <- 0x34
```

---

### INSTRUCCION 18 — PC=0x34: `sw a1, -24(s0)`
*(derrama el parametro b=2 al stack en dmem[0xF2])*

```
alu                 -> 0x3E0 + (-24) = 0x3C8
─────────────────────────────────────────────────────
posedge:  dmem[0xF2] <- 0x00000002    PC <- 0x38
```

---

### INSTRUCCION 19 — PC=0x38: `lw a4, -20(s0)`
*(recarga parametro a desde el stack a a4)*

```
alu                 -> 0x3E0 + (-20) = 0x3CC
data_memory         -> lee dmem[0x3CC>>2] = dmem[0xF3] = 2
mux_wb              -> mem_to_reg=1, wb_data = mem_data_out = 2
─────────────────────────────────────────────────────
posedge:  regs[14] (a4) <- 0x00000002    PC <- 0x3C
```

---

### INSTRUCCION 20 — PC=0x3C: `lw a5, -24(s0)`
*(recarga parametro b desde el stack a a5)*

```
alu                 -> 0x3E0 + (-24) = 0x3C8
data_memory         -> lee dmem[0xF2] = 2
─────────────────────────────────────────────────────
posedge:  regs[15] (a5) <- 0x00000002    PC <- 0x40
```

---

### INSTRUCCION 21 — PC=0x40: `add a5, a4, a5`
**(LA SUMA: 2 + 2 = 4)**

```
control_unit        -> reg_write=1, alu_src=0 (usar rs2, no imm)
register_file       -> reg_data1=a4=2,  reg_data2=a5=2
mux_alu_a           -> alu_a_src=0, operand_a = reg_data1 = 2
mux_alu_b           -> alu_src=0,   operand_b = reg_data2 = 2
alu_control         -> opcode=OP, funct3=000, funct7=0x00 -> alu_ctrl=ADD
alu                 -> 2 + 2 = 4,  zero=0
─────────────────────────────────────────────────────
posedge:  regs[15] (a5) <- 0x00000004    PC <- 0x44
```

---

### INSTRUCCION 22 — PC=0x44: `addi a0, a5, 0`
*(mv a0, a5 — mueve el resultado al registro de retorno)*

```
alu                 -> 4 + 0 = 4
─────────────────────────────────────────────────────
posedge:  regs[10] (a0) <- 0x00000004    PC <- 0x48
```

---

### INSTRUCCION 23 — PC=0x48: `lw ra, 28(sp)`
*(restaura ra=0x78 del stack)*

```
alu                 -> 0x3C0 + 28 = 0x3DC
data_memory         -> dmem[0xF7] = 0x78
─────────────────────────────────────────────────────
posedge:  regs[1] (ra) <- 0x00000078    PC <- 0x4C
```

---

### INSTRUCCION 24 — PC=0x4C: `lw s0, 24(sp)`
*(restaura s0=0x400 del stack)*

```
alu                 -> 0x3C0 + 24 = 0x3D8
data_memory         -> dmem[0xF6] = 0x400
─────────────────────────────────────────────────────
posedge:  regs[8] (s0) <- 0x00000400    PC <- 0x50
```

---

### INSTRUCCION 25 — PC=0x50: `addi sp, sp, 32`
*(destruye el frame de adder, sp vuelve al valor pre-adder)*

```
alu                 -> 0x3C0 + 32 = 0x3E0
─────────────────────────────────────────────────────
posedge:  regs[2] (sp) <- 0x000003E0    PC <- 0x54
```

---

### INSTRUCCION 26 — PC=0x54: `jalr x0, ra, 0`
*(jr ra — retorna a main, PC = ra = 0x78)*

```
register_file       -> lee rs1=ra = 0x78
alu                 -> 0x78 + 0 = 0x78
mux_jump            -> jalr=1, pc_jump = alu_result = 0x78
rd=x0, no se escribe
─────────────────────────────────────────────────────
posedge:  PC <- 0x78
```

---

## DE VUELTA EN `main`

Estado: a0=4, sp=0x3E0, s0=0x400, ra=0x78

---

### INSTRUCCION 27 — PC=0x78: `sw a0, -20(s0)`
*(GCC con -O0 derrama el resultado al stack antes de usarlo)*

```
register_file       -> reg_data2=a0=4,  reg_data1=s0=0x400
alu                 -> 0x400 + (-20) = 0x3EC
─────────────────────────────────────────────────────
posedge:  dmem[0xFB] <- 0x00000004    PC <- 0x7C
```

---

### INSTRUCCION 28 — PC=0x7C: `lw a5, -20(s0)`
*(recarga el resultado del stack a a5)*

```
alu                 -> 0x400 + (-20) = 0x3EC
data_memory         -> dmem[0xFB] = 4
─────────────────────────────────────────────────────
posedge:  regs[15] (a5) <- 0x00000004    PC <- 0x80
```

---

### INSTRUCCION 29 — PC=0x80: `addi a0, a5, 0`
*(mv a0, a5 — prepara valor de retorno de main)*

```
alu                 -> 4 + 0 = 4
─────────────────────────────────────────────────────
posedge:  regs[10] (a0) <- 0x00000004    PC <- 0x84
```

---

### INSTRUCCION 30 — PC=0x84: `lw ra, 28(sp)`
*(restaura ra=0x14 del stack de main)*

```
alu                 -> 0x3E0 + 28 = 0x3FC
data_memory         -> dmem[0xFF] = 0x14
─────────────────────────────────────────────────────
posedge:  regs[1] (ra) <- 0x00000014    PC <- 0x88
```

---

### INSTRUCCION 31 — PC=0x88: `lw s0, 24(sp)`
*(restaura s0=0 del stack de main)*

```
alu                 -> 0x3E0 + 24 = 0x3F8
data_memory         -> dmem[0xFE] = 0
─────────────────────────────────────────────────────
posedge:  regs[8] (s0) <- 0x00000000    PC <- 0x8C
```

---

### INSTRUCCION 32 — PC=0x8C: `addi sp, sp, 32`
*(destruye el frame de main, sp vuelve al origen)*

```
alu                 -> 0x3E0 + 32 = 0x400
─────────────────────────────────────────────────────
posedge:  regs[2] (sp) <- 0x00000400    PC <- 0x90
```

---

### INSTRUCCION 33 — PC=0x90: `jalr x0, ra, 0`
*(jr ra — retorna al crt0, PC = ra = 0x14 donde esta el ebreak)*

```
register_file       -> lee rs1=ra = 0x14
alu                 -> 0x14 + 0 = 0x14
mux_jump            -> jalr=1, pc_jump = 0x14
─────────────────────────────────────────────────────
posedge:  PC <- 0x14
```

---

### INSTRUCCION 34 — PC=0x14: `ebreak`
*(el crt0 llama a ebreak despues de que main retorna)*

```
instruction_memory  -> instr = 0x00100073
halt detection      -> cpu_en=1 && instr==0x00100073 -> halted <= 1
─────────────────────────────────────────────────────
posedge:  halted <- 1
```

**CPU DETENIDA.**

---

## Estado final en la VGA

```
HALT:1  (rojo)
x01 (ra) = 00000014  <- ultima direccion de retorno (al ebreak)
x02 (sp) = 00000400  <- stack perfectamente balanceado
x08 (s0) = 00000000  <- frame pointer restaurado
x10 (a0) = 00000004  <- resultado: 2 + 2 = 4
x15 (a5) = 00000004  <- ultimo temporal usado
```

---

## Recorrido del resultado a traves de la CPU

```
INSTRUCCION 21  add a5, a4, a5     ALU computa 2+2=4
     |
INSTRUCCION 22  addi a0, a5, 0     resultado se mueve a a0 (registro de retorno)
     |
INSTRUCCION 27  sw a0, -20(s0)     GCC lo derrama al stack (dmem[0xFB] = 4)
     |
INSTRUCCION 28  lw a5, -20(s0)     lo recarga del stack a a5
     |
INSTRUCCION 29  addi a0, a5, 0     lo copia a a0 de nuevo
     |
INSTRUCCION 33  jalr x0, ra, 0     main retorna con a0=4
     |
INSTRUCCION 34  ebreak              CPU para, a0=4 visible en VGA
```

El doble sw/lw en main (instrucciones 27-29) es artefacto de compilacion con
`-O0`. Con `-O1` o superior ese par desaparece y el resultado va directo de
`add` a `a0` sin tocar la memoria.
