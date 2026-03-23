"""
Ensamblador RV32I.
    cd assembler
    python assembler.py program.asm program.hex program.bin
"""

import sys


type_r = {
    "add":  (0b000, 0b0000000),
    "sub":  (0b000, 0b0100000),
    "xor":  (0b100, 0b0000000),
    "or":   (0b110, 0b0000000),
    "and":  (0b111, 0b0000000),
    "sll":  (0b001, 0b0000000),
    "srl":  (0b101, 0b0000000),
    "sra":  (0b101, 0b0100000),
    "slt":  (0b010, 0b0000000),
    "sltu": (0b011, 0b0000000),
}

type_i = {
    "addi":  0b000,
    "xori":  0b100,
    "ori":   0b110,
    "andi":  0b111,
    "slli":  0b001,
    "srli":  0b101,
    "srai":  0b101,
    "slti":  0b010,
    "sltiu": 0b011,
}

type_i_load = {
    "lb":  0b000,
    "lh":  0b001,
    "lw":  0b010,
    "lbu": 0b100,
    "lhu": 0b101,
}

type_i_jalr = {
    "jalr": 0b000,
}

type_i_env = {
    "ecall":  0b0000000,
    "ebreak": 0b0000001,
}

type_s = {
    "sb": 0b000,
    "sh": 0b001,
    "sw": 0b010,
}

type_b = {
    "beq":  0b000,
    "bne":  0b001,
    "blt":  0b100,
    "bge":  0b101,
    "bltu": 0b110,
    "bgeu": 0b111,
}

type_j = {"jal"}

type_u = {
    "lui":   0b0110111,
    "auipc": 0b0010111,
}

type_pseudointruction = {
    "la": 2, "li": 2, "sltz": 1, "bgtz": 1, "jr": 1,
    "lb": 1, "nop": 1, "sgtz": 1, "bgt": 1, "jalr": 1,
    "lh": 1, "mv": 1, "beqz": 1, "ble": 1, "ret": 1,
    "lw": 1, "not": 1, "bnez": 1, "bgtu": 1, "call": 2,
    "sb": 1, "neg": 1, "blez": 1, "bleu": 1, "tail": 2,
    "sh": 1, "seqz": 1, "bgez": 1, "j": 1,
    "sw": 1, "snez": 1, "bltz": 1, "jal": 1,
}

registers = {
    "zero": 0,  "ra": 1,  "sp": 2,  "gp": 3,  "tp": 4,
    "t0":   5,  "t1": 6,  "t2": 7,  "s0": 8,  "fp": 8,
    "s1":   9,  "a0": 10, "a1": 11, "a2": 12, "a3": 13,
    "a4":   14, "a5": 15, "a6": 16, "a7": 17, "s2": 18,
    "s3":   19, "s4": 20, "s5": 21, "s6": 22, "s7": 23,
    "s8":   24, "s9": 25, "s10": 26,"s11": 27, "t3": 28,
    "t4":   29, "t5": 30, "t6": 31,
}


# --- Manejo de errores ---

def asm_error(msg: str, line: str = "") -> None:
    """Imprime error y termina el programa."""
    if line:
        print(f"Error: {msg}\n  → '{line.strip()}'", file=sys.stderr)
    else:
        print(f"Error: {msg}", file=sys.stderr)
    sys.exit(1)

def check_imm(value: int, bits: int, signed: bool, line: str = "") -> None:
    """Verifica que el inmediato cabe en el rango dado."""
    if signed:
        lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    else:
        lo, hi = 0, (1 << bits) - 1
    if not (lo <= value <= hi):
        asm_error(f"Inmediato {value} fuera de rango [{lo}, {hi}] para {bits} bits", line)

def check_register(name, line=""):
    """Verifica que el registro existe."""
    name = name.strip()
    if name in registers:
        return
    if name.startswith("x"):
        try:
            n = int(name[1:])
            if 0 <= n <= 31:
                return
        except ValueError:
            pass
    asm_error(f"Registro inválido '{name}'", line)

def check_alignment(value, line=""):
    """Verifica que el offset es múltiplo de 2."""
    if value % 2 != 0:
        asm_error(f"Offset {value} no es múltiplo de 2", line)


# --- Funciones base ---

def strip_comment(line: str) -> str:
    """Quita todo desde '#' hasta el final de la línea."""
    if "#" in line:
        return line[: line.index("#")].strip()
    return line.strip()


