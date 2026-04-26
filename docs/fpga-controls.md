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

### SW[9:8] - Que mostrar en los displays hexadecimales

Estos dos interruptores controlan que valor aparece en los seis displays de 7 segmentos (HEX5-HEX0).

| SW[9] | SW[8] | Que ves en los displays |
|-------|-------|------------------------|
| 0 | 0 | **PC** - La direccion de la instruccion que se esta ejecutando. Empieza en `000000`, sube de 4 en 4 (`000004`, `000008`, ...) mientras el programa corre. Si haces reset, vuelve a `000000`. |
| 0 | 1 | **Instruccion** - El codigo binario (en hex) de la instruccion actual. Por ejemplo, `00500093` es `addi x1, x0, 5`. Cambia cada ciclo mientras el programa avanza. |
| 1 | 0 | **Resultado del ALU** - El resultado de la operacion aritmetica o logica de la instruccion actual. En un `add`, ves la suma; en un `lw`, ves la direccion de memoria calculada. |
| 1 | 1 | **Valor de registro** - El contenido del registro seleccionado por SW[7:3]. Puedes ver en tiempo real como cambia un registro mientras el programa corre. |

---

### SW[7:3] - Que registro inspeccionar

Solo tiene efecto cuando SW[9:8] = 11 (modo registro).

Pon SW[7:3] en binario con el numero del registro que quieres leer (del 0 al 31).

| SW[7:3] | Registro | Nota |
|---------|----------|------|
| 00000   | x0  | Siempre muestra `000000` (x0 es siempre cero en RISC-V) |
| 00001   | x1  | |
| 00010   | x2  | Convencionalmente el stack pointer |
| 00101   | x5  | |
| ...     | ... | |
| 11111   | x31 | |

Ejemplo: para ver x5, pon SW[7]=0, SW[6]=0, SW[5]=1, SW[4]=0, SW[3]=1.

---

## LEDs (LEDR)

| LED | Que ves |
|-----|---------|
| LEDR[0]   | Encendido cuando estas en modo paso a paso (SW[0]=1). Apagado en modo libre. |
| LEDR[8:1] | Los 8 LEDs muestran en binario el indice de la instruccion actual (PC / 4). Al ejecutar la primera instruccion ves `00000001`, la segunda `00000010`, etc. Parpadean rapidamente en modo libre; en paso a paso puedes ver cada posicion claramente. |
| LEDR[9]   | Parpadea brevemente cada vez que se escribe un registro. En modo libre parpadea tan rapido que parece encendido; en paso a paso ves exactamente cuando hay escritura. |

---

## Displays hexadecimales (HEX5 - HEX0)

Muestran los 24 bits bajos del valor seleccionado por SW[9:8], en hexadecimal:

```
HEX5  HEX4  HEX3  HEX2  HEX1  HEX0
bits: [23:20][19:16][15:12][11:8][7:4][3:0]
```

Ejemplo: si el PC vale `0x000010` (instruccion 5), los displays muestran `000010`.
Si un registro vale `0x0000000F` (el numero 15), los displays muestran `00000F` (los 24 bits bajos).

> Los 8 bits mas altos (bits 31:24) no se muestran. Para valores grandes, los displays solo muestran la parte baja.

---

## Inicio rapido

1. Carga `program.hex` en la FPGA.
2. Mantén presionado **KEY[0]** para hacer reset, luego sueltalo.
3. Deja **SW[0] abajo** - la CPU corre sola.
4. Pon **SW[9:8] = 00** para ver como el PC sube de 4 en 4 en los displays.
5. Pon **SW[9:8] = 11** y **SW[7:3]** en el numero de un registro para ver su valor en vivo.

---

## Depurar paso a paso

1. Mantén presionado **KEY[0]** para hacer reset.
2. Sube **SW[0]** (modo paso a paso). LEDR[0] se enciende.
3. Suelta **KEY[0]**. La CPU esta congelada en PC=0, los displays muestran `000000`.
4. Deja **SW[9:8] = 00** para ver el PC.
5. Presiona **KEY[1]** una vez. El PC sube a `000004` y LEDR[9] parpadea si la instruccion escribe un registro.
6. Cambia **SW[9:8]** en cada paso para inspeccionar:
   - `01` -> que instruccion se ejecuto (codigo hex)
   - `10` -> que calculo hizo el ALU
   - `11` -> el valor resultante en el registro destino (ajusta SW[7:3] al numero del registro)
