# Como funciona esta CPU - Explicacion completa

Explica desde cero como funciona el procesador RV32I que implementamos.
Se puede leer de principio a fin sin haber visto hardware digital antes.

---

## 1. La idea general: que hace una CPU

Una CPU hace exactamente tres cosas, repetidas millones de veces por segundo:

1. **Fetch** - Busca la siguiente instruccion en memoria
2. **Decode** - Descifra que instruccion es y que necesita hacer
3. **Execute** - La ejecuta y guarda el resultado

En una CPU de un ciclo (monociclo) como esta, las tres etapas pasan
**al mismo tiempo, en un solo tick de reloj**. Cuando el reloj sube (flanco de subida),
la CPU ya tiene el resultado listo. En el siguiente tick, hace lo mismo con la
siguiente instruccion.

Esto es diferente a una CPU con pipeline (como tu celular), donde cada etapa
tiene su propio registro y se solapan: mientras una instruccion se ejecuta,
la siguiente ya se esta decodificando, y la que viene despues ya se esta buscando.
Nosotros no hacemos eso - es mas simple, pero mas lento.

---

## 2. Arquitectura Harvard: dos memorias separadas

Esta CPU usa **arquitectura Harvard**. La caracteristica principal es que tiene
dos memorias completamente separadas:

- **Memoria de instrucciones** (`instruction_memory.v`): solo lectura, guarda el programa
- **Memoria de datos** (`data_memory.v`): lectura y escritura, guarda variables y el stack

Esto permite leer una instruccion Y leer/escribir un dato al mismo tiempo en el
mismo ciclo, porque son buses y memorias fisicamente distintas.

La alternativa es **arquitectura Von Neumann** (la que usa tu computadora): programa
y datos comparten la misma memoria RAM. Nosotros NO usamos eso. Se menciona solo
como comparacion para entender por que Harvard es mas simple en FPGA.

---

## 3. El formato de las instrucciones RISC-V

Todas las instrucciones de RV32I tienen exactamente **32 bits** (4 bytes). No hay
instrucciones de 16 bits ni de 8 bits - siempre 32. Esto simplifica muchisimo el
hardware porque sabes exactamente cuanto leer cada vez.

Esos 32 bits se dividen en campos con significados fijos:

```
Bits:  31      25 24   20 19   15 14  12 11    7 6      0
       [ func7  ] [ rs2  ] [ rs1  ] [func3] [  rd  ] [opcode]
```

- **opcode** (bits 6:0): dice QUE tipo de instruccion es (suma, carga, salto, etc.)
- **rd** (bits 11:7): registro DESTINO - donde se guarda el resultado
- **rs1** (bits 19:15): primer registro FUENTE - primer operando
- **rs2** (bits 24:20): segundo registro FUENTE - segundo operando
- **func3** (bits 14:12): refinamiento dentro del tipo (ej: ADD vs SUB son el mismo tipo)
- **func7** (bits 31:25): refinamiento adicional (ej: shift logico vs aritmetico)

No todas las instrucciones usan todos estos campos. Los **tipos de instruccion** son:

| Tipo | Quien lo usa | Como se ve |
|------|-------------|------------|
| R | add, sub, and, or, xor, sll, srl, sra, slt | opcode + rd + func3 + rs1 + rs2 + func7 |
| I | addi, lw, jalr | opcode + rd + func3 + rs1 + inmediato[11:0] |
| S | sw | opcode + func3 + rs1 + rs2 + inmediato (partido en dos) |
| B | beq, bne, blt, bge | opcode + func3 + rs1 + rs2 + offset (partido) |
| U | lui, auipc | opcode + rd + inmediato[31:12] |
| J | jal | opcode + rd + offset (partido) |

El inmediato es un numero que viene **dentro de la propia instruccion** en lugar de
venir de un registro. Por ejemplo, `addi x1, x0, 5` tiene el 5 codificado en los
bits de la instruccion. El `imm_gen.v` se encarga de extraerlo y extenderlo a 32 bits.

---

## 4. Los registros

RISC-V tiene **32 registros** de 32 bits cada uno, llamados x0 a x31.
Son como variables que viven dentro del chip - acceso instantaneo, sin ir a memoria.

- **x0**: siempre vale 0, no se puede escribir. Es un convenio del ISA.
- **x1 (ra)**: return address - donde volver cuando termina una funcion
- **x2 (sp)**: stack pointer - apunta al tope del stack
- **x10-x17 (a0-a7)**: argumentos de funciones y valores de retorno
- **x8-x9, x18-x27 (s0-s11)**: registros guardados - las funciones los preservan
- **x5-x7, x28-x31 (t0-t6)**: temporales - pueden ser sobreescritos libremente

---

## 5. Los modulos - cada pieza por separado

### 5.1 `pc.v` - El contador de programa

```
Entradas: clk (CLOCK_50), rst, cpu_en, pc_next[31:0]
Salida:   pc_out[31:0]
```

El PC (Program Counter) es el registro mas importante de la CPU. Guarda **la direccion
de la instruccion que se esta ejecutando ahora mismo**. Es simplemente un registro de
32 bits que se actualiza en cada flanco de reloj.

- Si `rst = 1`: se pone a 0x00000000 (inicio del programa)
- Si `cpu_en = 1`: toma el valor de `pc_next` (la siguiente direccion)
- Si `cpu_en = 0`: se queda donde esta (CPU congelada - modo step o halt)

`pc_next` puede ser `PC + 4` (instruccion siguiente) o una direccion de salto.
`top.v` decide cual de las dos usar en las lineas 146-150:

```verilog
adder u_pc_plus4  (.a(pc_out),  .b(32'd4),    .out(pc_plus4));   // siempre calcula PC+4
adder u_pc_branch (.a(pc_out),  .b(imm_ext),  .out(pc_branch));  // siempre calcula PC+offset

mux2to1 u_mux_jump (.sel(jalr),   .a(pc_branch), .b(alu_result), .out(pc_jump));  // JALR usa ALU, no pc+imm
mux2to1 u_mux_pc   (.sel(pc_src), .a(pc_plus4),  .b(pc_jump),    .out(pc_next)); // decision final
```

`pc_src` (linea 137) es la senal que activa el salto:

```verilog
assign pc_src = branch_taken | jal | jalr;
```

Si `pc_src = 0`: `pc_next = pc_plus4` (secuencial).
Si `pc_src = 1`: `pc_next = pc_jump` (salto). El mux intermedio `u_mux_jump` elige entre
`pc_branch` (para JAL y branches, donde el destino es `PC + imm`) y `alu_result` (para JALR,
donde el destino es `rs1 + imm` calculado por la ALU).

El PC usa `CLOCK_50` como reloj propio, con `cpu_en` como puerta. Solo avanza cuando
el reloj sube Y cpu_en vale 1.

### 5.2 `instruction_memory.v` - La ROM del programa

```
Entrada: addr[31:0]
Salida:  instr[31:0]
```

Es una memoria de solo lectura (ROM) que contiene el programa. Se carga con el
contenido del archivo hex indicado por el parametro `HEX_FILE` al momento de sintetizar
en Quartus. El tamano esta definido por el parametro `MEM_DEPTH` (por defecto 256
palabras = 1 KB de programa). Para simulaciones con programas grandes como `final_test.hex`
se puede sobreescribir con `defparam dut.u_imem.MEM_DEPTH = 1024` en el testbench.

La direccion que le llega es en bytes (como en RISC-V real), pero como cada instruccion
son 4 bytes, se ignoran los dos bits menos significativos:

```verilog
assign instr = mem[addr[31:2]];
```

`addr[31:2]` es lo mismo que `addr / 4`. Si PC = 8, `8 / 4 = 2`, entonces saca la
instruccion numero 2. Funciona porque todas las instrucciones estan alineadas a 4 bytes.