def int_to_bin(value: int | str, bin_size: int, line: str = "") -> str:
    int_value: int
    if isinstance(value, str):
        value = value.strip()
        if value in registers:
            int_value = registers[value]
        elif value.startswith("x"):
            try:
                n = int(value[1:])
                if not (0 <= n <= 31):
                    asm_error(f"Registro inválido '{value}'", line)
                int_value = n
            except ValueError:
                asm_error(f"Registro inválido '{value}'", line)
                int_value = 0
        else:
            try:
                int_value = int(value, 0)
            except ValueError:
                asm_error(f"No se puede convertir '{value}' a número", line)
                int_value = 0
    else:
        int_value = value

    if int_value < 0:
        int_value = int_value & ((1 << bin_size) - 1)

    return format(int_value, f'0{bin_size}b')


def binary_to_hex(binary_program):
    hex_program = ""
    for line in binary_program.splitlines():
        hex_line = format(int(line, 2), '08x')
        hex_program += hex_line + "\n"
    return hex_program


# --- Instrucciones ---

def type_r_instruction(line):
    instruction, rd, rs1, rs2 = "", "", "", ""
    try:
        instruction_rd, rs1, rs2 = line.strip().split(",")
        parts = instruction_rd.split()
        instruction, rd = parts[0], parts[1]
    except ValueError:
        asm_error("Sintaxis tipo R inválida, se esperaba: instr rd, rs1, rs2", line)

    check_register(rd, line)
    check_register(rs1, line)
    check_register(rs2, line)

    func3, func7 = type_r[instruction]
    rd_bin    = int_to_bin(rd, 5, line)
    rs1_bin   = int_to_bin(rs1, 5, line)
    rs2_bin   = int_to_bin(rs2, 5, line)
    func3_bin = int_to_bin(func3, 3, line)
    func7_bin = int_to_bin(func7, 7, line)

    return f"{func7_bin}{rs2_bin}{rs1_bin}{func3_bin}{rd_bin}0110011\n"


def type_i_instruction(line):
    instruction, rd, rs1, imm = "", "", "", "0"
    try:
        instruction_rd, rs1, imm = line.strip().split(",")
        parts = instruction_rd.split()
        instruction, rd = parts[0], parts[1]
    except ValueError:
        asm_error("Sintaxis tipo I inválida, se esperaba: instr rd, rs1, imm", line)

    check_register(rd, line)
    check_register(rs1, line)

    func3 = type_i[instruction]
    rd_bin    = int_to_bin(rd, 5, line)
    rs1_bin   = int_to_bin(rs1, 5, line)
    func3_bin = int_to_bin(func3, 3, line)
    imm_bin   = ""

    if instruction == "srai":
        imm_val = int(imm, 0)
        check_imm(imm_val, 5, False, line)
        imm_bin = int_to_bin(imm_val, 5, line)
        imm_bin = f"0100000{imm_bin}"
    elif instruction in ("slli", "srli"):
        imm_val = int(imm, 0)
        check_imm(imm_val, 5, False, line)
        imm_bin = int_to_bin(imm_val, 5, line)
        imm_bin = f"0000000{imm_bin}"
    else:
        imm_val = int(imm, 0)
        check_imm(imm_val, 12, True, line)
        imm_bin = int_to_bin(imm_val, 12, line)

    return f"{imm_bin}{rs1_bin}{func3_bin}{rd_bin}0010011\n"


def type_i_load_instruction(line):
    instruction, rd, rs1, imm = "", "", "", "0"
    try:
        instruction_rd, offset = line.strip().split(",")
        parts = instruction_rd.split()
        instruction, rd = parts[0], parts[1]
        imm, rs1 = offset.split("(")
        rs1 = rs1.rstrip(")")
    except ValueError:
        asm_error("Sintaxis load inválida, se esperaba: instr rd, imm(rs1)", line)

    check_register(rd, line)
    check_register(rs1, line)
    imm_val = int(imm, 0)
    check_imm(imm_val, 12, True, line)

    func3  = type_i_load[instruction]
    opcode = int_to_bin(0b0000011, 7, line)
    imm_bin   = int_to_bin(imm_val, 12, line)
    rs1_bin   = int_to_bin(rs1, 5, line)
    func3_bin = int_to_bin(func3, 3, line)
    rd_bin    = int_to_bin(rd, 5, line)

    return f"{imm_bin}{rs1_bin}{func3_bin}{rd_bin}{opcode}\n"


