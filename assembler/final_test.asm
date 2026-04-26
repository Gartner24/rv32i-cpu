multiplicar:
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
        bge     a5,zero,.L2
        lw      a5,-36(s0)
        neg     a5,a5
        sw      a5,-36(s0)
        lw      a5,-28(s0)
        addi    a5,a5,1
        sw      a5,-28(s0)
.L2:
        lw      a5,-40(s0)
        bge     a5,zero,.L4
        lw      a5,-40(s0)
        neg     a5,a5
        sw      a5,-40(s0)
        lw      a5,-28(s0)
        addi    a5,a5,1
        sw      a5,-28(s0)
        j       .L4
.L5:
        lw      a4,-20(s0)
        lw      a5,-36(s0)
        add     a5,a4,a5
        sw      a5,-20(s0)
        lw      a5,-24(s0)
        addi    a5,a5,1
        sw      a5,-24(s0)
.L4:
        lw      a4,-24(s0)
        lw      a5,-40(s0)
        blt     a4,a5,.L5
        lw      a4,-28(s0)
        li      a5,1
        bne     a4,a5,.L6
        lw      a5,-20(s0)
        neg     a5,a5
        j       .L7
.L6:
        lw      a5,-20(s0)
.L7:
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
valor_absoluto:
        addi    sp,sp,-32
        sw      ra,28(sp)
        sw      s0,24(sp)
        addi    s0,sp,32
        sw      a0,-20(s0)
        lw      a5,-20(s0)
        bge     a5,zero,.L9
        lw      a5,-20(s0)
        neg     a5,a5
        j       .L10
.L9:
        lw      a5,-20(s0)
.L10:
        mv      a0,a5
        lw      ra,28(sp)
        lw      s0,24(sp)
        addi    sp,sp,32
        jr      ra
maximo:
        addi    sp,sp,-32
        sw      ra,28(sp)
        sw      s0,24(sp)
        addi    s0,sp,32
        sw      a0,-20(s0)
        sw      a1,-24(s0)
        lw      a4,-20(s0)
        lw      a5,-24(s0)
        ble     a4,a5,.L12
        lw      a5,-20(s0)
        j       .L13
.L12:
        lw      a5,-24(s0)
.L13:
        mv      a0,a5
        lw      ra,28(sp)
        lw      s0,24(sp)
        addi    sp,sp,32
        jr      ra
minimo:
        addi    sp,sp,-32
        sw      ra,28(sp)
        sw      s0,24(sp)
        addi    s0,sp,32
        sw      a0,-20(s0)
        sw      a1,-24(s0)
        lw      a4,-20(s0)
        lw      a5,-24(s0)
        bge     a4,a5,.L15
        lw      a5,-20(s0)
        j       .L16
.L15:
        lw      a5,-24(s0)
.L16:
        mv      a0,a5
        lw      ra,28(sp)
        lw      s0,24(sp)
        addi    sp,sp,32
        jr      ra
busqueda_lineal:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      a1,-40(s0)
        sw      a2,-44(s0)
        sw      zero,-20(s0)
        j       .L18
.L21:
        lw      a5,-20(s0)
        slli    a5,a5,2
        lw      a4,-36(s0)
        add     a5,a4,a5
        lw      a5,0(a5)
        lw      a4,-44(s0)
        bne     a4,a5,.L19
        lw      a5,-20(s0)
        j       .L20
.L19:
        lw      a5,-20(s0)
        addi    a5,a5,1
        sw      a5,-20(s0)
.L18:
        lw      a4,-20(s0)
        lw      a5,-40(s0)
        blt     a4,a5,.L21
        li      a5,-1
.L20:
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
busqueda_binaria:
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
        j       .L23
.L27:
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
        bne     a4,a5,.L24
        lw      a5,-28(s0)
        j       .L25
.L24:
        lw      a5,-28(s0)
        slli    a5,a5,2
        lw      a4,-36(s0)
        add     a5,a4,a5
        lw      a5,0(a5)
        lw      a4,-44(s0)
        ble     a4,a5,.L26
        lw      a5,-28(s0)
        addi    a5,a5,1
        sw      a5,-20(s0)
        j       .L23