La salida es combinacional: no espera un flanco de reloj, entrega la instruccion
inmediatamente cuando llega la direccion.

### 5.3 `control_unit.v` - El cerebro del decodificador

```
Entrada: opcode[6:0]
Salidas: reg_write, alu_src, alu_a_src, mem_write, mem_read,
         mem_to_reg, branch, jal, jalr, alu_op[1:0]
```

Mira solo el opcode (7 bits menos significativos de la instruccion) y decide
que tiene que pasar en toda la CPU. Es un **decodificador puro** - combinacional,
sin registros, sin estado. Entrada opcode, salida un conjunto de senales de control.

Cada senal de control abre o cierra una "compuerta" en el camino de datos:

| Senal | 0 | 1 |
|-------|---|---|
| `reg_write` | No se escribe en registros (SW, branches) | Escribe `wb_data` en el registro destino al final del ciclo |
| `alu_src` | Segundo operando de la ALU = `rs2` (tipo R) | Segundo operando de la ALU = inmediato (tipo I, S, U) |
| `alu_a_src` | Primer operando de la ALU = `rs1` (caso normal) | Primer operando de la ALU = `PC` (solo AUIPC y JAL) |
| `mem_write` | No escribe en memoria | Escribe `rs2` en `dmem[alu_result]` (instruccion SW) |
| `mem_read` | No lee de memoria | Lee `dmem[alu_result]` y lo pone en `mem_data_out` (instruccion LW) |
| `mem_to_reg` | El valor que se guarda en `rd` viene de la ALU | El valor que se guarda en `rd` viene de memoria (`mem_data_out`) |
| `branch` | No es un salto condicional | Es BEQ/BNE/BLT/BGE: el salto ocurre solo si `branch_cond` tambien es 1 |
| `jal` | No es JAL | Es JAL: salta a `PC + imm`, guarda `PC+4` en `rd` |
| `jalr` | No es JALR | Es JALR: salta a `rs1 + imm` (via ALU), guarda `PC+4` en `rd` |
| `alu_op` | 2 bits — ver tabla siguiente | |

`alu_op` no dice exactamente que operacion hacer - solo da una pista:
- `00`: siempre ADD (para loads, stores, LUI, AUIPC, JAL, JALR)
- `01`: mirar func3 para elegir la comparacion correcta (para branches)
- `10`: mirar func3 y func7 para decidir (para instrucciones R-type)
- `11`: mirar solo func3, ignorar func7 (para instrucciones I-type aritmeticas: addi, xori, etc.)

### 5.4 `alu_control.v` - El segundo nivel de decodificacion

```
Entradas: alu_op[1:0], func3[2:0], func7[6:0]
Salida:   alu_ctrl[3:0]
```

Existe porque `control_unit` solo mira el opcode y no sabe si es ADD o SUB o AND
(todas son R-type con el mismo opcode). `alu_control` resuelve eso mirando func3 y func7.

Por que dos niveles de decodificacion? Para mantener `control_unit` simple.
Si `control_unit` tuviese que mirar opcode + func3 + func7 al mismo tiempo,
tendria el doble de casos. Separarlo en dos modulos mantiene cada uno manejable.

Produce un codigo de 4 bits que le dice a la ALU exactamente que operacion ejecutar:

```
0000 = ADD    0001 = SUB    0010 = AND    0011 = OR
0100 = XOR    0101 = SLL    0110 = SRL    0111 = SRA
1000 = SLT    1001 = SLTU
```

Cuando `alu_op = 01` (branches), `alu_control` no usa SUB para todo: mira func3
para elegir la comparacion adecuada segun la instruccion de salto:

```verilog
2'b01: case (func3)
    3'b000, 3'b001: alu_ctrl = 4'b0001; // BEQ/BNE  -> SUB  (usar alu_zero)
    3'b100, 3'b101: alu_ctrl = 4'b1000; // BLT/BGE  -> SLT  (comparar con signo)
    3'b110, 3'b111: alu_ctrl = 4'b1001; // BLTU/BGEU -> SLTU (comparar sin signo)
    default:        alu_ctrl = 4'b0001;
endcase
```

- BEQ/BNE necesitan saber si son iguales: se restan y se mira si el resultado es 0
- BLT/BGE necesitan saber si uno es menor que el otro con signo: SLT pone 1 en result[0] si a < b
- BLTU/BGEU: igual pero sin signo (SLTU)

### 5.5 `alu.v` - La unidad aritmetico-logica

```
Entradas: a[31:0], b[31:0], alu_ctrl[3:0]
Salidas:  result[31:0], zero
```

Hace la operacion matematica. Recibe dos numeros de 32 bits y un codigo de operacion,
y produce el resultado. Es completamente combinacional - no hay reloj, el resultado
esta disponible inmediatamente (con algo de retardo de propagacion).

La senal `zero` vale 1 cuando `result == 0`. Se usa para BEQ y BNE:
`BEQ` hace `rs1 - rs2` con la ALU, y si el resultado es 0 (son iguales), `zero = 1`
y el salto se toma.

Para operaciones SLT y SLTU, `result[0]` vale 1 si a < b, y 0 si a >= b.
El bit 0 del resultado es lo unico que importa en ese caso. La logica de branch
en `top.v` lo lee directamente para decidir si BLT o BGE se toman.

### 5.6 `imm_gen.v` - El generador de inmediatos

```
Entrada: instr[31:0]
Salida:  imm_out[31:0]
```

Las instrucciones tienen el inmediato partido en pedazos por toda la instruccion,
en posiciones distintas segun el tipo. `imm_gen` los reensambla y los **extiende
con signo** a 32 bits.

Extension con signo significa: si el inmediato es negativo (bit de signo = 1),
los bits que se agregan a la izquierda para llegar a 32 bits son todos 1. Si es
positivo, son todos 0. Asi el numero mantiene su valor cuando pasa de 12 bits a 32.

El bit de signo siempre es `instr[31]` en todos los formatos RISC-V. Lo pusieron
siempre en el mismo bit para que el hardware de extension con signo sea el mismo
circuito para todos los tipos.

Ejemplo con S-type (`sw`): el inmediato esta partido en `instr[31:25]` (7 bits) e
`instr[11:7]` (5 bits). `imm_gen` los junta: `{instr[31:25], instr[11:7]}` = 12 bits,
luego los extiende a 32. Por que partido? Para que rs2 siempre este en la misma
posicion que en R-type, lo que simplifica el banco de registros.

### 5.7 `register_file.v` - El banco de registros (combinacional puro)

```
Entradas: regs_flat[1023:0], rs1[4:0], rs2[4:0], debug_addr[4:0]
Salidas:  read_data1[31:0], read_data2[31:0], debug_data[31:0], exit_code[31:0]
```

Este modulo **no tiene clk, no tiene escritura, no tiene estado propio**. Es un
decodificador (mux) puro: recibe los 32 registros ya calculados desde `top.v` y
selecciona los que pide la instruccion actual.

Los valores de los registros no viven aqui. Vienen de `top.v` empaquetados en un
bus de 1024 bits llamado `regs_flat` (32 registros x 32 bits = 1024 bits en un wire).

Internamente el modulo los desempaqueta con un bloque `generate`:

```verilog
wire [31:0] regs [0:31];
genvar gi;
generate
    for (gi = 0; gi < 32; gi = gi + 1) begin : unpack
        assign regs[gi] = regs_flat[32*gi +: 32];
    end
endgenerate
```

El `generate` se expande en tiempo de elaboracion (antes de que corra la simulacion)
produciendo 32 `assign` fijos:
- `assign regs[0]  = regs_flat[31:0]`
- `assign regs[1]  = regs_flat[63:32]`
- ...
- `assign regs[31] = regs_flat[1023:992]`

Luego tres lecturas combinacionales independientes:

