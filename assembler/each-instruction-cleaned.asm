jal x0, 8
jal x0, 20
addi sp, x0, 1024
auipc x6, 0
jalr x1, x6, 20
ebreak
addi x10, x0, 0x123
jal x0, -4
addi    x1, zero, 10
addi    x2, zero, 3
add     x3,  x1, x2
sub     x4,  x1, x2
xor     x5,  x1, x2
or      x6,  x1, x2x
and     x7,  x1, x2
sll     x8,  x1, x2
srl     x9,  x1, x2
sra     x10, x1, x2
slt     x11, x2, x1
sltu    x12, x2, x1
xori    x13, x1, 6
ori     x14, x1, 5
andi    x15, x1, 6
slli    x16, x1, 2
srli    x17, x1, 1
srai    x18, x1, 1
slti    x19, x1, 20
sltiu   x20, x1, 20
lui     x21, 0x12345
auipc   x22, 0
addi    x23, zero, 0x40
sw      x1, 0(x23)
lw      x24, 0(x23)
addi    x25, zero, -1
sb      x25, 4(x23)
lb      x26, 4(x23)
lbu     x27, 4(x23)
sh      x25, 8(x23)
lh      x28, 8(x23)
lhu     x29, 8(x23)
addi    x30, zero, 5
addi    x31, zero, 5
beq     x30, x31, 4
bne     x30, x0,  4
blt     x0,  x30, 4
bge     x30, x0,  4
bltu    x0,  x30, 4
bgeu    x30, x0,  4
ecall
jal     x5, 8
ebreak
jalr    x0, x5, 0