.L26:
        lw      a5,-28(s0)
        addi    a5,a5,-1
        sw      a5,-24(s0)
.L23:
        lw      a4,-20(s0)
        lw      a5,-24(s0)
        ble     a4,a5,.L27
        li      a5,-1
.L25:
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
intercambiar:
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
        nop
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
bubble_sort:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      a1,-40(s0)
        sw      zero,-20(s0)
        j       .L30
.L34:
        sw      zero,-24(s0)
        j       .L31
.L33:
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
        ble     a4,a5,.L32
        lw      a5,-24(s0)
        addi    a5,a5,1
        mv      a2,a5
        lw      a1,-24(s0)
        lw      a0,-36(s0)
        call    intercambiar
.L32:
        lw      a5,-24(s0)
        addi    a5,a5,1
        sw      a5,-24(s0)
.L31:
        lw      a4,-40(s0)
        lw      a5,-20(s0)
        sub     a5,a4,a5
        addi    a5,a5,-1
        lw      a4,-24(s0)
        blt     a4,a5,.L33
        lw      a5,-20(s0)
        addi    a5,a5,1
        sw      a5,-20(s0)
.L30:
        lw      a5,-40(s0)
        addi    a5,a5,-1
        lw      a4,-20(s0)
        blt     a4,a5,.L34
        nop
        nop
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
selection_sort:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      a1,-40(s0)
        sw      zero,-20(s0)
        j       .L36
.L41:
        lw      a5,-20(s0)
        sw      a5,-24(s0)
        lw      a5,-20(s0)
        addi    a5,a5,1
        sw      a5,-28(s0)
        j       .L37
.L39:
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
        bge     a4,a5,.L38
        lw      a5,-28(s0)
        sw      a5,-24(s0)
.L38:
        lw      a5,-28(s0)
        addi    a5,a5,1
        sw      a5,-28(s0)
.L37:
        lw      a4,-28(s0)
        lw      a5,-40(s0)
        blt     a4,a5,.L39
        lw      a4,-24(s0)
        lw      a5,-20(s0)
        beq     a4,a5,.L40
        lw      a2,-24(s0)
        lw      a1,-20(s0)
        lw      a0,-36(s0)
        call    intercambiar
.L40:
        lw      a5,-20(s0)
        addi    a5,a5,1
        sw      a5,-20(s0)
.L36:
        lw      a5,-40(s0)
        addi    a5,a5,-1
        lw      a4,-20(s0)
        blt     a4,a5,.L41
        nop
        nop
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
suma_array:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      a1,-40(s0)
        sw      zero,-20(s0)
        sw      zero,-24(s0)
        j       .L43
.L44:
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
.L43:
        lw      a4,-24(s0)
        lw      a5,-40(s0)
        blt     a4,a5,.L44
        lw      a5,-20(s0)
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
promedio_entero:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      a1,-40(s0)
        lw      a1,-40(s0)
        lw      a0,-36(s0)
        call    suma_array
        sw      a0,-28(s0)
        sw      zero,-20(s0)
        sw      zero,-24(s0)
        sw      zero,-32(s0)
        j       .L47
.L48:
        lw      a4,-24(s0)
        lw      a5,-40(s0)
        add     a5,a4,a5
        sw      a5,-24(s0)
        lw      a5,-20(s0)
        addi    a5,a5,1
        sw      a5,-20(s0)
.L47:
        lw      a4,-24(s0)
        lw      a5,-40(s0)
        add     a5,a4,a5
        lw      a4,-28(s0)
        bge     a4,a5,.L48
        lw      a5,-20(s0)
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
contar_si:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      a1,-40(s0)
        sw      a2,-44(s0)
        sw      zero,-20(s0)
        sw      zero,-24(s0)
        j       .L51
.L53:
        lw      a5,-24(s0)
        slli    a5,a5,2
        lw      a4,-36(s0)
        add     a5,a4,a5
        lw      a5,0(a5)
        lw      a4,-44(s0)
        bne     a4,a5,.L52
        lw      a5,-20(s0)
        addi    a5,a5,1
        sw      a5,-20(s0)