```verilog
assign read_data1 = (rs1 == 5'b0) ? 32'b0 : regs[rs1];
assign read_data2 = (rs2 == 5'b0) ? 32'b0 : regs[rs2];
assign debug_data = (debug_addr == 5'b0) ? 32'b0 : regs[debug_addr];
assign exit_code  = regs[10];
```

La proteccion de x0 esta en la lectura: si la direccion es 0, el resultado es
siempre 0 sin importar que diga `regs[0]`. La escritura en x0 se bloquea en `top.v`.

**Por que no tiene clk?** El teacher requiere que solo `pc.v` sea sincrono para que el
diseno sea considerado monociclo. Si este modulo tuviera `posedge clk` interno, dejaria
de ser un bloque combinacional del camino de datos. Los flip-flops de almacenamiento
viven en `top.v` (ver seccion 6.5), donde ya hay permiso para logica sincrona.

El **puerto `debug_addr`/`debug_data`** lo maneja `vga_debug.v`: conduce `debug_addr`
con el numero del registro que quiere mostrar en pantalla y lee `debug_data` para
dibujarlo. Como todo es combinacional, puede recorrer los 32 registros ciclo a ciclo
sin afectar la ejecucion.

**`exit_code`** siempre lee x10 (a0), que es donde C guarda el valor de retorno de
`main()`. El display VGA lo muestra cuando el programa termina.

### 5.8 `data_memory.v` - La RAM de datos (combinacional pura)

```
Entradas: mem_flat[8191:0], mem_read, addr[31:0]
Salida:   read_data[31:0]
```

256 palabras de 32 bits = 1 KB de datos. Aqui viven las variables del programa y el stack.
Al igual que `register_file.v`, **no tiene clk, no escribe nada, no tiene estado propio**.

Los valores de la memoria no viven aqui. Vienen de `top.v` empaquetados en un bus de
8192 bits llamado `mem_flat` (256 palabras x 32 bits = 8192 bits en un wire).

Mismo patron de desempaquetado con `generate`:

```verilog
wire [31:0] mem [0:255];
genvar gi;
generate
    for (gi = 0; gi < 256; gi = gi + 1) begin : unpack
        assign mem[gi] = mem_flat[32*gi +: 32];
    end
endgenerate
```

Luego la lectura combinacional:

```verilog
assign read_data = mem_read ? mem[addr[31:2]] : 32'b0;
```

- `mem_read = 1`: devuelve la palabra en `mem[addr/4]`
- `mem_read = 0`: devuelve 0 para no contaminar el bus de writeback con basura

`addr[31:2]` convierte la direccion en bytes a indice de palabra dividiendo por 4.
Si `addr = 8`, `8/4 = 2`, lee `mem[2]`. Solo soporta acceso alineado de 32 bits (lw/sw).

El stack crece hacia abajo desde la direccion 1024 (el tope de la memoria).
La primera instruccion del crt0 pone `sp = 1024`. Cada funcion baja el sp
con `addi sp, sp, -N` para reservar espacio en el stack frame.

Las escrituras (instruccion `sw`) las realiza `top.v` directamente sobre el arreglo
`dmem[]` con un `always @(posedge CLOCK_50)`. Ver seccion 6.5.

### 5.9 `adder.v` - Sumador puro

```
Entradas: a[31:0], b[31:0]
Salida:   out[31:0]
```

Solo suma. Se usa dos veces en top.v:
- Para calcular `PC + 4` (siguiente instruccion en secuencia)
- Para calcular `PC + inmediato` (destino de un salto relativo)

Por que no usar la ALU para esto? Porque la ALU ya esta ocupada ejecutando la
instruccion actual. Necesitamos calcular el PC siguiente en paralelo con la ejecucion.

### 5.10 `mux2to1.v` - Multiplexor de 2 entradas

```
Entradas: sel, a[31:0], b[31:0]
Salida:   out[31:0]
```

Elige entre dos opciones segun `sel`. Si `sel = 0`, pasa `a`. Si `sel = 1`, pasa `b`.
Se usa 6 veces en top.v para diferentes decisiones:

1. Que va como operando A de la ALU: rs1 o PC
2. Que va como operando B de la ALU: rs2 o inmediato
3. A donde salta: PC+inmediato o resultado de la ALU
4. Si el PC salta o sigue en secuencia
5. Que se escribe en el registro: resultado ALU o dato de memoria
6. Si se guarda PC+4 en rd (para JAL/JALR)

### 5.11 `hex_display.v` - Display de 7 segmentos

```
Entrada: value[3:0]
Salida:  segments[6:0]
```

Convierte un nibble (0-F) en los 7 bits que controlan los segmentos del display.
Es una tabla de conversion (ROM de 16 entradas). Los segmentos son activos en bajo:
`0` enciende el segmento, `1` lo apaga.

### 5.12 `clock_div.v` - Divisor de reloj

```
Entrada: clock50 (50 MHz)
Salida:  clock25 (25 MHz)
```

Divide la frecuencia del reloj principal a la mitad. Usa un contador de 2 bits:
la salida `clock25` esta en alto durante 2 de cada 4 ciclos del reloj de 50 MHz,
produciendo un reloj de 25 MHz con ciclo de trabajo del 50%.

Lo usa `vga_controller.v` internamente para generar el pixel clock que necesita
VGA a 640x480@60Hz.

### 5.13 `vga_controller.v` - Controlador VGA

```
Entradas: clk_50MHz, reset
Salidas:  video_on, hsync, vsync, clk (25 MHz pixel clock = VGA_CLK), x[9:0], y[9:0]
```

Genera las senales de sincronizacion VGA para una resolucion de 640x480 a 60 Hz
(estandar VESA). Internamente usa `clock_div` para obtener el pixel clock de 25 MHz.

Su trabajo es llevar la cuenta de que pixel se esta dibujando ahora mismo:
- `x` y `y` son las coordenadas del pixel actual (0-639 horizontal, 0-479 vertical)
- `video_on = 1` cuando el haz esta en el area visible (los 640x480 pixeles utiles)
- `video_on = 0` durante el blanking horizontal y vertical (el tiempo que el haz
  "viaja de vuelta" al inicio de la siguiente linea o del siguiente frame)
- `hsync` y `vsync` son los pulsos de sincronizacion que el monitor usa para
  saber donde empieza cada linea y cada frame
- `clk` es el pixel clock de 25 MHz que se conecta a `VGA_CLK` en la FPGA

`vga_debug.v` recibe `x` e `y` de este modulo para saber que pixel colorear.

### 5.14 `vga_debug.v` - Visualizacion del estado de la CPU por pantalla

```
Entradas: x[9:0], y[9:0], video_on, pc_out, instr, alu_result, alu_zero, halted,
          mem_data_out, exit_code, reg_write, mem_read, mem_write, mem_to_reg,
          alu_src, branch, jal, jalr, pc_src, debug_data[31:0]
          (mas todas las senales de instruccion decodificadas)
Salidas:  VGA_R[3:0], VGA_G[3:0], VGA_B[3:0]
```

Es un modulo **puramente combinacional**: dado el pixel actual `(x, y)` mas el estado
de la CPU, calcula el color RGB que debe tener ese pixel. No tiene registros internos
propios - en cada ciclo recalcula toda la pantalla desde cero.

Divide la pantalla de 640x480 en una cuadricula de caracteres de **80 columnas x 30
filas** (8 pixeles de ancho x 16 pixeles de alto por caracter). La fuente es el
charset de Atari-ST, cargado desde `font128.hex`.

Para mostrar todos los registros, `vga_debug.v` maneja el puerto de debug del banco
de registros: conduce `debug_addr` con la direccion del registro que quiere leer
(recorre x00 a x31 para dibujar la pantalla), y lee el valor de `debug_data`.

**Layout de la pantalla:**

