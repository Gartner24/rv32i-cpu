jal x0, 8
jal x0, 20
addi sp, x0, 1024
auipc x6, 0
jalr x1, x6, 76
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
add     a5,a4,a5
addi a0, a5, 0
lw      ra,28(sp)
lw      s0,24(sp)
addi    sp,sp,32
jalr x0, ra, 0
addi    sp,sp,-32
sw      ra,28(sp)
sw      s0,24(sp)
addi    s0,sp,32
addi a1, x0, 2
addi a0, x0, 2
auipc x6, 0
jalr x1, x6, -80
sw      a0,-20(s0)
lw      a5,-20(s0)
addi a0, a5, 0
lw      ra,28(sp)
lw      s0,24(sp)
addi    sp,sp,32
jalr x0, ra, 0
