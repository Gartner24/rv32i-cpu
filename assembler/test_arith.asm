maximo:
        addi    sp,sp,-32
        sw      ra,28(sp)
        sw      s0,24(sp)
        addi    s0,sp,32
        sw      a0,-20(s0)
        sw      a1,-24(s0)
        lw      a4,-20(s0)
        lw      a5,-24(s0)
        ble     a4,a5,.L2
        lw      a5,-20(s0)
        j       .L3
.L2:
        lw      a5,-24(s0)
.L3:
        mv      a0,a5
        lw      ra,28(sp)
        lw      s0,24(sp)
        addi    sp,sp,32
        jr      ra
minimo:
        addi    sp,sp,-32
        sw      ra,28(sp)
        sw      s0,24(sp)
        addi    s0,sp,32
        sw      a0,-20(s0)
        sw      a1,-24(s0)
        lw      a4,-20(s0)
        lw      a5,-24(s0)
        bge     a4,a5,.L5
        lw      a5,-20(s0)
        j       .L6
.L5:
        lw      a5,-24(s0)
.L6:
        mv      a0,a5
        lw      ra,28(sp)
        lw      s0,24(sp)
        addi    sp,sp,32
        jr      ra
valor_abs:
        addi    sp,sp,-32
        sw      ra,28(sp)
        sw      s0,24(sp)
        addi    s0,sp,32
        sw      a0,-20(s0)
        lw      a5,-20(s0)
        bge     a5,zero,.L8
        lw      a5,-20(s0)
        neg     a5,a5
        j       .L9
.L8:
        lw      a5,-20(s0)
.L9:
        mv      a0,a5
        lw      ra,28(sp)
        lw      s0,24(sp)
        addi    sp,sp,32
        jr      ra
main:
        addi    sp,sp,-16
        sw      ra,12(sp)
        sw      s0,8(sp)
        addi    s0,sp,16
        li      a1,7
        li      a0,3
        call    maximo
        mv      a4,a0
        li      a5,7
        beq     a4,a5,.L11
        li      a5,-1
        j       .L12
.L11:
        li      a1,2
        li      a0,10
        call    maximo
        mv      a4,a0
        li      a5,10
        beq     a4,a5,.L13
        li      a5,-2
        j       .L12
.L13:
        li      a1,-1
        li      a0,-5
        call    maximo
        mv      a4,a0
        li      a5,-1
        beq     a4,a5,.L14
        li      a5,-3
        j       .L12
.L14:
        li      a1,7
        li      a0,3
        call    minimo
        mv      a4,a0
        li      a5,3
        beq     a4,a5,.L15
        li      a5,-4
        j       .L12
.L15:
        li      a1,-1
        li      a0,-5
        call    minimo
        mv      a4,a0
        li      a5,-5
        beq     a4,a5,.L16
        li      a5,-5
        j       .L12
.L16:
        li      a0,-42
        call    valor_abs
        mv      a4,a0
        li      a5,42
        beq     a4,a5,.L17
        li      a5,-6
        j       .L12
.L17:
        li      a0,42
        call    valor_abs
        mv      a4,a0
        li      a5,42
        beq     a4,a5,.L18
        li      a5,-7
        j       .L12
.L18:
        li      a0,0
        call    valor_abs
        mv      a5,a0
        beq     a5,zero,.L19
        li      a5,-8
        j       .L12
.L19:
        li      a5,0
.L12:
        mv      a0,a5
        lw      ra,12(sp)
        lw      s0,8(sp)
        addi    sp,sp,16
        jr      ra