```
Fila  0: PC:XXXXXXXX  INSTR:XXXXXXXX  ALU:XXXXXXXX  Z:X  HALT:X  MEM:XXXXXXXX
Fila  1: OPC:XX  F3:X  F7:XX  RD:XX  RS1:XX  RS2:XX  IMM:XXXXXXXX
Fila  2: CTL: RW=X MR=X MW=X M2R=X AS=X BR=X JL=X JR=X PCS=X
Fila  4: REGISTERS
Filas 5-20: x00..x15 (columna izquierda), x16..x31 (columna derecha)
```

- **Fila 0**: estado de ejecucion en tiempo real - PC, instruccion cruda, resultado
  de la ALU, flag de cero, flag de halt, ultimo dato leido de memoria
- **Fila 1**: campos decodificados de la instruccion actual - opcode, funct3, funct7,
  numeros de registros rd/rs1/rs2, inmediato
- **Fila 2**: todas las senales de control que genera `control_unit` para esta instruccion
- **Filas 5-20**: los 32 registros x0-x31 con sus valores en hex, actualizados en tiempo real

Esta pantalla reemplaza la necesidad de usar switches para seleccionar que mostrar:
todo el estado de la CPU es visible de un vistazo.

---

## 6. `top.v` - El que conecta todo

`top.v` es el modulo principal. No hace calculos por si mismo - su trabajo es
**cablear** todos los modulos anteriores y tomar las decisiones de enrutamiento.
Es el director de orquesta.

### 6.1 El reloj y el reset

```verilog
wire rst = ~KEY[0];
```

KEY[0] es activo en bajo (cuando lo presionas va a 0). Para convertirlo a
activo en alto (que es lo que esperan los modulos internos), se invierte con `~`.
Resultado: mientras mantienes KEY[0] presionado, `rst = 1` y toda la CPU esta en reset.

### 6.2 El modo paso a paso y el debouncer

#### Por que existe el debouncer

Cuando presionas un boton fisico, los contactos metalicos dentro no se tocan de una
vez. Rebotan mecanicamente durante 5-20 ms antes de asentarse:

```
Lo que quieres:    1111100000000000000
Lo que pasa real:  1111101010100000000
                        ^^^rebote^^^
```

La FPGA corre a 50 millones de ciclos por segundo. Para ti es un solo press.
Para la FPGA, cada rebote es un press separado. Sin proteccion, un toque del boton
avanzaria 5-10 instrucciones en vez de una.

**Esto explica los bugs que se veian en modo paso a paso:** instrucciones que parecian
saltarse, registros con valores que no correspondian a la instruccion mostrada, y
comportamiento inconsistente entre un press y el siguiente. La CPU estaba correcta.
El problema era que el boton le mentia a la FPGA diciendo que fue presionado varias
veces cuando en realidad fue una. Y como el rebote mecanico no es deterministico
(a veces rebota 2 veces, a veces 7), el bug era diferente cada vez.

#### Que es un Flip-Flop (FF)

Antes de explicar la solucion, hay que entender el elemento basico que se usa:

Un FF tiene una sola regla: **en cada flanco de reloj, copia su entrada a su salida.
Entre flancos, se queda quieto sin importar que pase en la entrada.**

```
entrada:  0000011111100000
reloj:        ^       ^
salida:   0000001111110000
               ^copia  ^copia
```

Es como una camara que solo toma foto en momentos exactos, no un video continuo.

#### Problema 1 - Metaestabilidad (por que hay 2 FF al inicio)

Las senales que vienen de afuera del chip (botones, switches) pueden cambiar en
cualquier momento, incluso justo en el momento en que el reloj sube. Cuando eso
pasa, el FF interno no sabe si leer 0 o 1 y se queda en un estado intermedio
(ni 0 ni 1) por un momento. Esto se llama **metaestabilidad** y puede corromper
todo el sistema.

La solucion es poner dos FF en cadena:

```verilog
key1_sync0 <= KEY[1];      // FF1: puede entrar en metaestabilidad
key1_sync1 <= key1_sync0;  // FF2: lee FF1 un ciclo despues
```

Si FF1 entra en metaestabilidad, tiene un ciclo entero (20 nanosegundos) para
resolverse antes de que FF2 lo lea. La probabilidad de que siga inestable es
astronomicamente baja. `key1_sync1` sale limpia y estable, pero todavia con rebote.

#### Problema 2 - Rebote (el contador de estabilidad)

La solucion es simple: **solo acepto que el boton cambio si lleva mucho tiempo
siendo diferente.**

```verilog
if (key1_sync1 == key1_stable)
    key1_count <= 0;                // sigue igual, nada que hacer

else if (key1_count == DEBOUNCE_LIMIT - 1)
    key1_stable <= key1_sync1;      // lleva 1ms siendo diferente, acepto el cambio

else
    key1_count <= key1_count + 1;   // va camino al limite
```

- Si la senal rebota antes de llegar a 50000: el contador se resetea a cero y empieza de nuevo
- Si llega a 50000 sin rebotar (1ms estable): acepta el nuevo valor como real

```
key1_sync1:  111111010101000000000000000000
key1_count:  000000012012000001234...50000
                    ^rebotes^  ^press real^
key1_stable: 111111111111111111111111111110
                                          ^acepta aqui
```

Con `DEBOUNCE_LIMIT = 50000` a 50 MHz son exactamente **1 ms de estabilidad
requerida**. El rebote mecanico dura menos que eso, asi que se filtra completamente.

#### Deteccion del momento exacto del press

`key1_stable` ahora cambia limpiamente cuando el boton se acepta. Pero necesitamos
saber exactamente el ciclo en que cambio para generar un pulso de UN solo ciclo.

Se agrega un FF que guarda el valor anterior de `key1_stable`:

```verilog
key1_stable_prev <= key1_stable;   // siempre un ciclo atras

wire step_pulse = key1_stable_prev & ~key1_stable;
```

Vale 1 solo cuando `key1_stable` paso de 1 a 0 (el ciclo exacto del press).
El siguiente ciclo `key1_stable_prev` ya vale 0 y el pulso desaparece:

```
key1_stable:      111111110000000000
key1_stable_prev: 111111111000000000
step_pulse:       000000001000000000
                           ^un solo ciclo
```

Un press fisico con todo su rebote produce exactamente **un pulso de un ciclo**.

#### cpu_en: el enable general de la CPU

```verilog
wire cpu_en = SW[0] ? step_pulse : ~halted;
```

- `SW[0] = 0` (libre): `cpu_en = ~halted` - siempre 1 hasta que el programa termina
- `SW[0] = 1` (paso a paso): `cpu_en = step_pulse` - un pulso de un ciclo por press

Todos los `always @(posedge CLOCK_50)` en `top.v` (PC, registros, memoria de datos)
tienen la condicion `if (cpu_en)`. El reloj siempre corre a 50 MHz, pero la CPU solo
avanza cuando `cpu_en` es 1. Esto es **clock enable**: un patron estandar en FPGA que
evita crear multiples dominios de reloj (ver seccion 11 para la explicacion completa).

### 6.3 La deteccion de halt

```verilog
reg halted;
always @(posedge CLOCK_50 or posedge rst) begin
    if (rst)        halted <= 1'b0;
    else if (cpu_en && (instr == 32'h00000000 || instr == 32'h00100073))
                    halted <= 1'b1;
end
```

`0x00000000` es una instruccion nula: zona de memoria no inicializada que se lee cuando
el programa termino y no hay mas instrucciones. `0x00100073` es `ebreak`, la instruccion
que el crt0 ejecuta despues de que `main()` retorna para senalizar fin de programa.

Cuando se detecta cualquiera de las dos, `halted` se pone a 1 y no baja hasta el
siguiente reset. Como `cpu_en = SW[0] ? step_pulse : ~halted`, en modo libre `cpu_en`
pasa a 0 inmediatamente, congelando el PC y bloqueando todas las escrituras. En modo
paso a paso deja de importar porque el usuario no puede avanzar mas (LEDR[9] indica halt).

