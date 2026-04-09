# Assembler for RISC-V 32I

A simple assembler for RISC-V 32I, written in Python using GNU assembler syntax. The assembler script is `rv32i_assembler.py`.

## Syntax

### Labels

- **label:** - Etiqueta en el código fuente (source code)
- **symbol** - Dirección en la memoria de programa (program memory)
- **offset** - Desplazamiento en la memoria de programa (program memory)

### Instructions

#### Support for 40 instructions from the RV32I Base Integer Instructions

**Type R**

| # | Instruction | Description |
|---|-------------|-------------|
| 1 | `add rd, rs, rt` | Add |
| 2 | `sub rd, rs, rt` | Subtract |
| 3 | `xor rd, rs, rt` | Xor |
| 4 | `or rd, rs, rt` | Or |
| 5 | `and rd, rs, rt` | And |
| 6 | `sll rd, rs, rt` | Shift Left Logical |
| 7 | `srl rd, rs, rt` | Shift Right Logical |
| 8 | `sra rd, rs, rt` | Shift Right Arithmetic |
| 9 | `slt rd, rs, rt` | Set Less Than |
| 10 | `sltu rd, rs, rt` | Set Less Than Unsigned |

**Type I**

| # | Instruction | Description |
|---|-------------|-------------|
| 11 | `addi rd, rs, imm` | Add immediate |
| 12 | `andi rd, rs, imm` | And immediate |
| 13 | `ori rd, rs, imm` | Or immediate |
| 14 | `xori rd, rs, imm` | Xor immediate |
| 15 | `slli rd, rs, imm` | Shift Left Logical immediate |
| 16 | `srli rd, rs, imm` | Shift Right Logical immediate |
| 17 | `srai rd, rs, imm` | Shift Right Arithmetic immediate |
| 18 | `slti rd, rs, imm` | Set Less Than immediate |
| 19 | `sltiu rd, rs, imm` | Set Less Than Unsigned immediate |

**Type I - Load**

| # | Instruction | Description |
|---|-------------|-------------|
| 20 | `lb rd, rs, imm` | Load Byte |
| 21 | `lh rd, rs, imm` | Load Half |
| 22 | `lw rd, rs, imm` | Load Word |
| 23 | `lbu rd, rs, imm` | Load Byte Unsigned |
| 24 | `lhu rd, rs, imm` | Load Half Unsigned |

**Type S**

| # | Instruction | Description |
|---|-------------|-------------|
| 25 | `sb rd, rs, imm` | Store Byte |
| 26 | `sh rd, rs, imm` | Store Half |
| 27 | `sw rd, rs, imm` | Store Word |

**Type B**

| # | Instruction | Description |
|---|-------------|-------------|
| 28 | `beq rd, rs, imm` | Branch if equal |
| 29 | `bne rd, rs, imm` | Branch if not equal |
| 30 | `blt rd, rs, imm` | Branch if less than |
| 31 | `bge rd, rs, imm` | Branch if greater than or equal |
| 32 | `bltu rd, rs, imm` | Branch if less than unsigned |
| 33 | `bgeu rd, rs, imm` | Branch if greater than or equal unsigned |

**Type J**

| # | Instruction | Description |
|---|-------------|-------------|
| 34 | `jal rd, imm` | Jump and link |
| 35 | `jalr rd, rs, imm` | Jump and link register |

**Type U**

| # | Instruction | Description |
|---|-------------|-------------|
| 36 | `lui rd, imm` | Load Upper Immediate |
| 37 | `auipc rd, imm` | Add Upper Immediate to PC |

**Type E (Environment)**

| # | Instruction | Description |
|---|-------------|-------------|
| 38 | `ecall` | Exit |
| 39 | `ebreak` | Break |

#### Pseudoinstructions (35 total)

**Load / Address**

| # | Instruction | Description |
|---|-------------|-------------|
| 1 | `la rd, symbol` | Load Address |
| 2 | `lb rd, symbol` / `lh rd, symbol` / `lw rd, symbol` | Load Byte, Half, or Word from Symbol |
| 3 | `sb rs, symbol` / `sh rs, symbol` / `sw rs, symbol` | Store Byte, Half, or Word to Symbol |
| 4 | `li rd, immediate` | Load immediate |

**Arithmetic / Logic**

| # | Instruction | Description |
|---|-------------|-------------|
| 5 | `nop` | No operation |
| 6 | `mv rd, rs` | Move |
| 7 | `not rd, rs` | One's complement |
| 8 | `neg rd, rs` | Two's complement |
| 9 | `seqz rd, rs` | Set if equal to zero |
| 10 | `snez rd, rs` | Set if not equal to zero |
| 11 | `sltz rd, rs` | Set if less than zero |
| 12 | `sgtz rd, rs` | Set if greater than zero |

**Branch - Zero comparisons**

| # | Instruction | Description |
|---|-------------|-------------|
| 13 | `beqz rs, offset` | Branch if equal to zero |
| 14 | `bnez rs, offset` | Branch if not equal to zero |
| 15 | `blez rs, offset` | Branch if less than or equal to zero |
| 16 | `bgez rs, offset` | Branch if greater than or equal to zero |
| 17 | `bltz rs, offset` | Branch if less than zero |
| 18 | `bgtz rs, offset` | Branch if greater than zero |

**Branch - Register comparisons**

| # | Instruction | Description |
|---|-------------|-------------|
| 19 | `bgt rs, rt, offset` | Branch if greater than |
| 20 | `ble rs, rt, offset` | Branch if less than or equal |
| 21 | `bgtu rs, rt, offset` | Branch if greater than unsigned |
| 22 | `bleu rs, rt, offset` | Branch if less than or equal unsigned |

**Jump / Call**

| # | Instruction | Description |
|---|-------------|-------------|
| 23 | `j offset` | Jump |
| 24 | `jal offset` | Jump and link |
| 25 | `jr rs` | Jump register |
| 26 | `jalr rs` | Jump and link register |
| 27 | `ret` | Return |
| 28 | `call offset` | Call |
| 29 | `tail offset` | Tail call |

**Total:** 35 pseudoinstructions
