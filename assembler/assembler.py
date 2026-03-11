#!/usr/bin/env python3
"""
Ensamblador RV32I en dos pasadas — Paso 1: Esqueleto + primera pasada (solo tabla de símbolos).

Está en assembler/. Ejecutar desde la raíz del proyecto:
  python assembler/assembler.py assembler/program.asm assembler/program.hex assembler/program.bin
O desde dentro de assembler/:
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
    "slti":  0b101,
    "sltiu": 0b011,
}

type_i_load = {
    "lb":  0b000,
    "lh":  0b001,
    "lw":   0b010,
    "lbu":  0b100,
    "lhu":  0b101,
}

type_s = {
    "sb":  0b000,
    "sh":  0b001,
    "sw":   0b010,
}

type_b = {
    "beq":  0b000,
    "bne":  0b001,
    "blt":   0b010,
    "bge":  0b100,
    "bltu":  0b101,
    "bgeu":  0b101,
}

tags = {"loop"}


def strip_comment(line: str) -> str:
    """Quita todo desde '#' hasta el final de la línea (el comentario)."""
    if "#" in line:
        return line[: line.index("#")].strip()
    return line.strip()

def int_to_bin(value, bin_size):
    if isinstance(value, str):
        value = int(value.strip().lstrip("x"))

    # Si es negativo, aplicar complemento a 2 con máscara del tamaño correcto
    if value < 0:
        value = value & ((1 << bin_size) - 1)

    return format(value, f'0{bin_size}b')

def type_r_instruction(line):
    instruction_rd, rs1, rs2 = line.strip().split(",")
    instruction, rd = instruction_rd.split(" ")

    func3, func7 = type_r[instruction]

    rd_bin = int_to_bin(rd, 5)
    rs1_bin = int_to_bin(rs1, 5)
    rs2_bin = int_to_bin(rs2, 5)
    func3_bin = int_to_bin(func3, 3)
    func7_bin = int_to_bin(func7, 7)

    return f"{func7_bin}{rs2_bin}{rs1_bin}{func3_bin}{rd_bin}0110011\n"

def type_i_instruction(line):
    instruction_rd, rs1, imm = line.strip().split(",")
    instruction, rd = instruction_rd.split(" ")

    func3 = type_i[instruction]

    rd_bin = int_to_bin(rd, 5)
    rs1_bin = int_to_bin(rs1, 5)
    imm_bin = ""

    if instruction == "srai":
        imm_bin = int_to_bin(int(imm, 0), 5)
        imm_bin = f"0100000{imm_bin}"
    else:
        imm_bin = int_to_bin(int(imm, 0), 12)

    func3_bin = int_to_bin(func3, 3)

    return f"{imm_bin}{rs1_bin}{func3_bin}{rd_bin}0010011\n"

def type_i_load_instruction(line):
    instruction_rd, offset = line.strip().split(",")
    instruction, rd = instruction_rd.split(" ")
    imm, rs1 = offset.split("(")
    rs1 = rs1.rstrip(")")

    func3 = type_i_load[instruction]

    # Calculamos binarios
    imm_bin = int_to_bin(imm, 12)
    rs1_bin = int_to_bin(rs1, 5)
    func3_bin = int_to_bin(func3, 3)
    rd_bin = int_to_bin(rd, 5)

    return f"{imm_bin}{rs1_bin}{func3_bin}{rd_bin}0000011\n"

def type_s_instriction(line):
    instruction_rs2, offset = line.strip().split(",")
    instruction, rs2 = instruction_rs2.split(" ")
    imm, rs1 = offset.split("(")
    rs1 = rs1.rstrip(")")

    func3 = type_s[instruction]

    # Calculamos binarios
    imm_bin = int_to_bin(imm, 12)
    rs1_bin = int_to_bin(rs1, 5)
    rs2_bin = int_to_bin(rs2, 5)
    func3_bin = int_to_bin(func3, 3)

    return f"{imm_bin[0:7]}{rs2_bin}{rs1_bin}{func3_bin}{imm_bin[7:12]}0100011\n"

def read_assembler_lines(source_lines):
    """Mapear el array source_lines separar instrucciones"""
    binary_program = ""

    for line_number in range(len(source_lines)):
        line = source_lines[line_number]
        instruction = line.strip().split(" ")[0]

        if instruction in type_r:
            binary_program += type_r_instruction(line)
        elif instruction in type_i:
            binary_program += type_i_instruction(line)
        elif instruction in type_i_load:
            binary_program += type_i_load_instruction(line)
        elif instruction in type_s:
            binary_program += type_s_instriction(line)

    return binary_program


def main() -> None:
    if len(sys.argv) != 4:
        print("Uso: python assembler.py <entrada.asm> <salida.hex> <salida.bin>", file=sys.stderr)
        sys.exit(1)

    asm_path = sys.argv[1]
    hex_path = sys.argv[2]
    bin_path = sys.argv[3]

    with open(asm_path, "r", encoding="utf-8") as f:
        # Array que guarda cada linea
        source_lines = f.readlines()

    print("Lineas de assembler\n")
    print(source_lines)

    binary_program = read_assembler_lines(source_lines)


    # Placeholder: escribiremos hex_path y bin_path en pasos posteriores
    with open(hex_path, "w", encoding="utf-8") as f:
        f.write("")
    with open(bin_path, "w") as f:
        f.write(binary_program)


if __name__ == "__main__":
    main()
