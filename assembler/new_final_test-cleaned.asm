jal x0, 8
jal x0, 20
addi sp, x0, 1024
auipc x6, 0
jalr x1, x6, 364
ebreak
addi x10, x0, 0x123
jal x0, -4
addi    sp,sp,-32
sw      ra,28(sp)
sw      s0,24(sp)
addi    s0,sp,32
sw      a0,-20(s0)
sw      a1,-24(s0)
lw      a4,-20(s0)
lw      a5,-24(s0)
bge a5, a4, 12
lw      a5,-20(s0)
jal x0, 8
lw      a5,-24(s0)
addi a0, a5, 0
lw      ra,28(sp)
lw      s0,24(sp)
addi    sp,sp,32
jalr x0, ra, 0
addi    sp,sp,-48
sw      ra,44(sp)
sw      s0,40(sp)
addi    s0,sp,48
sw      a0,-36(s0)
lw      a5,-36(s0)
blt zero, a5, 12
addi a5, x0, 0
jal x0, 108
lw      a4,-36(s0)
addi a5, x0, 1
bne     a4,a5,12
addi a5, x0, 1
jal x0, 88
sw      zero,-20(s0)
addi a5, x0, 1
sw      a5,-24(s0)
addi a5, x0, 2
sw      a5,-28(s0)
jal x0, 48
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
lw      a4,-28(s0)
lw      a5,-36(s0)
bge a5, a4, -52
lw      a5,-24(s0)
addi a0, a5, 0
lw      ra,44(sp)
lw      s0,40(sp)
addi    sp,sp,48
jalr x0, ra, 0
addi    sp,sp,-48
sw      ra,44(sp)
sw      s0,40(sp)
addi    s0,sp,48
sw      a0,-36(s0)
sw      a1,-40(s0)
sw      zero,-20(s0)
sw      zero,-24(s0)
jal x0, 48
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
lw      a4,-24(s0)
lw      a5,-40(s0)
blt     a4,a5,-52
lw      a5,-20(s0)
addi a0, a5, 0
lw      ra,44(sp)
lw      s0,40(sp)
addi    sp,sp,48
jalr x0, ra, 0
addi    sp,sp,-48
sw      ra,44(sp)
sw      s0,40(sp)
addi    s0,sp,48
addi a1, x0, 42
addi a0, x0, 10
auipc x6, 0
jalr x1, x6, -368
addi a4, a0, 0
addi a5, x0, 42
beq     a4,a5,12
addi a5, x0, -1
jal x0, 208
addi a1, x0, 10
addi a0, x0, 42
auipc x6, 0
jalr x1, x6, -404
addi a4, a0, 0
addi a5, x0, 42
beq     a4,a5,12
addi a5, x0, -2
jal x0, 172
addi a0, x0, 8
auipc x6, 0
jalr x1, x6, -368
addi a4, a0, 0
addi a5, x0, 21
beq     a4,a5,12
addi a5, x0, -3
jal x0, 140
addi a0, x0, 1
auipc x6, 0
jalr x1, x6, -400
addi a4, a0, 0
addi a5, x0, 1
beq     a4,a5,12
addi a5, x0, -4
jal x0, 108
addi a5, x0, 10
sw      a5,-36(s0)
addi a5, x0, 20
sw      a5,-32(s0)
addi a5, x0, 30
sw      a5,-28(s0)
addi a5, x0, 40
sw      a5,-24(s0)
addi a5, x0, 50
sw      a5,-20(s0)
addi    a5,s0,-36
addi a1, x0, 5
addi a0, a5, 0
auipc x6, 0
jalr x1, x6, -320
addi a4, a0, 0
addi a5, x0, 150
beq     a4,a5,12
addi a5, x0, -5
jal x0, 28
lw      a4,-28(s0)
addi a5, x0, 30
beq     a4,a5,12
addi a5, x0, -6
jal x0, 8
addi a5, x0, 0
addi a0, a5, 0
lw      ra,44(sp)
lw      s0,40(sp)
addi    sp,sp,48
jalr x0, ra, 0
