jal x0, 8
jal x0, 20
addi sp, x0, 1024
auipc x6, 0
jalr x1, x6, 280
ebreak
addi x10, x0, 0x123
jal x0, -4
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
sw      zero,-20(s0)
addi a5, x0, 1
sw      a5,-24(s0)
jal x0, 32
lw      a4,-20(s0)
lw      a5,-24(s0)
add     a5,a4,a5
sw      a5,-20(s0)
lw      a5,-24(s0)
addi    a5,a5,1
sw      a5,-24(s0)
lw      a4,-24(s0)
lw      a5,-36(s0)
bge a5, a4, -36
lw      a5,-20(s0)
addi a0, a5, 0
lw      ra,44(sp)
lw      s0,40(sp)
addi    sp,sp,48
jalr x0, ra, 0
addi    sp,sp,-16
sw      ra,12(sp)
sw      s0,8(sp)
addi    s0,sp,16
addi a0, x0, 0
auipc x6, 0
jalr x1, x6, -280
addi a5, a0, 0
beq     a5,zero,12
addi a5, x0, -1
jal x0, 196
addi a0, x0, 1
auipc x6, 0
jalr x1, x6, -308
addi a4, a0, 0
addi a5, x0, 1
beq     a4,a5,12
addi a5, x0, -2
jal x0, 164
addi a0, x0, 6
auipc x6, 0
jalr x1, x6, -340
addi a4, a0, 0
addi a5, x0, 8
beq     a4,a5,12
addi a5, x0, -3
jal x0, 132
addi a0, x0, 10
auipc x6, 0
jalr x1, x6, -372
addi a4, a0, 0
addi a5, x0, 55
beq     a4,a5,12
addi a5, x0, -4
jal x0, 100
addi a0, x0, 10
auipc x6, 0
jalr x1, x6, -244
addi a4, a0, 0
addi a5, x0, 55
beq     a4,a5,12
addi a5, x0, -5
jal x0, 68
addi a0, x0, 1
auipc x6, 0
jalr x1, x6, -276
addi a4, a0, 0
addi a5, x0, 1
beq     a4,a5,12
addi a5, x0, -6
jal x0, 36
addi a0, x0, 0
auipc x6, 0
jalr x1, x6, -308
addi a5, a0, 0
beq     a5,zero,12
addi a5, x0, -7
jal x0, 8
addi a5, x0, 0
addi a0, a5, 0
lw      ra,12(sp)
lw      s0,8(sp)
addi    sp,sp,16
jalr x0, ra, 0
