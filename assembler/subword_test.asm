# subword_test.asm - verifica lb/lh/lbu/lhu/sb/sh con extension de signo/cero
# y que las escrituras por byte no pisan los bytes vecinos.
# main devuelve a0 = 0 si todo pasa, o un codigo de error distinto de 0.
# Nota: los valores negativos se cargan con addi ...,zero,-N (el li del
# ensamblador desborda con constantes 0xFFFFxxxx).
main:
        addi    sp,sp,-32

        # --- sb / lb (signo) / lbu (cero) con byte 0x80 ---
        li      a0,0x80
        sb      a0,0(sp)
        lb      a1,0(sp)
        addi    a2,zero,-128
        bne     a1,a2,.fail1
        lbu     a1,0(sp)
        addi    a2,zero,128
        bne     a1,a2,.fail2

        # --- sh / lh (signo) / lhu (cero) con half 0xFF80 ---
        li      a0,0xFF80
        sh      a0,4(sp)
        lh      a1,4(sp)
        addi    a2,zero,-128
        bne     a1,a2,.fail3
        lhu     a1,4(sp)
        li      a2,0xFF80
        bne     a1,a2,.fail4

        # --- sb en byte 1: no debe pisar el resto de la palabra ---
        li      a0,0
        sw      a0,8(sp)
        li      a0,0xAA
        sb      a0,9(sp)
        lw      a1,8(sp)
        li      a2,0xAA00
        bne     a1,a2,.fail5

        # --- sb en byte 3 (mas alto) ---
        li      a0,0
        sw      a0,12(sp)
        li      a0,0xEF
        sb      a0,15(sp)
        lbu     a1,15(sp)
        addi    a2,zero,239
        bne     a1,a2,.fail6
        lw      a1,12(sp)
        li      a2,0xEF000000
        bne     a1,a2,.fail7

        li      a0,0
        j       .done
.fail1:
        li      a0,1
        j       .done
.fail2:
        li      a0,2
        j       .done
.fail3:
        li      a0,3
        j       .done
.fail4:
        li      a0,4
        j       .done
.fail5:
        li      a0,5
        j       .done
.fail6:
        li      a0,6
        j       .done
.fail7:
        li      a0,7
.done:
        addi    sp,sp,32
        ret