def type_s_instruction(line):
    instruction, rs2, rs1, imm = "", "", "", "0"
    try:
        instruction_rs2, offset = line.strip().split(",")
        parts = instruction_rs2.split()
        instruction, rs2 = parts[0], parts[1]
        imm, rs1 = offset.split("(")
        rs1 = rs1.rstrip(")")
    except ValueError:
        asm_error("Sintaxis tipo S inválida, se esperaba: instr rs2, imm(rs1)", line)

    check_register(rs2, line)
    check_register(rs1, line)
    imm_val = int(imm, 0)
    check_imm(imm_val, 12, True, line)

    func3  = type_s[instruction]
    opcode = int_to_bin(0b0100011, 7, line)
    imm_bin   = int_to_bin(imm_val, 12, line)
    rs1_bin   = int_to_bin(rs1, 5, line)
    rs2_bin   = int_to_bin(rs2, 5, line)
    func3_bin = int_to_bin(func3, 3, line)

    return f"{imm_bin[0:7]}{rs2_bin}{rs1_bin}{func3_bin}{imm_bin[7:12]}{opcode}\n"


def type_b_instruction(line):
    instruction, rs1, rs2, imm = "", "", "", "0"
    try:
        instruction_rs1, rs2, imm = line.strip().split(",")
        parts = instruction_rs1.split()
        instruction, rs1 = parts[0], parts[1]
    except ValueError:
        asm_error("Sintaxis tipo B inválida, se esperaba: instr rs1, rs2, offset", line)

    check_register(rs1, line)
    check_register(rs2, line)
    imm_val = int(imm, 0)
    check_imm(imm_val, 13, True, line)
    check_alignment(imm_val, line)

    func3  = type_b[instruction]
    opcode = int_to_bin(0b1100011, 7, line)
    imm_bin   = int_to_bin(imm_val, 13, line)
    rs1_bin   = int_to_bin(rs1, 5, line)
    rs2_bin   = int_to_bin(rs2, 5, line)
    func3_bin = int_to_bin(func3, 3, line)

    return f"{imm_bin[0]}{imm_bin[2:8]}{rs2_bin}{rs1_bin}{func3_bin}{imm_bin[8:12]}{imm_bin[1]}{opcode}\n"


def type_j_instruction(line):
    rd, imm = "", "0"
    try:
        instruction_rd, imm = line.strip().split(",")
        parts = instruction_rd.split()
        rd = parts[1]
    except ValueError:
        asm_error("Sintaxis tipo J inválida, se esperaba: jal rd, offset", line)

    check_register(rd, line)
    imm_val = int(imm, 0)
    check_imm(imm_val, 21, True, line)
    check_alignment(imm_val, line)

    opcode  = int_to_bin(0b1101111, 7, line)
    imm_bin = int_to_bin(imm_val, 21, line)
    rd_bin  = int_to_bin(rd, 5, line)

    return f"{imm_bin[0]}{imm_bin[10:20]}{imm_bin[9]}{imm_bin[1:9]}{rd_bin}{opcode}\n"


def type_i_jalr_instruction(line):
    rd, rs1, imm = "", "", "0"
    try:
        instruction_rd, offset = line.strip().split(",", 1)
        parts = instruction_rd.split()
        rd = parts[1]
        if "(" in offset:
            imm, rs1 = offset.split("(")
            rs1 = rs1.rstrip(")")
        else:
            rs1, imm = offset.strip().split(",")
    except ValueError:
        asm_error("Sintaxis jalr inválida, se esperaba: jalr rd, imm(rs1) o jalr rd, rs1, imm", line)

    check_register(rd, line)
    check_register(rs1, line)
    imm_val = int(imm, 0)
    check_imm(imm_val, 12, True, line)

    func3  = int_to_bin(0b000, 3, line)
    opcode = int_to_bin(0b1100111, 7, line)
    imm_bin = int_to_bin(imm_val, 12, line)
    rs1_bin = int_to_bin(rs1, 5, line)
    rd_bin  = int_to_bin(rd, 5, line)

    return f"{imm_bin}{rs1_bin}{func3}{rd_bin}{opcode}\n"


def type_u_instruction(line):
    instruction, rd, imm = "", "", "0"
    try:
        instruction_rd, imm = line.strip().split(",")
        parts = instruction_rd.split()
        instruction, rd = parts[0], parts[1]
    except ValueError:
        asm_error("Sintaxis tipo U inválida, se esperaba: instr rd, imm", line)

    check_register(rd, line)

    imm_val = int(imm, 0)
    if instruction == "lui":
        check_imm(imm_val, 20, False, line)  # lui: unsigned
    else:
        check_imm(imm_val, 20, True, line)   # auipc: signed

    opcode  = int_to_bin(type_u[instruction], 7, line)
    rd_bin  = int_to_bin(rd, 5, line)
    imm_bin = int_to_bin(imm_val, 20, line)

    return f"{imm_bin}{rd_bin}{opcode}\n"


