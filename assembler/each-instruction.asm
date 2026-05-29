# each-instruction.asm - ejecuta UNA de cada instruccion RV32I que implementa
# esta CPU, para verificarlas paso a paso (modo step) en la FPGA.
#
# Convencion: el ensamblador inyecta el arranque (pone sp=0x400 y llama a main);
# este programa termina con ebreak (HALT). Los resultados quedan en x1..x31 y en
# la memoria de datos (base 0x40 = palabra 16, pagina 0, visible por defecto).
#
# Cuidados del ensamblador: li desborda con 0xFFFFxxxx (se usa addi rd,zero,-N);
# cada etiqueta va en su propia linea.
main:
        # ---------- valores de partida ----------
        addi    x1, zero, 10          # x1 = 10  (ADDI)
        addi    x2, zero, 3           # x2 = 3

        # ---------- R-type ----------
        add     x3,  x1, x2           # 13
        sub     x4,  x1, x2           # 7
        xor     x5,  x1, x2           # 9
        or      x6,  x1, x2           # 11
        and     x7,  x1, x2           # 2
        sll     x8,  x1, x2           # 10<<3 = 80
        srl     x9,  x1, x2           # 10>>3 = 1
        sra     x10, x1, x2           # 10>>>3 = 1
        slt     x11, x2, x1           # 3<10  = 1
        sltu    x12, x2, x1           # 3<10  = 1 (sin signo)

        # ---------- I-type aritmetico ----------
        xori    x13, x1, 6            # 10^6 = 12
        ori     x14, x1, 5           # 10|5 = 15
        andi    x15, x1, 6           # 10&6 = 2
        slli    x16, x1, 2           # 10<<2 = 40
        srli    x17, x1, 1           # 10>>1 = 5
        srai    x18, x1, 1           # 10>>>1 = 5
        slti    x19, x1, 20          # 10<20 = 1
        sltiu   x20, x1, 20          # 10<20 = 1 (sin signo)

        # ---------- LUI / AUIPC ----------
        lui     x21, 0x12345          # x21 = 0x12345000
        auipc   x22, 0                # x22 = PC de esta instruccion

        # ---------- memoria: base en x23 = 0x40 (palabra 16) ----------
        addi    x23, zero, 0x40
        sw      x1, 0(x23)            # M[0x40] = 10            (SW)
        lw      x24, 0(x23)           # x24 = 10                (LW)
        addi    x25, zero, -1         # x25 = 0xFFFFFFFF
        sb      x25, 4(x23)           # M[0x44] byte 0 = 0xFF   (SB)
        lb      x26, 4(x23)           # x26 = -1 (extiende signo)   (LB)
        lbu     x27, 4(x23)           # x27 = 0xFF (extiende cero)  (LBU)
        sh      x25, 8(x23)           # M[0x48] half = 0xFFFF   (SH)
        lh      x28, 8(x23)           # x28 = -1 (signo)            (LH)
        lhu     x29, 8(x23)           # x29 = 0xFFFF (cero)         (LHU)

        # ---------- saltos condicionales (todos TOMADOS hacia la linea siguiente
        # = PC+4: el salto se nota por flush, y el flujo continua) ----------
        addi    x30, zero, 5
        addi    x31, zero, 5
        beq     x30, x31, l_bne       # 5==5  -> tomado          (BEQ)
l_bne:
        bne     x30, x0,  l_blt       # 5!=0  -> tomado          (BNE)
l_blt:
        blt     x0,  x30, l_bge       # 0<5   -> tomado          (BLT)
l_bge:
        bge     x30, x0,  l_bltu      # 5>=0  -> tomado          (BGE)
l_bltu:
        bltu    x0,  x30, l_bgeu      # 0<5   -> tomado          (BLTU)
l_bgeu:
        bgeu    x30, x0,  l_sys       # 5>=0  -> tomado          (BGEU)
l_sys:
        # ---------- ECALL: esta CPU no atrapa; se comporta como NOP ----------
        ecall

        # ---------- JAL / JALR ----------
        jal     x5, j_target          # x5 = PC+4 (= dir. de halt), salta a j_target (JAL)
halt:
        ebreak                        # HALT (se llega aqui por el jalr)
j_target:
        jalr    x0, x5, 0             # salta a x5 = halt                         (JALR)