.L52:
        lw      a5,-24(s0)
        addi    a5,a5,1
        sw      a5,-24(s0)
.L51:
        lw      a4,-24(s0)
        lw      a5,-40(s0)
        blt     a4,a5,.L53
        lw      a5,-20(s0)
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
revertir_array:
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
        j       .L56
.L57:
        lw      a2,-24(s0)
        lw      a1,-20(s0)
        lw      a0,-36(s0)
        call    intercambiar
        lw      a5,-20(s0)
        addi    a5,a5,1
        sw      a5,-20(s0)
        lw      a5,-24(s0)
        addi    a5,a5,-1
        sw      a5,-24(s0)
.L56:
        lw      a4,-20(s0)
        lw      a5,-24(s0)
        blt     a4,a5,.L57
        nop
        nop
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
mcd:
        addi    sp,sp,-32
        sw      ra,28(sp)
        sw      s0,24(sp)
        addi    s0,sp,32
        sw      a0,-20(s0)
        sw      a1,-24(s0)
        lw      a5,-20(s0)
        bge     a5,zero,.L59
        lw      a5,-20(s0)
        neg     a5,a5
        sw      a5,-20(s0)
.L59:
        lw      a5,-24(s0)
        bge     a5,zero,.L61
        lw      a5,-24(s0)
        neg     a5,a5
        sw      a5,-24(s0)
        j       .L61
.L63:
        lw      a4,-20(s0)
        lw      a5,-24(s0)
        ble     a4,a5,.L62
        lw      a4,-20(s0)
        lw      a5,-24(s0)
        sub     a5,a4,a5
        sw      a5,-20(s0)
        j       .L61
.L62:
        lw      a4,-24(s0)
        lw      a5,-20(s0)
        sub     a5,a4,a5
        sw      a5,-24(s0)
.L61:
        lw      a4,-20(s0)
        lw      a5,-24(s0)
        bne     a4,a5,.L63
        lw      a5,-20(s0)
        mv      a0,a5
        lw      ra,28(sp)
        lw      s0,24(sp)
        addi    sp,sp,32
        jr      ra
mcm:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      a1,-40(s0)
        lw      a1,-40(s0)
        lw      a0,-36(s0)
        call    mcd
        sw      a0,-28(s0)
        lw      a1,-40(s0)
        lw      a0,-36(s0)
        call    multiplicar
        sw      a0,-32(s0)
        sw      zero,-20(s0)
        sw      zero,-24(s0)
        j       .L66
.L67:
        lw      a4,-24(s0)
        lw      a5,-28(s0)
        add     a5,a4,a5
        sw      a5,-24(s0)
        lw      a5,-20(s0)
        addi    a5,a5,1
        sw      a5,-20(s0)
.L66:
        lw      a4,-24(s0)
        lw      a5,-28(s0)
        add     a5,a4,a5
        lw      a4,-32(s0)
        bge     a4,a5,.L67
        lw      a5,-20(s0)
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
es_primo:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        lw      a4,-36(s0)
        li      a5,1
        bgt     a4,a5,.L70
        li      a5,0
        j       .L71
.L70:
        li      a5,2
        sw      a5,-20(s0)
        j       .L72
.L76:
        lw      a5,-36(s0)
        sw      a5,-24(s0)
        j       .L73
.L74:
        lw      a4,-24(s0)
        lw      a5,-20(s0)
        sub     a5,a4,a5
        sw      a5,-24(s0)
.L73:
        lw      a5,-24(s0)
        bgt     a5,zero,.L74
        lw      a5,-24(s0)
        bne     a5,zero,.L75
        li      a5,0
        j       .L71
.L75:
        lw      a5,-20(s0)
        addi    a5,a5,1
        sw      a5,-20(s0)
.L72:
        lw      a4,-20(s0)
        lw      a5,-36(s0)
        blt     a4,a5,.L76
        li      a5,1
.L71:
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
fibonacci:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        lw      a5,-36(s0)
        bgt     a5,zero,.L78
        li      a5,0
        j       .L79
.L78:
        lw      a4,-36(s0)
        li      a5,1
        bne     a4,a5,.L80
        li      a5,1
        j       .L79