**Por que `halted` es un registro y no logica combinacional?** Porque si fuera
combinacional, en el mismo ciclo en que se detecta el ebreak `cpu_en` se pondria a 0,
el PC no avanzaria, el siguiente ciclo seguiria viendo el mismo ebreak y estaria en
un bucle. Al ser registro, `halted` se actualiza en el flanco: durante ese ciclo
`cpu_en` todavia es 1 (la instruccion se ejecuta normalmente), y a partir del
siguiente ciclo `cpu_en = 0` de forma estable.

### 6.4 El camino del PC (como decide donde ir)

```verilog
reg branch_cond;
always @(*) begin
    case (instr[14:12])   // func3
        3'b000: branch_cond =  alu_zero;       // BEQ
        3'b001: branch_cond = ~alu_zero;       // BNE
        3'b100: branch_cond =  alu_result[0];  // BLT  (SLT: 1 si a < b)
        3'b101: branch_cond = ~alu_result[0];  // BGE
        3'b110: branch_cond =  alu_result[0];  // BLTU (SLTU: 1 si a < b sin signo)
        3'b111: branch_cond = ~alu_result[0];  // BGEU
        default: branch_cond = 1'b0;
    endcase
end
wire branch_taken = branch & branch_cond;
assign pc_src = branch_taken | jal | jalr;

adder u_pc_plus4  (.a(pc_out), .b(32'd4),   .out(pc_plus4));
adder u_pc_branch (.a(pc_out), .b(imm_ext), .out(pc_branch));

mux2to1 u_mux_jump (.sel(jalr),   .a(pc_branch), .b(alu_result), .out(pc_jump));
mux2to1 u_mux_pc   (.sel(pc_src), .a(pc_plus4),  .b(pc_jump),    .out(pc_next));
```

Hay tres destinos posibles para el PC:

1. **PC + 4**: siguiente instruccion en secuencia (el caso normal)
2. **PC + inmediato** (`pc_branch`): saltos relativos - BEQ, BNE, JAL
3. **resultado de la ALU** (`alu_result`): solo JALR - salta a rs1 + inmediato
   (la ALU calcula esa suma)

La logica de decision para branches:
- `branch_cond` selecciona que senal mirar segun el tipo de branch (func3):
  - BEQ/BNE: miran `alu_zero` (resultado de restar rs1 - rs2)
  - BLT/BGE: miran `alu_result[0]` (resultado SLT - 1 si rs1 < rs2 con signo)
  - BLTU/BGEU: miran `alu_result[0]` (resultado SLTU - 1 si rs1 < rs2 sin signo)
- `branch_taken = branch & branch_cond`: el salto se toma si es una instruccion
  branch Y la condicion es verdadera
- Para jal/jalr: siempre saltan, independientemente de cualquier condicion

Los dos mux encadenados:
- Primero decide entre PC+imm y ALU_result (para JALR)
- Luego decide si saltar (pc_jump) o seguir en secuencia (pc_plus4)

### 6.5 El camino de datos completo

```verilog
// Operando A de la ALU: rs1 o PC (para AUIPC)
mux2to1 u_mux_alu_a (.sel(alu_a_src), .a(reg_data1), .b(pc_out), .out(alu_operand_a));

// Operando B de la ALU: rs2 o inmediato
mux2to1 u_mux_alu_b (.sel(alu_src), .a(reg_data2), .b(imm_ext), .out(alu_operand_b));

// Que escribir en el registro: resultado ALU o dato de memoria
mux2to1 u_mux_wb (.sel(mem_to_reg), .a(alu_result), .b(mem_data_out), .out(wb_data_pre));

// Para JAL/JALR: guardar PC+4 en rd en vez del resultado de la ALU
mux2to1 u_mux_jal (.sel(jal | jalr), .a(wb_data_pre), .b(pc_plus4), .out(wb_data));
```

El dato que finalmente se escribe en el registro destino (`wb_data`) pasa por dos
decisiones encadenadas:

1. ALU result vs dato de memoria - `mem_to_reg` elige (1 para LW, 0 para el resto)
2. Lo anterior vs PC+4 - `jal | jalr` elige (1 para JAL/JALR, guarda la
   direccion de retorno en rd)

### 6.6 Los almacenes de estado: regs[] y dmem[] en top.v

`register_file.v` y `data_memory.v` no tienen estado propio. Los flip-flops que
guardan los 32 registros y las 256 palabras de memoria de datos viven directamente
en `top.v`:

```verilog
reg [31:0] regs [0:31];   // 32 registros x 32 bits = 1 KB de logica
reg [31:0] dmem [0:255];  // 256 palabras x 32 bits = 8 KB de logica
```

**Escritura de registros:**

```verilog
integer ri;
always @(posedge CLOCK_50 or posedge rst) begin
    if (rst) begin
        for (ri = 0; ri < 32; ri = ri + 1) regs[ri] <= 32'b0;
    end else if (cpu_en && reg_write && instr[11:7] != 5'b0) begin
        regs[instr[11:7]] <= wb_data;
    end
end
```

En cada flanco de CLOCK_50:
- Si `rst`: todos los registros se ponen a 0
- Si `cpu_en && reg_write && rd != x0`: escribe `wb_data` en el registro destino

`instr[11:7]` son los 5 bits del campo `rd` de la instruccion actual. `wb_data` es
el resultado final del writeback (ALU, carga de memoria o PC+4 para JAL/JALR).
La condicion `!= 5'b0` protege x0 contra escritura.

**Escritura de memoria de datos:**

```verilog
always @(posedge CLOCK_50) begin
    if (cpu_en && mem_write)
        dmem[alu_result[31:2]] <= reg_data2;
end
```

Si la instruccion es `sw`: escribe `reg_data2` (el valor de rs2) en `dmem` en la
posicion `alu_result/4` (la ALU calculo la direccion base + offset en este mismo ciclo).
Sin reset: limpiar 256 palabras en reset seria costoso e innecesario, el programa
inicializa el stack explicitamente.

**Empaquetado hacia los modulos combinacionales:**

Los modulos `register_file` y `data_memory` no pueden recibir arreglos directamente
como puertos en Verilog-2001. La solucion es empaquetar cada arreglo en un wire plano:

```verilog
wire [32*32-1:0]   regs_flat;   // 1024 bits
wire [256*32-1:0]  dmem_flat;   // 8192 bits

genvar gri;
generate
    for (gri = 0; gri < 32; gri = gri + 1) begin : pack_regs
        assign regs_flat[32*gri +: 32] = regs[gri];
    end
endgenerate

genvar gmi;
generate
    for (gmi = 0; gmi < 256; gmi = gmi + 1) begin : pack_dmem
        assign dmem_flat[32*gmi +: 32] = dmem[gmi];
    end
endgenerate
```

Esto produce 32 + 256 = 288 `assign` combinacionales que mantienen `regs_flat` y
`dmem_flat` siempre sincronizados con `regs[]` y `dmem[]`. Cuando `top.v` escribe
`regs[5] <= 42` en el flanco, en el mismo ciclo (combinacionalmente) `regs_flat[191:160]`
pasa a valer 42, y `register_file.v` lo ve inmediatamente en sus salidas de lectura.

**Por que en top.v y no en los submodulos?** Ver seccion 11 para la explicacion
completa. En resumen: el teacher require que `register_file.v` y `data_memory.v` sean
puramente combinacionales (sin `clk`) para que el diseno cuente como monociclo. Mover
el almacenamiento a `top.v` satisface esa regla literalmente: los submodulos no tienen
`clk`, y los flip-flops viven en `top.v` donde ya hay logica sincrona permitida.

### 6.7 El display y los LEDs

```verilog
assign LEDR[0]   = SW[0];
assign LEDR[8:1] = 8'b0;
assign LEDR[9]   = halted;
```

