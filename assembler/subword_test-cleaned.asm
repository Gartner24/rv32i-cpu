jal x0, 8
jal x0, 20
addi sp, x0, 1024
auipc x6, 0
jalr x1, x6, 20
ebreak
addi x10, x0, 0x123
jal x0, -4
addi    sp,sp,-32
addi a0, x0, 0x80
sb      a0,0(sp)
lb      a1,0(sp)
addi    a2,zero,-128
bne     a1,a2,140
lbu     a1,0(sp)
addi    a2,zero,128
bne     a1,a2,136
lui a0, 16
addi a0, a0, -128
sh      a0,4(sp)
lh      a1,4(sp)
addi    a2,zero,-128
bne     a1,a2,120
lhu     a1,4(sp)
lui a2, 16
addi a2, a2, -128
bne     a1,a2,112
addi a0, x0, 0
sw      a0,8(sp)
addi a0, x0, 0xAA
sb      a0,9(sp)
lw      a1,8(sp)
lui a2, 11
addi a2, a2, -1536
bne     a1,a2,88
addi a0, x0, 0
sw      a0,12(sp)
addi a0, x0, 0xEF
sb      a0,15(sp)
lbu     a1,15(sp)
addi    a2,zero,239
bne     a1,a2,68
lw      a1,12(sp)
lui a2, 978944
addi a2, a2, 0
bne     a1,a2,60
addi a0, x0, 0
jal x0, 56
addi a0, x0, 1
jal x0, 48
addi a0, x0, 2
jal x0, 40
addi a0, x0, 3
jal x0, 32
addi a0, x0, 4
jal x0, 24
addi a0, x0, 5
jal x0, 16
addi a0, x0, 6
jal x0, 8
addi a0, x0, 7
addi    sp,sp,32
jalr x0, x1, 0