.L80:
        sw      zero,-20(s0)
        li      a5,1
        sw      a5,-24(s0)
        li      a5,2
        sw      a5,-28(s0)
        j       .L81
.L82:
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
.L81:
        lw      a4,-28(s0)
        lw      a5,-36(s0)
        ble     a4,a5,.L82
        lw      a5,-24(s0)
.L79:
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
sqrt_entera:
        addi    sp,sp,-64
        sw      ra,60(sp)
        sw      s0,56(sp)
        addi    s0,sp,64
        sw      a0,-52(s0)
        lw      a5,-52(s0)
        bge     a5,zero,.L84
        li      a5,-1
        j       .L85
.L84:
        lw      a5,-52(s0)
        bne     a5,zero,.L86
        li      a5,0
        j       .L85
.L86:
        li      a5,1
        sw      a5,-20(s0)
        lw      a5,-52(s0)
        sw      a5,-24(s0)
        sw      zero,-28(s0)
        j       .L87
.L90:
        lw      a4,-20(s0)
        lw      a5,-24(s0)
        add     a5,a4,a5
        srai    a5,a5,1
        sw      a5,-32(s0)
        lw      a1,-32(s0)
        lw      a0,-32(s0)
        call    multiplicar
        sw      a0,-36(s0)
        lw      a4,-36(s0)
        lw      a5,-52(s0)
        bne     a4,a5,.L88
        lw      a5,-32(s0)
        j       .L85
.L88:
        lw      a4,-36(s0)
        lw      a5,-52(s0)
        bge     a4,a5,.L89
        lw      a5,-32(s0)
        sw      a5,-28(s0)
        lw      a5,-32(s0)
        addi    a5,a5,1
        sw      a5,-20(s0)
        j       .L87
.L89:
        lw      a5,-32(s0)
        addi    a5,a5,-1
        sw      a5,-24(s0)
.L87:
        lw      a4,-20(s0)
        lw      a5,-24(s0)
        ble     a4,a5,.L90
        lw      a5,-28(s0)
.L85:
        mv      a0,a5
        lw      ra,60(sp)
        lw      s0,56(sp)
        addi    sp,sp,64
        jr      ra
contar_bits:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      zero,-20(s0)
        sw      zero,-24(s0)
        j       .L92
.L94:
        lw      a5,-36(s0)
        andi    a5,a5,1
        beq     a5,zero,.L93
        lw      a5,-20(s0)
        addi    a5,a5,1
        sw      a5,-20(s0)
.L93:
        lw      a5,-36(s0)
        srai    a5,a5,1
        sw      a5,-36(s0)
        lw      a5,-24(s0)
        addi    a5,a5,1
        sw      a5,-24(s0)
.L92:
        lw      a4,-24(s0)
        li      a5,31
        ble     a4,a5,.L94
        lw      a5,-20(s0)
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
es_potencia_de_dos:
        addi    sp,sp,-32
        sw      ra,28(sp)
        sw      s0,24(sp)
        addi    s0,sp,32
        sw      a0,-20(s0)
        lw      a5,-20(s0)
        bgt     a5,zero,.L97
        li      a5,0
        j       .L98
.L97:
        lw      a5,-20(s0)
        addi    a4,a5,-1
        lw      a5,-20(s0)
        and     a5,a4,a5
        seqz    a5,a5
        andi    a5,a5,0xff
.L98:
        mv      a0,a5
        lw      ra,28(sp)
        lw      s0,24(sp)
        addi    sp,sp,32
        jr      ra
bit_mas_significativo:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      zero,-20(s0)
        sw      zero,-24(s0)
        j       .L100
.L102:
        lw      a5,-36(s0)
        andi    a5,a5,1
        beq     a5,zero,.L101
        lw      a5,-24(s0)
        sw      a5,-20(s0)
.L101:
        lw      a5,-36(s0)
        srai    a5,a5,1
        sw      a5,-36(s0)
        lw      a5,-24(s0)
        addi    a5,a5,1
        sw      a5,-24(s0)