- **LEDR[0]**: espejo de SW[0] - encendido = modo paso a paso activo
- **LEDR[8:1]**: apagados (toda la informacion de estado esta en el VGA)
- **LEDR[9]**: se enciende cuando el programa termina, nunca baja hasta reset

Toda la informacion detallada (PC, instruccion, ALU, registros x0-x31, senales de
control) se muestra en la pantalla VGA a traves de `vga_debug.v`. Los displays de
7 segmentos (HEX0-HEX5) no se usan en esta version.

---

## 7. Como se ejecuta una instruccion: trazado completo

Vamos a trazar `addi x1, x0, 5` a traves de todo el hardware.
Esta instruccion codificada es `0x00500093`.

### Paso 1 - Fetch

El PC contiene la direccion de esta instruccion (supongamos que es 0x00000000,
la primera instruccion). Esa direccion llega a `instruction_memory`, que devuelve
`0x00500093` de forma inmediata (combinacional).

### Paso 2 - Decode

El opcode es `0010011` (I_TYPE). `control_unit` ve ese opcode y pone:
- `reg_write = 1` (vamos a escribir en un registro)
- `alu_src = 1` (el segundo operando de la ALU es el inmediato, no rs2)
- `alu_a_src = 0` (primer operando es rs1, no el PC)
- `mem_write = 0`, `mem_read = 0` (no tocamos memoria)
- `alu_op = 2'b11` (alu_control mirara func3, ignorando func7 que es parte del inmediato)

Al mismo tiempo:
- `imm_gen` extrae el inmediato: bits[31:20] = `000000000101` = 5, extendido a 32 bits = 32'd5
- El banco de registros lee rs1 = `instr[19:15]` = `00000` = x0, devuelve 0
- `alu_control` recibe `alu_op=10`, func3=`000`, func7=`0000000` -> produce `alu_ctrl = 0000` (ADD)

### Paso 3 - Execute

Los mux eligen los operandos:
- Operando A: `reg_data1` = 0 (valor de x0)
- Operando B: `imm_ext` = 5 (porque `alu_src = 1`)

La ALU suma: `0 + 5 = 5`. `zero = 0`.

Como `branch = 0`, `jal = 0`, `jalr = 0`: `pc_src = 0`, el PC tomara `pc_plus4 = 4`.

### Paso 4 - Writeback

Al flanco de reloj:
- `reg_write = 1` y `cpu_en = 1`: el banco de registros escribe `wb_data = 5`
  en rd = `instr[11:7]` = `00001` = x1
- El PC se actualiza a 4 (siguiente instruccion)
- La memoria de datos no hace nada (mem_write = 0)

Resultado: x1 ahora vale 5. En un solo ciclo de reloj.

---

### Trazado de `lw x5, 0(x0)` - la instruccion mas larga

Esta es la instruccion que define la frecuencia maxima del reloj porque pasa
por mas etapas combinacionales:

1. **Instruction memory** -> entrega la instruccion
2. **Control unit** -> decodifica: `mem_read=1`, `mem_to_reg=1`, `alu_src=1`, `alu_op=00`
3. **Register file** -> lee x0 = 0
4. **imm_gen** -> extrae inmediato = 0
5. **Mux** -> elige inmediato como operando B
6. **ALU** -> suma 0 + 0 = 0 (la direccion de memoria)
7. **Data memory** -> lee `mem[0]`
8. **Mux** -> elige dato de memoria como resultado
9. **Register file** -> espera el flanco para escribir en x5

Todo esto en cadena, sin registros intermedios. La suma de los retardos de
propagacion de cada bloque define el periodo minimo del reloj. Si el reloj
va mas rapido que eso, el dato no llega a tiempo al banco de registros y
se escribe un valor incorrecto.

---

### Trazado de `beq x1, x2, offset` - un salto condicional BEQ

1. `control_unit`: `branch=1`, `alu_op=01`, `reg_write=0`
2. `alu_control`: `alu_op=01`, func3=`000` (BEQ) -> SUB
3. ALU: `x1 - x2`. Si x1 == x2, resultado = 0, `alu_zero = 1`
4. `branch_cond`: func3=000 -> `branch_cond = alu_zero = 1`
5. `branch_taken = branch & branch_cond = 1 & 1 = 1`
6. `pc_src = branch_taken | jal | jalr = 1` -> el PC toma `pc_branch = PC + offset`
7. Si x1 != x2: `alu_zero = 0`, `branch_cond = 0`, `pc_src = 0`, el PC toma `PC + 4`

El salto no necesita la ALU para calcular el destino - eso lo hace el sumador
`u_pc_branch` en paralelo. La ALU solo sirve para hacer la comparacion.

---

### Trazado de `blt x1, x2, offset` - un salto condicional BLT

1. `control_unit`: `branch=1`, `alu_op=01`, `reg_write=0`
2. `alu_control`: `alu_op=01`, func3=`100` (BLT) -> SLT (comparar con signo)
3. ALU: ejecuta SLT. Si x1 < x2 (con signo), `alu_result = 32'd1`; si no, `alu_result = 32'd0`
4. `branch_cond`: func3=100 -> `branch_cond = alu_result[0]`
   - Si x1 < x2: `alu_result[0] = 1`, `branch_cond = 1` -> salto tomado
   - Si x1 >= x2: `alu_result[0] = 0`, `branch_cond = 0` -> no salta
5. `branch_taken = branch & branch_cond`
6. `pc_src = branch_taken` -> el PC toma `pc_branch = PC + offset` si se salta

La diferencia con BEQ: en vez de usar `alu_zero`, se usa directamente el bit 0
del resultado de SLT, que el hardware de la ALU pone a 1 cuando a < b.

---

## 8. Por que separar control_unit y alu_control

Podria hacerse en un solo modulo que mire opcode + func3 + func7 directamente.
Pero separarlo en dos niveles hace que cada modulo haga una sola cosa.
`alu_control` es el mismo para instrucciones R e I aritmeticas aunque tienen opcodes
distintos - `control_unit` les manda `alu_op=10` a ambas y `alu_control` resuelve el
resto. Agregar una instruccion nueva solo requiere tocar el modulo correcto, no los dos.
A esto se le llama decodificacion de dos niveles.

---

## 9. Resumen visual del flujo de datos

```
program.hex
    |
    v
[instruction_memory] --instr--> [control_unit] --> senales de control
         |                           |
         |                    [imm_gen] --> imm_ext
         |                           |
         v                           v
[register_file] --rs1--> [mux] --> alu_operand_a
[register_file] --rs2--> [mux] --> alu_operand_b (o imm_ext)
                                        |
                                        v
                                     [alu] --> alu_result --> [mux] --> wb_data
                                       |                         |
                                  alu_zero                  [data_memory]
                                  alu_result[0]                  |
                                       |                         v
                                       v                [register_file] (escritura)
                                  [branch_cond]
                                       |
                                  [pc logic]
                                       |
                                       v
                                  [pc] --> siguiente ciclo
```

---

## 10. Lo que hace el crt0 antes de llegar a main()

Cuando cargas el programa en la FPGA y sueltas el reset, la CPU empieza en
la direccion 0. Ahi no esta tu `main()` - esta el **crt0** (C RunTime 0),
un pequeno arranque que el ensamblador agrega automaticamente:

```asm
j handle_reset      # salta sobre el vector de trap
j handle_trap       # vector de trap (PC=4) - si algo falla, viene aqui
handle_reset:
  li sp, 1024       # inicializa el stack pointer al tope de la RAM de datos
  call main         # llama a tu main() -- auipc + jalr
  ebreak            # cuando main() retorna, senaliza fin de programa
handle_trap:
  li x10, 0x123     # codigo de error en x10
  j handle_trap     # loop infinito en caso de excepcion
```

