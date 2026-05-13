leer:
        addi    sp,sp,-32
        sw      ra,28(sp)
        sw      s0,24(sp)
        addi    s0,sp,32
        sw      a0,-20(s0)
        sw      a1,-24(s0)
        lw      a5,-24(s0)
        slli    a5,a5,2
        lw      a4,-20(s0)
        add     a5,a4,a5
        lw      a5,0(a5)
        mv      a0,a5
        lw      ra,28(sp)
        lw      s0,24(sp)
        addi    sp,sp,32
        jr      ra
escribir:
        addi    sp,sp,-32
        sw      ra,28(sp)
        sw      s0,24(sp)
        addi    s0,sp,32
        sw      a0,-20(s0)
        sw      a1,-24(s0)
        sw      a2,-28(s0)
        lw      a5,-24(s0)
        slli    a5,a5,2
        lw      a4,-20(s0)
        add     a5,a4,a5
        lw      a4,-28(s0)
        sw      a4,0(a5)
        nop
        lw      ra,28(sp)
        lw      s0,24(sp)
        addi    sp,sp,32
        jr      ra
main:
        addi    sp,sp,-64
        sw      ra,60(sp)
        sw      s0,56(sp)
        addi    s0,sp,64
        li      a5,42
        sw      a5,-52(s0)
        lw      a4,-52(s0)
        li      a5,42
        beq     a4,a5,.L5
        li      a5,-1
        j       .L13
.L5:
        li      a5,3
        sw      a5,-20(s0)
        lw      a4,-20(s0)
        addi    a5,s0,-52
        slli    a4,a4,2
        add     a5,a4,a5
        li      a4,99
        sw      a4,0(a5)
        lw      a4,-20(s0)
        addi    a5,s0,-52
        slli    a4,a4,2
        add     a5,a4,a5
        lw      a4,0(a5)
        li      a5,99
        beq     a4,a5,.L7
        li      a5,-2
        j       .L13
.L7:
        addi    a5,s0,-52
        li      a2,77
        li      a1,5
        mv      a0,a5
        call    escribir
        addi    a5,s0,-52
        li      a1,5
        mv      a0,a5
        call    leer
        mv      a4,a0
        li      a5,77
        beq     a4,a5,.L8
        li      a5,-3
        j       .L13
.L8:
        li      a5,10
        sw      a5,-48(s0)
        li      a5,20
        sw      a5,-44(s0)
        li      a5,30
        sw      a5,-40(s0)
        lw      a4,-44(s0)
        li      a5,20
        beq     a4,a5,.L9
        li      a5,-4
        j       .L13
.L9:
        lw      a4,-48(s0)
        li      a5,10
        beq     a4,a5,.L10
        li      a5,-5
        j       .L13
.L10:
        lw      a4,-40(s0)
        li      a5,30
        beq     a4,a5,.L11
        li      a5,-6
        j       .L13
.L11:
        sw      zero,-52(s0)
        li      a5,55
        sw      a5,-52(s0)
        lw      a4,-52(s0)
        li      a5,55
        beq     a4,a5,.L12
        li      a5,-7
        j       .L13
.L12:
        li      a5,0
.L13:
        mv      a0,a5
        lw      ra,60(sp)
        lw      s0,56(sp)
        addi    sp,sp,64
        jr      ra
