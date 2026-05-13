fibonacci:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        lw      a5,-36(s0)
        bgt     a5,zero,.L2
        li      a5,0
        j       .L3
.L2:
        lw      a4,-36(s0)
        li      a5,1
        bne     a4,a5,.L4
        li      a5,1
        j       .L3
.L4:
        sw      zero,-20(s0)
        li      a5,1
        sw      a5,-24(s0)
        li      a5,2
        sw      a5,-28(s0)
        j       .L5
.L6:
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
.L5:
        lw      a4,-28(s0)
        lw      a5,-36(s0)
        ble     a4,a5,.L6
        lw      a5,-24(s0)
.L3:
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
suma_hasta:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      zero,-20(s0)
        li      a5,1
        sw      a5,-24(s0)
        j       .L8
.L9:
        lw      a4,-20(s0)
        lw      a5,-24(s0)
        add     a5,a4,a5
        sw      a5,-20(s0)
        lw      a5,-24(s0)
        addi    a5,a5,1
        sw      a5,-24(s0)
.L8:
        lw      a4,-24(s0)
        lw      a5,-36(s0)
        ble     a4,a5,.L9
        lw      a5,-20(s0)
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
main:
        addi    sp,sp,-16
        sw      ra,12(sp)
        sw      s0,8(sp)
        addi    s0,sp,16
        li      a0,0
        call    fibonacci
        mv      a5,a0
        beq     a5,zero,.L12
        li      a5,-1
        j       .L13
.L12:
        li      a0,1
        call    fibonacci
        mv      a4,a0
        li      a5,1
        beq     a4,a5,.L14
        li      a5,-2
        j       .L13
.L14:
        li      a0,6
        call    fibonacci
        mv      a4,a0
        li      a5,8
        beq     a4,a5,.L15
        li      a5,-3
        j       .L13
.L15:
        li      a0,10
        call    fibonacci
        mv      a4,a0
        li      a5,55
        beq     a4,a5,.L16
        li      a5,-4
        j       .L13
.L16:
        li      a0,10
        call    suma_hasta
        mv      a4,a0
        li      a5,55
        beq     a4,a5,.L17
        li      a5,-5
        j       .L13
.L17:
        li      a0,1
        call    suma_hasta
        mv      a4,a0
        li      a5,1
        beq     a4,a5,.L18
        li      a5,-6
        j       .L13
.L18:
        li      a0,0
        call    suma_hasta
        mv      a5,a0
        beq     a5,zero,.L19
        li      a5,-7
        j       .L13
.L19:
        li      a5,0
.L13:
        mv      a0,a5
        lw      ra,12(sp)
        lw      s0,8(sp)
        addi    sp,sp,16
        jr      ra