def type_i_env_instruction(line):
    instruction = line.strip().split()[0]
    func12     = type_i_env[instruction]
    func12_bin = int_to_bin(func12, 12, line)
    zeros      = int_to_bin(0, 5, line)
    func3_bin  = int_to_bin(0, 3, line)
    opcode     = int_to_bin(0b1110011, 7, line)

    return f"{func12_bin}{zeros}{func3_bin}{zeros}{opcode}\n"


def type_pseudoinstruction(line):
    parts = line.strip().split(",")
    first = parts[0].split()
    instruction = first[0]
    operands = first[1:] + [p.strip() for p in parts[1:]]

    def split_imm(value):
        """Divide offset en upper[31:12] y lower[11:0] con ajuste de signo."""
        value = int(str(value), 0)
        lower = value & 0xFFF
        if lower >= 2048:
            lower -= 4096
        upper = (value - lower) >> 12
        return upper, lower

    if instruction == "la":
        upper, lower = split_imm(operands[1])
        line = f"auipc {operands[0]}, {upper}\naddi {operands[0]}, {operands[0]}, {lower}"

    elif instruction in ("lb", "lh", "lw"):
        upper, lower = split_imm(operands[1])
        line = f"auipc {operands[0]}, {upper}\n{instruction} {operands[0]}, {lower}({operands[0]})"

    elif instruction in ("sb", "sh", "sw"):
        upper, lower = split_imm(operands[1])
        line = f"auipc {operands[2]}, {upper}\n{instruction} {operands[0]}, {lower}({operands[2]})"

    elif instruction == "nop":
        line = f"addi x0, x0, 0"

    elif instruction == "li":
        imm = int(operands[1], 0)
        if -2048 <= imm <= 2047:
            line = f"addi {operands[0]}, x0, {operands[1]}"
        else:
            upper, lower = split_imm(operands[1])
            line = f"lui {operands[0]}, {upper}\naddi {operands[0]}, {operands[0]}, {lower}"

    elif instruction == "mv":
        line = f"addi {operands[0]}, {operands[1]}, 0"

    elif instruction == "not":
        line = f"xori {operands[0]}, {operands[1]}, -1"

    elif instruction == "neg":
        line = f"sub {operands[0]}, x0, {operands[1]}"

    elif instruction == "seqz":
        line = f"sltiu {operands[0]}, {operands[1]}, 1"

    elif instruction == "snez":
        line = f"sltu {operands[0]}, x0, {operands[1]}"

    elif instruction == "sltz":
        line = f"slt {operands[0]}, {operands[1]}, x0"

    elif instruction == "sgtz":
        line = f"slt {operands[0]}, x0, {operands[1]}"

    elif instruction == "beqz":
        line = f"beq {operands[0]}, x0, {operands[1]}"

    elif instruction == "bnez":
        line = f"bne {operands[0]}, x0, {operands[1]}"

    elif instruction == "blez":
        line = f"bge x0, {operands[0]}, {operands[1]}"

    elif instruction == "bgez":
        line = f"bge {operands[0]}, x0, {operands[1]}"

    elif instruction == "bltz":
        line = f"blt {operands[0]}, x0, {operands[1]}"

    elif instruction == "bgtz":
        line = f"blt x0, {operands[0]}, {operands[1]}"

    elif instruction == "bgt":
        line = f"blt {operands[1]}, {operands[0]}, {operands[2]}"

    elif instruction == "ble":
        line = f"bge {operands[1]}, {operands[0]}, {operands[2]}"

    elif instruction == "bgtu":
        line = f"bltu {operands[1]}, {operands[0]}, {operands[2]}"

    elif instruction == "bleu":
        line = f"bgeu {operands[1]}, {operands[0]}, {operands[2]}"

    elif instruction == "j":
        line = f"jal x0, {operands[0]}"

    elif instruction == "jal" and len(operands) == 1:
        line = f"jal x1, {operands[0]}"

    elif instruction == "jr":
        line = f"jalr x0, {operands[0]}, 0"

    elif instruction == "jalr" and len(operands) == 1:
        line = f"jalr x1, {operands[0]}, 0"

    elif instruction == "ret":
        line = f"jalr x0, x1, 0"

    elif instruction == "call":
        offset = int(operands[0], 0)
        lower = offset & 0xFFF
        if lower >= 2048:
            lower -= 4096
        upper = (offset - lower) >> 12
        line = f"auipc x6, {upper}\njalr x1, x6, {lower}"

    elif instruction == "tail":
        offset = int(operands[0], 0)
        lower = offset & 0xFFF
        if lower >= 2048:
            lower -= 4096
        upper = (offset - lower) >> 12
        line = f"auipc x6, {upper}\njalr x0, x6, {lower}"

    elif instruction in ("jal", "jalr"):
        pass  # instrucción real, no expandir

    else:
        asm_error(f"Pseudoinstrucción no soportada '{instruction}'", line)

    return line


