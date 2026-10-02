jal x0, 8
jal x0, 20
addi sp, x0, 1024
auipc x6, 0
jalr x1, x6, 156
ebreak
addi x10, x0, 0x123
jal x0, -4
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
addi a0, a5, 0
lw      ra,28(sp)
lw      s0,24(sp)
addi    sp,sp,32
jalr x0, ra, 0
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
addi x0, x0, 0
lw      ra,28(sp)
lw      s0,24(sp)
addi    sp,sp,32
jalr x0, ra, 0
addi    sp,sp,-64
sw      ra,60(sp)
sw      s0,56(sp)
addi    s0,sp,64
addi a5, x0, 42
sw      a5,-52(s0)
lw      a4,-52(s0)
addi a5, x0, 42
beq     a4,a5,12
addi a5, x0, -1
jal x0, 256
addi a5, x0, 3
sw      a5,-20(s0)
lw      a4,-20(s0)
addi    a5,s0,-52
slli    a4,a4,2
add     a5,a4,a5
addi a4, x0, 99
sw      a4,0(a5)
lw      a4,-20(s0)
addi    a5,s0,-52
slli    a4,a4,2
add     a5,a4,a5
lw      a4,0(a5)
addi a5, x0, 99
beq     a4,a5,12
addi a5, x0, -2
jal x0, 188
addi    a5,s0,-52
addi a2, x0, 77
addi a1, x0, 5
addi a0, a5, 0
auipc x6, 0
jalr x1, x6, -200
addi    a5,s0,-52
addi a1, x0, 5
addi a0, a5, 0
auipc x6, 0
jalr x1, x6, -284
addi a4, a0, 0
addi a5, x0, 77
beq     a4,a5,12
addi a5, x0, -3
jal x0, 124
addi a5, x0, 10
sw      a5,-48(s0)
addi a5, x0, 20
sw      a5,-44(s0)
addi a5, x0, 30
sw      a5,-40(s0)
lw      a4,-44(s0)
addi a5, x0, 20
beq     a4,a5,12
addi a5, x0, -4
jal x0, 80
lw      a4,-48(s0)
addi a5, x0, 10
beq     a4,a5,12
addi a5, x0, -5
jal x0, 60
lw      a4,-40(s0)
addi a5, x0, 30
beq     a4,a5,12
addi a5, x0, -6
jal x0, 40
sw      zero,-52(s0)
addi a5, x0, 55
sw      a5,-52(s0)
lw      a4,-52(s0)
addi a5, x0, 55
beq     a4,a5,12
addi a5, x0, -7
jal x0, 8
addi a5, x0, 0
addi a0, a5, 0
lw      ra,60(sp)
lw      s0,56(sp)
addi    sp,sp,64
jalr x0, ra, 0
