# Controles del DE1-SoC

## Botones (KEY)

| Boton | Que hace |
|-------|----------|
| KEY[0] | **Reset** - Mantenerlo presionado reinicia la CPU. El PC vuelve a 0 y el programa empieza desde el principio. Al soltarlo, la CPU empieza a ejecutar. |
| KEY[1] | **Paso a paso** - En modo manual (SW[0]=1), cada presion ejecuta exactamente una instruccion. |

> Los botones son activos en bajo: cuando no los presionas estan en 1, y al presionarlos van a 0.

---

## Interruptores (SW)

### SW[0] - Modo de ejecucion

| Posicion | Comportamiento |
|----------|----------------|
| ABAJO (0) | **Libre** - La CPU corre a 50 MHz automaticamente. El programa avanza solo, instruccion por instruccion, sin que hagas nada. |
| ARRIBA (1) | **Paso a paso** - La CPU se congela. No avanza hasta que presiones KEY[1]. Util para depurar. |

---

### SW[9:8] - Que mostrar en los displays

| SW[9] | SW[8] | Que ves |
|-------|-------|---------|
| 0 | 0 | **PC** - La direccion de la instruccion actual. Empieza en `000000`, sube de 4 en 4. |
| 0 | 1 | **Instruccion** - El codigo hex de la instruccion actual. Por ejemplo, `00500093` es `addi x1, x0, 5`. |
| 1 | 0 | **Resultado del ALU** - El resultado de la operacion actual. |
| 1 | 1 | **Registro** - HEX5:HEX4 muestran el numero del registro en decimal, HEX3:HEX0 su valor en hex. Usa SW[1] para ver la mitad alta o baja. |

---

### SW[7:3] - Que registro ver

Solo funciona cuando SW[9:8] = 11.

Pon el numero del registro en binario (0 al 31).

| SW[7:3] | Registro | Nota |
|---------|----------|------|
| 00000   | x0  | Siempre `000000` (x0 es siempre cero) |
| 00001   | x1  | |
| 00010   | x2  | Stack pointer |
| 00101   | x5  | |
| ...     | ... | |
| 11111   | x31 | |

Ejemplo: para ver x5, pon SW[7]=0, SW[6]=0, SW[5]=1, SW[4]=0, SW[3]=1.

---

### SW[1] - Mitad del registro

Solo funciona cuando SW[9:8] = 11.

| Posicion | Que ves en HEX3:HEX0 |
|----------|----------------------|
| ABAJO (0) | Bits [15:0] del registro |
| ARRIBA (1) | Bits [31:16] del registro |

---

## LEDs (LEDR)

| LED | Que ves |
|-----|---------|
| LEDR[0]   | Encendido en modo paso a paso (SW[0]=1). |
| LEDR[8:1] | Mientras corre: indice de la instruccion actual en binario (PC / 4). Cuando termina (LEDR[9] encendido): los 8 bits bajos del valor de retorno de main (x10/a0). Todo apagado = exito (retorno 0). Encendido = retorno no-cero. |
| LEDR[9]   | Se enciende cuando el programa termina (instruccion `ebreak` o memoria vacia). La CPU se congela y los displays quedan fijos. Para reiniciar, haz reset con KEY[0]. |

---

## Displays (HEX5 - HEX0)

En modos PC / instruccion / ALU muestran los 24 bits bajos del valor en hex:

```
HEX5  HEX4  HEX3  HEX2  HEX1  HEX0
[23:20][19:16][15:12][11:8][7:4][3:0]
```

En modo registro (SW[9:8] = 11):

```
HEX5  HEX4  |  HEX3  HEX2  HEX1  HEX0
indice (dec)   valor 16 bits (hex)
```

Ejemplo: x1 = 5 con SW[1]=0 → `01 0005`.

---

## Inicio rapido

1. Carga `program.hex` en la FPGA.
2. Mantén presionado **KEY[0]** para hacer reset, luego sueltalo.
3. Deja **SW[0] abajo** - la CPU corre sola.
4. Cuando **LEDR[9] se encienda** el programa termino.
5. Pon **SW[9:8] = 11** y ajusta **SW[7:3]** al registro que quieras ver. Usa **SW[1]** para ver la mitad alta si el valor es mayor a 16 bits.

---

## Depurar paso a paso

1. Mantén presionado **KEY[0]** para hacer reset.
2. Sube **SW[0]** (modo paso a paso). LEDR[0] se enciende.
3. Suelta **KEY[0]**. La CPU esta en PC=0.
4. Deja **SW[9:8] = 00** para ver el PC.
5. Presiona **KEY[1]** una vez. El PC sube a `000004`.
6. Cambia **SW[9:8]** para inspeccionar:
   - `01` -> instruccion ejecutada
   - `10` -> resultado del ALU
   - `11` -> valor del registro destino (ajusta SW[7:3])
7. Cuando **LEDR[9] se encienda**, el programa termino.