def pseudo_size(line):
    instruction = line.split()[0]
    if instruction == "li":
        parts = line.strip().split(",")
        imm = int(parts[1].strip(), 0)
        return 1 if -2048 <= imm <= 2047 else 2
    return type_pseudointruction.get(instruction, 1)


def clean_source_code(source_code, symbol_table):
    source_code_cleaned = ""
    pc_count = 0
    for line in source_code:
        line = strip_comment(line)
        if not line:
            continue
        if ":" in line:
            pass
        else:
            pc = pc_count * 4
            instruction = line.split()[0]
            pc_count += pseudo_size(line)

            # Reemplazar tags por offsets - de mayor a menor longitud para evitar sustituciones parciales
            for tag, tag_pc in sorted(symbol_table.items(), key=lambda x: len(x[0]), reverse=True):
                if tag in line:
                    offset = tag_pc - pc
                    line = line.replace(tag, str(offset))

            # Verificar que no queden tags sin resolver
            for tag in symbol_table:
                if tag in line:
                    asm_error(f"Tag '{tag}' no resuelta en la línea", line)

            # Expandir pseudoinstrucción si no tiene formato imm(rs1)
            if instruction in type_pseudointruction and "(" not in line:
                line = type_pseudoinstruction(line)

            source_code_cleaned += f"{line}\n"
    return source_code_cleaned


def second_pass(source_code, symbol_table):
    """Segunda pasada: traduce instrucciones a binario."""
    source_code_cleaned = clean_source_code(source_code, symbol_table)
    binary_program = ""

    for line in source_code_cleaned.splitlines():
        line = strip_comment(line)
        if not line:
            continue
        instruction = line.strip().split()[0]

        if instruction in type_r:
            binary_program += type_r_instruction(line)
        elif instruction in type_i:
            binary_program += type_i_instruction(line)
        elif instruction in type_i_load:
            binary_program += type_i_load_instruction(line)
        elif instruction in type_i_jalr:
            binary_program += type_i_jalr_instruction(line)
        elif instruction in type_i_env:
            binary_program += type_i_env_instruction(line)
        elif instruction in type_s:
            binary_program += type_s_instruction(line)
        elif instruction in type_b:
            binary_program += type_b_instruction(line)
        elif instruction in type_j:
            binary_program += type_j_instruction(line)
        elif instruction in type_u:
            binary_program += type_u_instruction(line)
        else:
            asm_error(f"Instrucción no soportada '{instruction}'", line)

    return binary_program


def first_pass(source_code):
    """Primera pasada: construir tabla de símbolos."""
    symbol_table = {}
    pc_count = 0

    for line in source_code:
        line = strip_comment(line)
        if not line:
            continue
        if ":" in line:
            tag_name = line.replace(":", "").strip()
            if tag_name in symbol_table:
                asm_error(f"Tag duplicada '{tag_name}'")
            symbol_table[tag_name] = pc_count * 4
        else:
            pc_count += pseudo_size(line)

    return symbol_table


def main() -> None:
    if len(sys.argv) != 4:
        print("Uso: python assembler.py <entrada.asm> <salida.hex> <salida.bin>", file=sys.stderr)
        sys.exit(1)

    asm_path = sys.argv[1]
    hex_path = sys.argv[2]
    bin_path = sys.argv[3]

    with open(asm_path, "r", encoding="utf-8") as f:
        source_code = f.readlines()

    symbol_table   = first_pass(source_code)
    binary_program = second_pass(source_code, symbol_table)
    hex_program    = binary_to_hex(binary_program)
    cleaned        = clean_source_code(source_code, symbol_table)

    with open("./program_cleaned.asm", "w", encoding="utf-8") as f:
        f.write(cleaned)

    with open(hex_path, "w", encoding="utf-8") as f:
        f.write(hex_program)

    with open(bin_path, "w") as f:
        f.write(binary_program)


if __name__ == "__main__":
    main()