`call main` se expande en dos instrucciones:
1. `auipc ra, offset_hi` - ra = PC + parte alta del offset a main
2. `jalr ra, ra, offset_lo` - salta a ra + parte baja, guarda PC+4 en ra

Cuando `main()` hace `return`, la instruccion `jr ra` salta a la direccion
guardada en ra, que es exactamente la instruccion despues del `jalr` - el `ebreak`.
La CPU detecta el `ebreak` y congela todo. En ese momento LEDR[9] se enciende
y LEDR[8:1] muestra el valor de x10 (el valor de retorno de main).

---

## 11. Sincronico, asincronico y combinacional: que significa cada cosa

Antes de explicar por que `register_file` y `data_memory` no tienen reloj, es
importante aclarar estos terminos porque se confunden con frecuencia.

### Los cuatro conceptos

| Termino | Significado | Ejemplo en esta CPU |
|---------|-------------|---------------------|
| **Combinacional** | La salida depende SOLO de las entradas actuales. Sin memoria, sin reloj. | ALU, imm_gen, control_unit, register_file.v |
| **Secuencial** | La salida depende de las entradas actuales Y del estado interno. Tiene memoria. | pc.v, los regs[] y dmem[] en top.v |
| **Sincrono** | Los cambios de estado ocurren SOLO en el flanco de reloj (`posedge clk`) | Todo `always @(posedge CLOCK_50)` en top.v |
| **Asincrono** | Los cambios ocurren inmediatamente cuando cambian las entradas (sin esperar reloj) | Los `assign` y `always @(*)` sin clk |

Cuando el teacher dice "solo el PC es sincrono", quiere decir: el unico modulo con
un puerto `clk` y un `always @(posedge clk)` es `pc.v`. Todos los demas modulos
responden combinacionalmente a sus entradas sin necesitar un flanco de reloj.

### La diferencia practica en esta CPU

**Lectura combinacional (lo que tiene register_file y data_memory):**
```
addr cambia -> read_data se actualiza instantaneamente (mismo ciclo)
```
No hay que esperar ningun flanco. La salida siempre refleja la entrada actual.
Esto es lo que necesita una CPU monociclo: el valor del registro o memoria tiene
que estar disponible en el mismo ciclo en que se necesita para la ALU.

**Escritura sincrona (lo que hacen los always @(posedge CLOCK_50) en top.v):**
```
posedge CLOCK_50 -> si cpu_en && condicion: guardar nuevo valor
```
El valor almacenado solo cambia en el flanco. Esto es correcto para el writeback:
quieres que el resultado calculado en el ciclo N se guarde al FINAL de ese ciclo,
no mientras la instruccion todavia se esta ejecutando.

### Por que no usar always @(*) para escribir (el error original)

La version original de `data_memory.v` y `register_file.v` usaba:

```verilog
always @(*) begin
    if (mem_write) mem[addr] = data;  // PELIGROSO
end
```

Esto parece correcto pero tiene dos problemas graves:

**Problema 1 - Latch transparente:**

Cuando Quartus sintetiza `if (enable) salida = entrada` sin un `else`, no puede
inferir un flip-flop (porque no hay reloj). En cambio infiere un **latch transparente**.

La diferencia es critica:

- **Flip-flop**: solo cambia en el flanco de reloj. Entre flancos es inmune a cualquier
  cambio en la entrada. Timing perfectamente definido.
- **Latch transparente**: cuando `enable=1`, la salida sigue a la entrada en tiempo
  real, como si fuera un cable directo. Cuando `enable=0`, mantiene el ultimo valor.

#### Como lo reporta Quartus

Quartus emite este warning textual cuando sintetiza un `always @(*)` con
`if (enable) out = in` sin `else`:

```
Warning (10240): Verilog HDL Always Construct warning at data_memory.v(N):
inferring latch(es) for variable "mem[X]", which holds its previous value in
one or more paths through the always construct
```

Este warning no es informativo: es la herramienta diciendote que el circuito
sintetizado no es lo que dibujaste en el esquema. Se puede verificar abriendo
el RTL Viewer de Quartus: en vez de un bloque de memoria con WE (write enable),
aparece un simbolo de latch con ENABLE. Son primitivas de silicio completamente
distintas.

Esto es mandato del estandar IEEE Std 1364-2001, seccion 9.9.1:

> "If a variable is assigned in some, but not all, branches of an if statement
> within a combinational always block, the synthesizer infers a latch to preserve
> the previous value."

Quartus no tiene opcion: si el codigo tiene esa forma, sintetiza un latch.
No es una decision de diseno de Altera.

#### La cadena de propagacion en esta CPU a 50 MHz

A 50 MHz el periodo de reloj es 20 ns. Para un `sw`, la cadena combinacional
desde el flanco de reloj anterior hasta que las senales se asientan es:

```
posedge CLK
    -> PC sale del registro          (tiempo 0 ns)
    -> instruction_memory devuelve instr        (~2-3 ns)
    -> control_unit calcula mem_write=1          (~1 ns mas)  <- latch se abre aqui
    -> imm_gen calcula el offset                 (~1-2 ns)
    -> register_file lee rs1 (base) y rs2 (data) (~2-3 ns)
    -> ALU suma base + offset -> alu_result       (~5-8 ns)   <- addr se asienta aqui
    -> reg_data2 (dato a escribir) se estabiliza  (~8-10 ns)
    -> siguiente posedge CLK                     (t = 20 ns)
```

En numeros concretos para Cyclone V a 50 MHz:

| Evento                     | Tiempo desde flanco |
|----------------------------|---------------------|
| `mem_write` = 1            | ~4 ns               |
| `reg_data2` estable        | ~8-10 ns            |
| `alu_result` (addr) estable| ~12-16 ns           |
| Siguiente flanco de reloj  | 20 ns               |

**Con el flip-flop (diseno actual en `top.v`):** el flanco en t=20 ns captura
`alu_result` y `reg_data2` cuando llevan 4-8 ns completamente estables.
Inmunidad total a todo lo que paso antes.

**Con el latch transparente (el diseno rechazado):** `mem_write=1` en t=4 ns
abre el latch. El latch queda transparente desde t=4 ns hasta t=20 ns, es decir,
**16 de los 20 ns del ciclo**. Durante esos 16 ns, todo lo que aparezca en
`addr` y `data` entra directo en la memoria. Los valores transitorios de la
ALU y del banco de registros se escriben como si fueran el valor final:

```
t (ns):    0    4         10        16       20
           |    |         |         |        |
CLOCK_50:  |____|_________|_________|________|^___
mem_write: ____/ latch abierto              \____
addr:      XXXXXXXXXXXXXXXXXXXXXXXXXXXX[corr]
data:      XXXXXXXXXXXXXXXXX[corr]
mem[addr]: ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? [???]
                                            ^flanco captura el ultimo valor visto
```

El latch no captura "el valor final" sino "el ultimo valor mientras estuvo abierto".
Si en t=19.9 ns `addr` todavia estaba en un estado de transicion, ese es el valor
que queda guardado en memoria.

#### Por que aparece exactamente `0xFFFFFF78` en vez de `0x78`

Ese patron no es aleatorio. Es evidencia forense del mecanismo especifico.

En esta CPU, `alu_result` es la suma `rs1 + offset` calculada por la ALU.
Antes de que la ALU termine de calcular, los bits de la suma se propagan de
menos significativo a mas significativo (propagacion de carry). Durante la
propagacion, los bits altos pueden quedar temporalmente en `1` mientras el
carry se propaga hacia ellos.

`0xFFFFFF78 = 1111 1111 1111 1111 1111 1111 0111 1000`

Los bits altos `0xFFFFFF` son todos unos. Eso corresponde exactamente a un
estado transitorio de la suma donde los bits `[31:8]` aun no resolvieron el
carry y quedaron en `1` mientras los bits `[7:0]` ya mostraban el resultado
correcto `0x78`. El latch capturo ese estado intermedio de la propagacion del carry.

