jal x0, 8
jal x0, 20
addi sp, x0, 1024
auipc x6, 0
jalr x1, x6, 20
ebreak
addi x10, x0, 0x123
jal x0, -4
addi    x1, zero, 0x40
addi    x2, zero, 5
sw      x2, 0(x1)
addi    x2, zero, 10
sw      x2, 4(x1)
addi    x2, zero, 15
sw      x2, 8(x1)
addi    x2, zero, 20
sw      x2, 12(x1)
addi    x3, zero, 0
addi    x4, zero, 0
addi    x5, zero, 16
add     x6, x1, x4
lw      x7, 0(x6)
add     x3, x3, x7
addi    x4, x4, 4
blt     x4, x5, -16
sw      x3, 16(x1)
addi    x10, zero, 0
ebreak
