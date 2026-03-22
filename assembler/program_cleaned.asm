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
jal x0, -3920
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a4,-20(s0)
lw      a5,-40(s0)
blt     a4,a5,-4161
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
jal x0, -4883
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
bne     a4,a5,-5364
lw      a5,-28(s0)
jal x0, -5445
lw      a5,-28(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a5,0(a5)
lw      a4,-44(s0)
bge a5, a4, -5726
lw      a5,-28(s0)
addi    a5,a5,1
sw      a5,-20(s0)
jal x0, -5883
lw      a5,-28(s0)
addi    a5,a5,-1
sw      a5,-24(s0)
lw      a4,-20(s0)
lw      a5,-24(s0)
bge a5, a4, -6127
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
auipc x1, 1048575
jalr x1, x1, 3852
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
beq     a4,a5,-10560
lw      a2,-24(s0)
lw      a1,-20(s0)
lw      a0,-36(s0)
auipc x1, 1048575
jalr x1, x1, 3600
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a5,-40(s0)
addi    a5,a5,-1
lw      a4,-20(s0)
blt     a4,a5,-11041
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
jal x0, -11643
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
blt     a4,a5,-12204
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
auipc x1, 1048575
jalr x1, x1, 3948
sw      a0,-28(s0)
sw      zero,-20(s0)
sw      zero,-24(s0)
sw      zero,-32(s0)
jal x0, -13047
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
bge     a4,a5,-13528
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
jal x0, -14441
lw      a5,-24(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a5,0(a5)
lw      a4,-44(s0)
bne     a4,a5,-14722
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a5,-24(s0)
addi    a5,a5,1
sw      a5,-24(s0)
lw      a4,-24(s0)
lw      a5,-40(s0)
blt     a4,a5,-15083
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
jal x0, -15766
lw      a2,-24(s0)
lw      a1,-20(s0)
lw      a0,-36(s0)
auipc x1, 1048575
jalr x1, x1, 3108
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a5,-24(s0)
addi    a5,a5,-1
sw      a5,-24(s0)
lw      a4,-20(s0)
lw      a5,-24(s0)
blt     a4,a5,-16327
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
bge     a5,zero,-16889
lw      a5,-20(s0)
sub a5, x0, a5
sw      a5,-20(s0)
lw      a5,-24(s0)
bge     a5,zero,-16441
lw      a5,-24(s0)
sub a5, x0, a5
sw      a5,-24(s0)
jal x0, -16601
lw      a4,-20(s0)
lw      a5,-24(s0)
bge a5, a4, -16722
lw      a4,-20(s0)
lw      a5,-24(s0)
sub     a5,a4,a5
sw      a5,-20(s0)
jal x0, -16921
lw      a4,-24(s0)
lw      a5,-20(s0)
sub     a5,a4,a5
sw      a5,-24(s0)
lw      a4,-20(s0)
lw      a5,-24(s0)
bne     a4,a5,-17203
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
auipc x1, 1048575
jalr x1, x1, 3912
sw      a0,-28(s0)
lw      a1,-40(s0)
lw      a0,-36(s0)
auipc x1, 1048575
jalr x1, x1, 2128
sw      a0,-32(s0)
sw      zero,-20(s0)
sw      zero,-24(s0)
jal x0, -18206
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
bge     a4,a5,-18687
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
blt a5, a4, -19200
addi a5, x0, 0
jal x0, -19281
addi a5, x0, 2
sw      a5,-20(s0)
jal x0, -19402
lw      a5,-36(s0)
sw      a5,-24(s0)
jal x0, -19523
lw      a4,-24(s0)
lw      a5,-20(s0)
sub     a5,a4,a5
sw      a5,-24(s0)
lw      a5,-24(s0)
blt zero, a5, -19764
lw      a5,-24(s0)
bne     a5,zero,-19845
addi a5, x0, 0
jal x0, -19921
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a4,-20(s0)
lw      a5,-36(s0)
blt     a4,a5,-20166
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
blt zero, a5, -20688
addi a5, x0, 0
jal x0, -20769
lw      a4,-36(s0)
addi a5, x0, 1
bne     a4,a5,12
addi a5, x0, 1
jal x0, -20969
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
auipc x1, 1048575
jalr x1, x1, 1616
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
bge a5, a4, -23360
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
jal x0, -23922
lw      a5,-36(s0)
andi    a5,a5,1
beq     a5,zero,-24043
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
bge a5, a4, -24524
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
blt zero, a5, -25047
addi a5, x0, 0
jal x0, -25128
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
jal x0, -25840
lw      a5,-36(s0)
andi    a5,a5,1
beq     a5,zero,-25961
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
bge a5, a4, -26402
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
jal x0, -26925
lw      a5,-20(s0)
addi    a5,a5,1
sw      a5,-20(s0)
lw      a5,-20(s0)
slli    a5,a5,2
lw      a4,-36(s0)
add     a5,a4,a5
lw      a5,0(a5)
bne     a5,zero,-27286
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
jal x0, -27849
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