Si hubiera sido ruido electrico aleatorio, los valores serian impredecibles cada
vez. Que los 8 bits bajos sean siempre correctos y los 24 altos sean siempre
`0xFF` identifica el mecanismo como captura de carry intermedio: evidencia del latch,
no de ruido.

#### Por que la simulacion RTL no lo muestra

El simulador RTL (ModelSim/Questa/Icarus) opera con **tiempo cero**. Cuando el
reloj sube, todas las asignaciones se resuelven en delta-cycles sin tiempo fisico.
No existe el concepto de "la ALU tarda 8 ns en propagar el carry". Para el
simulador, `alu_result` pasa del valor anterior al valor nuevo instantaneamente
en el mismo delta.

Esto significa que en simulacion:
- `mem_write` se pone en 1
- En el mismo delta, `alu_result` ya tiene el valor final correcto
- El latch "transparente" captura el valor correcto por construccion

En hardware real, los 12-16 ns de propagacion son fisicos e inevitables.
La simulacion funcional (RTL) es necesaria para verificar logica, pero es
**insuficiente para detectar hazards de latch** porque no modela retardos.

La herramienta que si los detecta es la **post-synthesis timing simulation**
con el netlist real que produce Quartus y las anotaciones SDF del Place & Route.
Ahi si aparecen los glitches porque el simulador usa los retardos reales de cada
celda. Es una simulacion mucho mas lenta que la RTL y que la mayoria de los
flujos de desarrollo no ejecutan en cada iteracion.

#### El flip-flop como solucion

El `always @(posedge CLOCK_50)` en `top.v` (linea 210) sintetiza un flip-flop
real con una ventana de captura de ~0.5 ns alrededor del flanco (definida por
los parametros de setup y hold de la celda en Cyclone V). En ese momento,
`alu_result` lleva 4-8 ns completamente estable. La captura es limpia
por construccion, independientemente de lo que haya pasado en los 16 ns anteriores.

Ademas, `cpu_en` como clock-enable es el patron correcto en Cyclone V: usa el
puerto `CE` dedicado del flip-flop en lugar de crear un segundo dominio de reloj,
eliminando cualquier posibilidad de glitch por mux de reloj. Quartus reconoce el
patron `if (cpu_en && condicion) reg <= valor` y lo mapea directamente al CE sin
logica adicional en el camino critico.

**Problema 2 - Bucle combinacional:**

Cuando una instruccion usa el mismo registro como fuente y destino, por ejemplo:

```asm
add x1, x1, x2    # x1 = x1 + x2
```

El registro x1 se lee (para ser operando de la ALU) Y se escribe (para guardar el
resultado) en el mismo ciclo. Con un latch, esto crea un camino combinacional directo
de la salida de vuelta a la entrada:

```
regs[1] (salida/lectura)
    |
    v
   ALU  --> resultado --> regs[1] (entrada/escritura)
    ^                          |
    |__________________________|
           bucle!
```

La salida retroalimenta la entrada sin ningun elemento de memoria que rompa el ciclo.
El circuito oscila a la velocidad maxima de propagacion de la logica, que son
gigahercios. Desde afuera se ve como ruido electrico puro en todas las senales
conectadas a ese registro.

**Lo que se veia en la FPGA con estos bugs:**

- Valores como `0xFFFFFF78` en vez de `0x78` — bits correctos mezclados con basura
- Resultados de multiplicaciones que daban 0 en vez del producto correcto
- Funciones que retornaban a la direccion 0 en vez de al caller (el registro `ra`
  guardaba `0x00000000` en vez de la direccion de retorno)
- Comportamiento diferente cada vez que se compilaba o se cambiaba algo no relacionado,
  porque el timing de los glitches depende del ruteo interno de la FPGA que cambia
  con cada compilacion

Todo esto desaparece con flip-flops reales porque el flanco de reloj actua como
barrera: no importa cuanto oscilen las entradas durante el ciclo, el FF solo captura
el valor en el momento exacto del flanco, cuando ya todo se asento.

### Por que no poner clk en register_file.v y data_memory.v directamente

La solucion tecnica obvia es agregar `always @(posedge clk)` a esos modulos.
Eso funciona perfectamente en hardware y fue la primera solucion que se implemento.
El problema es que el teacher lo considera una violacion de la regla monociclo:
si `register_file.v` tiene su propio `posedge clk`, ya no es un bloque combinacional
sino un modulo secuencial, y el diseno deja de ser "solo el PC es sincrono".

### La solucion adoptada: almacenamiento en top.v

Los flip-flops se mueven a `top.v`, que ya tiene permiso para tener logica sincrona.
Los modulos `register_file.v` y `data_memory.v` se convierten en muxes puros:
reciben todos los valores como entradas (via `regs_flat` y `mem_flat`) y simplemente
seleccionan cual mostrar segun la direccion pedida.

```
top.v                          register_file.v
+------------------+           +------------------+
| regs[0..31] <--- | posedge   |                  |
|   flip-flops     | clk       | regs_flat -----+ |
|                  |           |                | |
| regs_flat -----> |---------> | mux:           | |
|   (1024 bits)    |           |  rs1 -> out1   | |
+------------------+           |  rs2 -> out2   | |
                                +------------------+
                                  sin clk, sin estado
```

El resultado satisface ambas restricciones:
- **Regla del teacher**: `register_file.v` y `data_memory.v` no tienen `clk`. Son
  puramente combinacionales. Solo `pc.v` (y `top.v`) tienen logica sincrona.
- **Correccion en FPGA**: los flip-flops son reales (`posedge CLOCK_50`), no latches.
  Quartus los sintetiza como registros con clock enable, sin glitches.

### Clock enable: por que cpu_en va dentro del if y no como reloj

Se podria intentar usar `cpu_en` directamente como reloj:

```verilog
// MAL: cpu_en como reloj
always @(posedge cpu_en) begin
    regs[rd] <= wb_data;
end
```

Esto tiene los mismos problemas que el latch: `cpu_en` es una senal combinacional
derivada de `SW[0]`, `step_pulse` y `~halted`. Tiene glitches durante su propagacion.
Usarla como reloj crea un segundo dominio de reloj con rutas de reloj no garantizadas.

La forma correcta es el **clock enable**:

```verilog
// BIEN: CLOCK_50 como reloj, cpu_en como condicion
always @(posedge CLOCK_50) begin
    if (cpu_en && reg_write && rd != 5'b0)
        regs[rd] <= wb_data;
end
```

El flip-flop siempre dispara en `posedge CLOCK_50` (reloj limpio, con routing dedicado
en la FPGA). Pero solo actua cuando `cpu_en=1`. Quartus reconoce este patron y lo
sintetiza usando la entrada `CE` (clock enable) dedicada de cada flip-flop en el
Cyclone V, que es una entrada libre de timing adicional.

Efecto observable: en modo paso a paso, la CPU avanza exactamente una instruccion
por press de KEY[1], porque `cpu_en = step_pulse` dura exactamente un ciclo de
CLOCK_50. El reloj de 50 MHz sigue corriendo, pero el flip-flop solo captura ese
unico ciclo.

---

## 12. Lo que NO hace esta CPU (y por que)

- **No hay pipeline**: una instruccion completa por ciclo, sin solapamiento
- **No hay cache**: acceso directo a BRAM, latencia fija de 0 ciclos adicionales
- **No hay excepciones reales**: `ebreak` se trata como halt, no como excepcion
- **No hay MMU**: la CPU ve directamente las direcciones fisicas, sin traduccion
- **No hay multiplicacion nativa**: por eso `multiplicar()` en el C usa un loop de sumas
- **No hay division nativa**: misma razon

Estas son caracteristicas de RV32I base. Las extensiones M (multiply/divide),
F (float), C (compressed) existen en RISC-V pero no se implementaron aqui.
