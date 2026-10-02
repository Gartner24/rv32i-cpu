jal x0, 8
jal x0, 20
addi sp, x0, 1024
auipc x6, 0
jalr x1, x6, 220
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
addi    sp,sp,-32
sw      ra,28(sp)
sw      s0,24(sp)
addi    s0,sp,32
sw      a0,-20(s0)
sw      a1,-24(s0)
lw      a4,-20(s0)
lw      a5,-24(s0)
bge     a4,a5,12
lw      a5,-20(s0)
jal x0, 8
lw      a5,-24(s0)
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
lw      a5,-20(s0)
bge     a5,zero,16
lw      a5,-20(s0)
sub a5, x0, a5
jal x0, 8
lw      a5,-20(s0)
addi a0, a5, 0
lw      ra,28(sp)
lw      s0,24(sp)
addi    sp,sp,32
jalr x0, ra, 0
addi    sp,sp,-16
sw      ra,12(sp)
sw      s0,8(sp)
addi    s0,sp,16
addi a1, x0, 7
addi a0, x0, 3
auipc x6, 0
jalr x1, x6, -224
addi a4, a0, 0
addi a5, x0, 7
beq     a4,a5,12
addi a5, x0, -1
jal x0, 244
addi a1, x0, 2
addi a0, x0, 10
auipc x6, 0
jalr x1, x6, -260
addi a4, a0, 0
addi a5, x0, 10
beq     a4,a5,12
addi a5, x0, -2
jal x0, 208
addi a1, x0, -1
addi a0, x0, -5
auipc x6, 0
jalr x1, x6, -296
addi a4, a0, 0
addi a5, x0, -1
beq     a4,a5,12
addi a5, x0, -3
jal x0, 172
addi a1, x0, 7
addi a0, x0, 3
auipc x6, 0
jalr x1, x6, -264
addi a4, a0, 0
addi a5, x0, 3
beq     a4,a5,12
addi a5, x0, -4
jal x0, 136
addi a1, x0, -1
addi a0, x0, -5
auipc x6, 0
jalr x1, x6, -300
addi a4, a0, 0
addi a5, x0, -5
beq     a4,a5,12
addi a5, x0, -5
jal x0, 100
addi a0, x0, -42
auipc x6, 0
jalr x1, x6, -264
addi a4, a0, 0
addi a5, x0, 42
beq     a4,a5,12
addi a5, x0, -6
jal x0, 68
addi a0, x0, 42
auipc x6, 0
jalr x1, x6, -296
addi a4, a0, 0
addi a5, x0, 42
beq     a4,a5,12
addi a5, x0, -7
jal x0, 36
addi a0, x0, 0
auipc x6, 0
jalr x1, x6, -328
addi a5, a0, 0
beq     a5,zero,12
addi a5, x0, -8
jal x0, 8
addi a5, x0, 0
addi a0, a5, 0
lw      ra,12(sp)
lw      s0,8(sp)
addi    sp,sp,16
jalr x0, ra, 0
