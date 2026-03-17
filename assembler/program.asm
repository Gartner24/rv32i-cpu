start:
        addi    sp, sp, -48
        sw      ra, 44(sp)
        sw      s0, 40(sp)
        addi    s0, sp, 48
        sw      a0, -36(s0)

# Tipo R
type_r_test:
        add     a5, a4, a3
        sub     a5, a4, a3
        xor     a5, a4, a3
        or      a5, a4, a3
        and     a5, a4, a3
        sll     a5, a4, a3
        srl     a5, a4, a3
        sra     a5, a4, a3
        slt     a5, a4, a3
        sltu    a5, a4, a3

# Tipo I
type_i_test:
        addi    a5, a4, 10
        xori    a5, a4, 0xff
        ori     a5, a4, 7
        andi    a5, a4, -1
        slli    a5, a4, 3
        srli    a5, a4, 3
        srai    a5, a4, 3
        slti    a5, a4, 5
        sltiu   a5, a4, 5

# Tipo I load
type_i_load_test:
        lb      a5, 0(a4)
        lh      a5, 2(a4)
        lw      a5, 4(a4)
        lbu     a5, 0(a4)
        lhu     a5, 2(a4)

# Tipo S
type_s_test:
        sb      a5, 0(a4)
        sh      a5, 2(a4)
        sw      a5, 4(a4)

# Tipo B
type_b_test:
        beq     a4, a5, end
        bne     a4, a5, end
        blt     a4, a5, end
        bge     a4, a5, end
        bltu    a4, a5, end
        bgeu    a4, a5, end

# Tipo J
type_j_test:
        jal     ra, end

# Tipo U
type_u_test:
        lui     a5, 0x10000
        auipc   a5, 0x10000

# jalr
        jalr    ra, ra, 0

# ecall / ebreak
        ecall
        ebreak

end:
        lw      ra, 44(sp)
        lw      s0, 40(sp)
        addi    sp, sp, 48
        jalr    zero, ra, 0
