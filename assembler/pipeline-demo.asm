# pipeline-demo.asm - programa CON SENTIDO para ver el pipeline en accion.
# Suma un arreglo [5,10,15,20] guardado en memoria y deja el total (50) tanto en
# un registro como en memoria. Encadena resultados a proposito para que se vean
# los tres riesgos del pipeline en modo paso:
#   - FORWARDING: cada instruccion usa el resultado de la anterior (x3, x4).
#   - LOAD-USE STALL: el `lw` carga x7 y el `add` siguiente lo usa -> 1 burbuja.
#   - FLUSH por salto: el `blt` del lazo, cuando se toma, descarta 3 instrucciones.
#
# Base del arreglo: 0x40 (palabra 16). El total se guarda en 0x50 (palabra 20).
# Ambos en la pagina 0 de la memoria de datos (vista por defecto en la VGA).
main:
        # ---------- construir el arreglo en memoria ----------
        addi    x1, zero, 0x40        # x1 = base
        addi    x2, zero, 5
        sw      x2, 0(x1)             # M[0x40] = 5
        addi    x2, zero, 10          # (x2 reusado; depende de nada)
        sw      x2, 4(x1)             # M[0x44] = 10
        addi    x2, zero, 15
        sw      x2, 8(x1)             # M[0x48] = 15
        addi    x2, zero, 20
        sw      x2, 12(x1)            # M[0x4C] = 20

        # ---------- lazo de suma ----------
        addi    x3, zero, 0           # x3 = suma
        addi    x4, zero, 0           # x4 = indice en bytes
        addi    x5, zero, 16          # x5 = limite (4 elementos * 4 bytes)
loop:
        add     x6, x1, x4            # x6 = base + indice   (usa x4 -> forwarding)
        lw      x7, 0(x6)             # x7 = M[x6]           (usa x6 -> forwarding)
        add     x3, x3, x7            # suma += x7           (LOAD-USE: 1 burbuja por x7)
        addi    x4, x4, 4             # indice += 4          (usa x3/x4 -> forwarding)
        blt     x4, x5, loop          # si indice<16, repetir (FLUSH cuando se toma)

        # ---------- guardar el resultado y terminar ----------
        sw      x3, 16(x1)            # M[0x50] = 50
        addi    x10, zero, 0          # x10 = 0 (convencion: "todo bien")
        ebreak                        # HALT
