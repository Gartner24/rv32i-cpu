main:
    addi x1, x0, 5      # x1 = 5
    addi x2, x0, 3      # x2 = 3
    add  x3, x1, x2     # x3 = 8
    sub  x4, x1, x2     # x4 = 2
    sw   x3, 0(x0)      # guarda x3 en memoria[0]
    lw   x5, 0(x0)      # x5 = memoria[0] = 8
    beq  x1, x2, 8      # NO salta (5 != 3)
    addi x6, x0, 99     # x6 = 99 (debe ejecutarse)
