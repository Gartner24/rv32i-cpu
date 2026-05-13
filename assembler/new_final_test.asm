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
fibonacci:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        lw      a5,-36(s0)
        bgt     a5,zero,.L5
        li      a5,0
        j       .L6
.L5:
        lw      a4,-36(s0)
        li      a5,1
        bne     a4,a5,.L7
        li      a5,1
        j       .L6
.L7:
        sw      zero,-20(s0)
        li      a5,1
        sw      a5,-24(s0)
        li      a5,2
        sw      a5,-28(s0)
        j       .L8
.L9:
        lw      a4,-20(s0)
        lw      a5,-24(s0)
        add     a5,a4,a5
        sw      a5,-32(s0)
        lw      a5,-24(s0)
        sw      a5,-20(s0)
        lw      a5,-32(s0)
        sw      a5,-24(s0)
        lw      a5,-28(s0)
        addi    a5,a5,1
        sw      a5,-28(s0)
.L8:
        lw      a4,-28(s0)
        lw      a5,-36(s0)
        ble     a4,a5,.L9
        lw      a5,-24(s0)
.L6:
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
suma_array:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      a1,-40(s0)
        sw      zero,-20(s0)
        sw      zero,-24(s0)
        j       .L11
.L12:
        lw      a5,-24(s0)
        slli    a5,a5,2
        lw      a4,-36(s0)
        add     a5,a4,a5
        lw      a5,0(a5)
        lw      a4,-20(s0)
        add     a5,a4,a5
        sw      a5,-20(s0)
        lw      a5,-24(s0)
        addi    a5,a5,1
        sw      a5,-24(s0)
.L11:
        lw      a4,-24(s0)
        lw      a5,-40(s0)
        blt     a4,a5,.L12
        lw      a5,-20(s0)
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
main:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        li      a1,42
        li      a0,10
        call    maximo
        mv      a4,a0
        li      a5,42
        beq     a4,a5,.L15
        li      a5,-1
        j       .L22
.L15:
        li      a1,10
        li      a0,42
        call    maximo
        mv      a4,a0
        li      a5,42
        beq     a4,a5,.L17
        li      a5,-2
        j       .L22
.L17:
        li      a0,8
        call    fibonacci
        mv      a4,a0
        li      a5,21
        beq     a4,a5,.L18
        li      a5,-3
        j       .L22
.L18:
        li      a0,1
        call    fibonacci
        mv      a4,a0
        li      a5,1
        beq     a4,a5,.L19
        li      a5,-4
        j       .L22
.L19:
        li      a5,10
        sw      a5,-36(s0)
        li      a5,20
        sw      a5,-32(s0)
        li      a5,30
        sw      a5,-28(s0)
        li      a5,40
        sw      a5,-24(s0)
        li      a5,50
        sw      a5,-20(s0)
        addi    a5,s0,-36
        li      a1,5
        mv      a0,a5
        call    suma_array
        mv      a4,a0
        li      a5,150
        beq     a4,a5,.L20
        li      a5,-5
        j       .L22
.L20:
        lw      a4,-28(s0)
        li      a5,30
        beq     a4,a5,.L21
        li      a5,-6
        j       .L22
.L21:
        li      a5,0
.L22:
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
