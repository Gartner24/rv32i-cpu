jal x0, 8
jal x0, 20
addi sp, x0, 1024
auipc x6, 0
jalr x1, x6, 20
ebreak
addi x10, x0, 0x123
jal x0, -4
addi    sp,sp,-32
sw      ra,28(sp)
sw      s0,24(sp)
addi    s0,sp,32
addi a5, x0, -32
sw      a5,-20(s0)
lw      a5,-20(s0)
srai    a4,a5,2
addi a5, x0, -8
beq     a4,a5,12
addi a5, x0, -11
jal x0, 8
addi a5, x0, 0
addi a0, a5, 0
lw      ra,28(sp)
lw      s0,24(sp)
addi    sp,sp,32
jalr x0, ra, 0
