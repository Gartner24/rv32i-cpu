addi    sp,sp,-48
sw      ra,44(sp)
sw      s0,40(sp)
addi    s0,sp,48
sw      a0,-36(s0)
sw      a1,-40(s0)
sw      zero,-20(s0)
sw      zero,-24(s0)
sw      zero,-28(s0)
lw      a5,-36(s0)
bge     a5,zero,28
lw      a5,-36(s0)
sub a5, x0, a5
sw      a5,-36(s0)
lw      a5,-28(s0)
addi    a5,a5,1
sw      a5,-28(s0)
lw      a5,-40(s0)
bge     a5,zero,60
lw      a5,-40(s0)
sub a5, x0, a5
sw      a5,-40(s0)
lw      a5,-28(s0)
addi    a5,a5,1
sw      a5,-28(s0)
jal x0, 32
lw      a4,-20(s0)
lw      a5,-36(s0)
add     a5,a4,a5
sw      a5,-20(s0)
lw      a5,-24(s0)
addi    a5,a5,1
sw      a5,-24(s0)
lw      a4,-24(s0)
lw      a5,-40(s0)
blt     a4,a5,-36
lw      a4,-28(s0)
addi a5, x0, 1
bne     a4,a5,16
lw      a5,-20(s0)
sub a5, x0, a5
jal x0, 8
lw      a5,-20(s0)
addi a0, a5, 0
lw      ra,44(sp)
lw      s0,40(sp)
addi    sp,sp,48
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
addi    sp,sp,-48
sw      ra,44(sp)
sw      s0,40(sp)
addi    s0,sp,48
sw      a0,-36(s0)
sw      a1,-40(s0)
sw      a2,-44(s0)
sw      zero,-20(s0)
jal x0, 52
lw      a5,-20(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a5,0(a5)
lw      a4,-44(s0)
bne     a4,a5,12
lw      a5,-20(s0)
jal x0, 32
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a4,-20(s0)
lw      a5,-40(s0)
blt     a4,a5,-56
addi a5, x0, -1
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
sw      a2,-44(s0)
sw      zero,-20(s0)
lw      a5,-40(s0)
addi    a5,a5,-1
sw      a5,-24(s0)
jal x0, 116
lw      a4,-20(s0)
lw      a5,-24(s0)
add     a5,a4,a5
srai    a5,a5,1
sw      a5,-28(s0)
lw      a5,-28(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a5,0(a5)
lw      a4,-44(s0)
bne     a4,a5,12
lw      a5,-28(s0)
jal x0, 76
lw      a5,-28(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a5,0(a5)
lw      a4,-44(s0)
bge a5, a4, 20
lw      a5,-28(s0)
addi    a5,a5,1
sw      a5,-20(s0)
jal x0, 16
lw      a5,-28(s0)
addi    a5,a5,-1
sw      a5,-24(s0)
lw      a4,-20(s0)
lw      a5,-24(s0)
bge a5, a4, -120
addi a5, x0, -1
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
sw      a2,-44(s0)
lw      a5,-40(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a5,0(a5)
sw      a5,-20(s0)
lw      a5,-44(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a4,a4,a5
lw      a5,-40(s0)
slli    a5,a5,2
lw      a3,-36(s0)
add     a5,a3,a5
lw      a4,0(a4)
sw      a4,0(a5)
lw      a5,-44(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a4,-20(s0)
sw      a4,0(a5)
addi x0, x0, 0
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
jal x0, 136
sw      zero,-24(s0)
jal x0, 92
lw      a5,-24(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a4,0(a5)
lw      a5,-24(s0)
addi    a5,a5,1
slli    a5,a5,2
lw      a3,-36(s0)
add     a5,a3,a5
lw      a5,0(a5)
bge a5, a4, 32
lw      a5,-24(s0)
addi    a5,a5,1
addi a2, a5, 0
lw      a1,-24(s0)
lw      a0,-36(s0)
auipc x6, 0
jalr x1, x6, -244
lw      a5,-24(s0)
addi    a5,a5,1
sw      a5,-24(s0)
lw      a4,-40(s0)
lw      a5,-20(s0)
sub     a5,a4,a5
addi    a5,a5,-1
lw      a4,-24(s0)
blt     a4,a5,-108
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a5,-40(s0)
addi    a5,a5,-1
lw      a4,-20(s0)
blt     a4,a5,-144
addi x0, x0, 0
addi x0, x0, 0
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
jal x0, 148
lw      a5,-20(s0)
sw      a5,-24(s0)
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-28(s0)
jal x0, 68
lw      a5,-28(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a4,0(a5)
lw      a5,-24(s0)
slli    a5,a5,2
lw      a3,-36(s0)
add     a5,a3,a5
lw      a5,0(a5)
bge     a4,a5,12
lw      a5,-28(s0)
sw      a5,-24(s0)
lw      a5,-28(s0)
addi    a5,a5,1
sw      a5,-28(s0)
lw      a4,-28(s0)
lw      a5,-40(s0)
blt     a4,a5,-72
lw      a4,-24(s0)
lw      a5,-20(s0)
beq     a4,a5,24
lw      a2,-24(s0)
lw      a1,-20(s0)
lw      a0,-36(s0)
auipc x6, 0
jalr x1, x6, -496
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a5,-40(s0)
addi    a5,a5,-1
lw      a4,-20(s0)
blt     a4,a5,-156
addi x0, x0, 0
addi x0, x0, 0
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
sw      a0,-36(s0)
sw      a1,-40(s0)
lw      a1,-40(s0)
lw      a0,-36(s0)
auipc x6, 0
jalr x1, x6, -148
sw      a0,-28(s0)
sw      zero,-20(s0)
sw      zero,-24(s0)
sw      zero,-32(s0)
jal x0, 32
lw      a4,-24(s0)
lw      a5,-40(s0)
add     a5,a4,a5
sw      a5,-24(s0)
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a4,-24(s0)
lw      a5,-40(s0)
add     a5,a4,a5
lw      a4,-28(s0)
bge     a4,a5,-44
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
sw      a0,-36(s0)
sw      a1,-40(s0)
sw      a2,-44(s0)
sw      zero,-20(s0)
sw      zero,-24(s0)
jal x0, 56
lw      a5,-24(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a5,0(a5)
lw      a4,-44(s0)
bne     a4,a5,16
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a5,-24(s0)
addi    a5,a5,1
sw      a5,-24(s0)
lw      a4,-24(s0)
lw      a5,-40(s0)
blt     a4,a5,-60
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
sw      a0,-36(s0)
sw      a1,-40(s0)
sw      zero,-20(s0)
lw      a5,-40(s0)
addi    a5,a5,-1
sw      a5,-24(s0)
jal x0, 48
lw      a2,-24(s0)
lw      a1,-20(s0)
lw      a0,-36(s0)
auipc x6, 0
jalr x1, x6, -988
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a5,-24(s0)
addi    a5,a5,-1
sw      a5,-24(s0)
lw      a4,-20(s0)
lw      a5,-24(s0)
blt     a4,a5,-52
addi x0, x0, 0
addi x0, x0, 0
lw      ra,44(sp)
lw      s0,40(sp)
addi    sp,sp,48
jalr x0, ra, 0
addi    sp,sp,-32
sw      ra,28(sp)
sw      s0,24(sp)
addi    s0,sp,32
sw      a0,-20(s0)
sw      a1,-24(s0)
lw      a5,-20(s0)
bge     a5,zero,16
lw      a5,-20(s0)
sub a5, x0, a5
sw      a5,-20(s0)
lw      a5,-24(s0)
bge     a5,zero,68
lw      a5,-24(s0)
sub a5, x0, a5
sw      a5,-24(s0)
jal x0, 52
lw      a4,-20(s0)
lw      a5,-24(s0)
bge a5, a4, 24
lw      a4,-20(s0)
lw      a5,-24(s0)
sub     a5,a4,a5
sw      a5,-20(s0)
jal x0, 20
lw      a4,-24(s0)
lw      a5,-20(s0)
sub     a5,a4,a5
sw      a5,-24(s0)
lw      a4,-20(s0)
lw      a5,-24(s0)
bne     a4,a5,-56
lw      a5,-20(s0)
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
sw      a1,-40(s0)
lw      a1,-40(s0)
lw      a0,-36(s0)
auipc x6, 0
jalr x1, x6, -184
sw      a0,-28(s0)
lw      a1,-40(s0)
lw      a0,-36(s0)
auipc x6, 0
jalr x1, x6, -1968
sw      a0,-32(s0)
sw      zero,-20(s0)
sw      zero,-24(s0)
jal x0, 32
lw      a4,-24(s0)
lw      a5,-28(s0)
add     a5,a4,a5
sw      a5,-24(s0)
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a4,-24(s0)
lw      a5,-28(s0)
add     a5,a4,a5
lw      a4,-32(s0)
bge     a4,a5,-44
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
sw      a0,-36(s0)
lw      a4,-36(s0)
addi a5, x0, 1
blt a5, a4, 12
addi a5, x0, 0
jal x0, 96
addi a5, x0, 2
sw      a5,-20(s0)
jal x0, 68
lw      a5,-36(s0)
sw      a5,-24(s0)
jal x0, 20
lw      a4,-24(s0)
lw      a5,-20(s0)
sub     a5,a4,a5
sw      a5,-24(s0)
lw      a5,-24(s0)
blt zero, a5, -20
lw      a5,-24(s0)
bne     a5,zero,12
addi a5, x0, 0
jal x0, 32
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a4,-20(s0)
lw      a5,-36(s0)
blt     a4,a5,-72
addi a5, x0, 1
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
addi    sp,sp,-64
sw      ra,60(sp)
sw      s0,56(sp)
addi    s0,sp,64
sw      a0,-52(s0)
lw      a5,-52(s0)
bge     a5,zero,12
addi a5, x0, -1
jal x0, 168
lw      a5,-52(s0)
bne     a5,zero,12
addi a5, x0, 0
jal x0, 152
addi a5, x0, 1
sw      a5,-20(s0)
lw      a5,-52(s0)
sw      a5,-24(s0)
sw      zero,-28(s0)
jal x0, 112
lw      a4,-20(s0)
lw      a5,-24(s0)
add     a5,a4,a5
srai    a5,a5,1
sw      a5,-32(s0)
lw      a1,-32(s0)
lw      a0,-32(s0)
auipc x6, -1
jalr x1, x6, 1616
sw      a0,-36(s0)
lw      a4,-36(s0)
lw      a5,-52(s0)
bne     a4,a5,12
lw      a5,-32(s0)
jal x0, 68
lw      a4,-36(s0)
lw      a5,-52(s0)
bge     a4,a5,28
lw      a5,-32(s0)
sw      a5,-28(s0)
lw      a5,-32(s0)
addi    a5,a5,1
sw      a5,-20(s0)
jal x0, 16
lw      a5,-32(s0)
addi    a5,a5,-1
sw      a5,-24(s0)
lw      a4,-20(s0)
lw      a5,-24(s0)
bge a5, a4, -116
lw      a5,-28(s0)
addi a0, a5, 0
lw      ra,60(sp)
lw      s0,56(sp)
addi    sp,sp,64
jalr x0, ra, 0
addi    sp,sp,-48
sw      ra,44(sp)
sw      s0,40(sp)
addi    s0,sp,48
sw      a0,-36(s0)
sw      zero,-20(s0)
sw      zero,-24(s0)
jal x0, 52
lw      a5,-36(s0)
andi    a5,a5,1
beq     a5,zero,16
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a5,-36(s0)
srai    a5,a5,1
sw      a5,-36(s0)
lw      a5,-24(s0)
addi    a5,a5,1
sw      a5,-24(s0)
lw      a4,-24(s0)
addi a5, x0, 31
bge a5, a4, -56
lw      a5,-20(s0)
addi a0, a5, 0
lw      ra,44(sp)
lw      s0,40(sp)
addi    sp,sp,48
jalr x0, ra, 0
addi    sp,sp,-32
sw      ra,28(sp)
sw      s0,24(sp)
addi    s0,sp,32
sw      a0,-20(s0)
lw      a5,-20(s0)
blt zero, a5, 12
addi a5, x0, 0
jal x0, 28
lw      a5,-20(s0)
addi    a4,a5,-1
lw      a5,-20(s0)
and     a5,a4,a5
sltiu a5, a5, 1
andi    a5,a5,0xff
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
sw      zero,-20(s0)
sw      zero,-24(s0)
jal x0, 48
lw      a5,-36(s0)
andi    a5,a5,1
beq     a5,zero,12
lw      a5,-24(s0)
sw      a5,-20(s0)
lw      a5,-36(s0)
srai    a5,a5,1
sw      a5,-36(s0)
lw      a5,-24(s0)
addi    a5,a5,1
sw      a5,-24(s0)
lw      a4,-24(s0)
addi a5, x0, 31
bge a5, a4, -52
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
sw      a0,-36(s0)
sw      zero,-20(s0)
jal x0, 16
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a5,-20(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a5,0(a5)
bne     a5,zero,-32
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
sw      a0,-36(s0)
sw      a1,-40(s0)
sw      zero,-20(s0)
jal x0, 120
lw      a5,-20(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a4,0(a5)
lw      a5,-20(s0)
slli    a5,a5,2
lw      a3,-40(s0)
add     a5,a3,a5
lw      a5,0(a5)
bge     a4,a5,12
addi a5, x0, -1
jal x0, 208
lw      a5,-20(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a4,0(a5)
lw      a5,-20(s0)
slli    a5,a5,2
lw      a3,-40(s0)
add     a5,a3,a5
lw      a5,0(a5)
bge a5, a4, 12
addi a5, x0, 1
jal x0, 156
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a5,-20(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a5,0(a5)
beq     a5,zero,28
lw      a5,-20(s0)
slli    a5,a5,2
lw      a4,-40(s0)
add     a5,a4,a5
lw      a5,0(a5)
bne     a5,zero,-160
lw      a5,-20(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a5,0(a5)
bne     a5,zero,36
lw      a5,-20(s0)
slli    a5,a5,2
lw      a4,-40(s0)
add     a5,a4,a5
lw      a5,0(a5)
bne     a5,zero,12
addi a5, x0, 0
jal x0, 40
lw      a5,-20(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a5,0(a5)
bne     a5,zero,12
addi a5, x0, -1
jal x0, 8
addi a5, x0, 1
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
jal x0, 56
lw      a5,-20(s0)
slli    a5,a5,2
lw      a4,-40(s0)
add     a4,a4,a5
lw      a5,-20(s0)
slli    a5,a5,2
lw      a3,-36(s0)
add     a5,a3,a5
lw      a4,0(a4)
sw      a4,0(a5)
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a5,-20(s0)
slli    a5,a5,2
lw      a4,-40(s0)
add     a5,a4,a5
lw      a5,0(a5)
bne     a5,zero,-72
lw      a5,-20(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
sw      zero,0(a5)
addi x0, x0, 0
lw      ra,44(sp)
lw      s0,40(sp)
addi    sp,sp,48
jalr x0, ra, 0