.L100:
        lw      a4,-24(s0)
        li      a5,31
        ble     a4,a5,.L102
        lw      a5,-20(s0)
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
longitud:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      zero,-20(s0)
        j       .L105
.L106:
        lw      a5,-20(s0)
        addi    a5,a5,1
        sw      a5,-20(s0)
.L105:
        lw      a5,-20(s0)
        slli    a5,a5,2
        lw      a4,-36(s0)
        add     a5,a4,a5
        lw      a5,0(a5)
        bne     a5,zero,.L106
        lw      a5,-20(s0)
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
comparar:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      a1,-40(s0)
        sw      zero,-20(s0)
        j       .L109
.L114:
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
        bge     a4,a5,.L110
        li      a5,-1
        j       .L111
.L110:
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
        ble     a4,a5,.L112
        li      a5,1
        j       .L111
.L112:
        lw      a5,-20(s0)
        addi    a5,a5,1
        sw      a5,-20(s0)
.L109:
        lw      a5,-20(s0)
        slli    a5,a5,2
        lw      a4,-36(s0)
        add     a5,a4,a5
        lw      a5,0(a5)
        beq     a5,zero,.L113
        lw      a5,-20(s0)
        slli    a5,a5,2
        lw      a4,-40(s0)
        add     a5,a4,a5
        lw      a5,0(a5)
        bne     a5,zero,.L114
.L113:
        lw      a5,-20(s0)
        slli    a5,a5,2
        lw      a4,-36(s0)
        add     a5,a4,a5
        lw      a5,0(a5)
        bne     a5,zero,.L115
        lw      a5,-20(s0)
        slli    a5,a5,2
        lw      a4,-40(s0)
        add     a5,a4,a5
        lw      a5,0(a5)
        bne     a5,zero,.L115
        li      a5,0
        j       .L111
.L115:
        lw      a5,-20(s0)
        slli    a5,a5,2
        lw      a4,-36(s0)
        add     a5,a4,a5
        lw      a5,0(a5)
        bne     a5,zero,.L116
        li      a5,-1
        j       .L111
.L116:
        li      a5,1
.L111:
        mv      a0,a5
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
copiar:
        addi    sp,sp,-48
        sw      ra,44(sp)
        sw      s0,40(sp)
        addi    s0,sp,48
        sw      a0,-36(s0)
        sw      a1,-40(s0)
        sw      zero,-20(s0)
        j       .L118
.L119:
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
.L118:
        lw      a5,-20(s0)
        slli    a5,a5,2
        lw      a4,-40(s0)
        add     a5,a4,a5
        lw      a5,0(a5)
        bne     a5,zero,.L119
        lw      a5,-20(s0)
        slli    a5,a5,2
        lw      a4,-36(s0)
        add     a5,a4,a5
        sw      zero,0(a5)
        nop
        lw      ra,44(sp)
        lw      s0,40(sp)
        addi    sp,sp,48
        jr      ra
main:
        addi    sp,sp,-16
        sw      ra,12(sp)
        sw      s0,8(sp)
        addi    s0,sp,16
        li      a1,7
        li      a0,6
        call    multiplicar
        mv      a4,a0
        li      a5,42
        beq     a4,a5,.L121
        li      a5,-1
        j       .L122
.L121:
        li      a0,-15
        call    valor_absoluto
        mv      a4,a0
        li      a5,15
        beq     a4,a5,.L123
        li      a5,-2
        j       .L122
.L123:
        li      a1,25
        li      a0,10
        call    maximo
        mv      a4,a0
        li      a5,25
        beq     a4,a5,.L124
        li      a5,-3
        j       .L122
.L124:
        li      a0,10
        call    fibonacci
        mv      a4,a0
        li      a5,55
        beq     a4,a5,.L125
        li      a5,-4
        j       .L122
.L125:
        li      a1,18
        li      a0,48
        call    mcd
        mv      a4,a0
        li      a5,6
        beq     a4,a5,.L126
        li      a5,-5
        j       .L122
.L126:
        li      a5,0
.L122:
        mv      a0,a5
        lw      ra,12(sp)
        lw      s0,8(sp)
        addi    sp,sp,16
        jr      ra
