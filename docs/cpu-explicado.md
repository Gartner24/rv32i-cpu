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

Esta CPU usa **arquitectura Harvard**: tiene dos memorias completamente separadas:

- **Memoria de instrucciones** (`instruction_memory.v`): solo lectura, guarda el programa
- **Memoria de datos** (`data_memory.v`): lectura y escritura, guarda variables y el stack

En cambio, tu computadora usa **arquitectura Von Neumann**: programa y datos comparten
la misma memoria RAM. Harvard es mas simple de implementar en FPGA y evita conflictos
(no puedes leer una instruccion y leer un dato al mismo tiempo si es la misma memoria).

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
Entradas: clk, rst, en, pc_next[31:0]
Salida:   pc_out[31:0]
```

El PC (Program Counter) es el registro mas importante de la CPU. Guarda **la direccion
de la instruccion que se esta ejecutando ahora mismo**. Es simplemente un registro de
32 bits que se actualiza en cada flanco de reloj.

- Si `rst = 1`: se pone a 0x00000000 (inicio del programa)
- Si `en = 1`: toma el valor de `pc_next` (la siguiente direccion)
- Si `en = 0`: se queda donde esta (CPU congelada - modo step o halt)

`pc_next` puede ser `PC + 4` (instruccion siguiente) o una direccion de salto.
`top.v` decide cual de las dos usar.

### 5.2 `instruction_memory.v` - La ROM del programa

```
Entrada: addr[31:0]
Salida:  instr[31:0]
```

Es una memoria de solo lectura (ROM) que contiene el programa. Se carga con el
contenido de `program.hex` al momento de sintetizar en Quartus. Tiene 1024 posiciones
de 32 bits = 4 KB de programa.

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

| Senal | Significado cuando vale 1 |
|-------|--------------------------|
| `reg_write` | Permite escribir en el banco de registros al final del ciclo |
| `alu_src` | La ALU usa el inmediato como segundo operando (en vez de rs2) |
| `alu_a_src` | La ALU usa el PC como primer operando (solo AUIPC) |
| `mem_write` | Escribe en la memoria de datos (instruccion SW) |
| `mem_read` | Lee de la memoria de datos (instruccion LW) |
| `mem_to_reg` | El dato que se escribe en el registro viene de memoria (no de la ALU) |
| `branch` | Es una instruccion de salto condicional (BEQ, BNE, etc.) |
| `jal` | Es un salto incondicional tipo JAL |
| `jalr` | Es un salto incondicional tipo JALR |
| `alu_op` | Pista de 2 bits para `alu_control` sobre que operacion hacer |

`alu_op` no dice exactamente que operacion hacer - solo da una pista:
- `00`: siempre ADD (para loads, stores, LUI)
- `01`: siempre SUB (para branches - comparar es restar y ver si da 0)
- `10`: mirar func3 y func7 para decidir (para instrucciones R e I aritmeticas)

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

### 5.5 `alu.v` - La unidad aritmetico-logica

```
Entradas: a[31:0], b[31:0], alu_ctrl[3:0]
Salidas:  result[31:0], zero
```

Hace la operacion matematica. Recibe dos numeros de 32 bits y un codigo de operacion,
y produce el resultado. Es completamente combinacional - no hay reloj, el resultado
esta disponible inmediatamente (con algo de retardo de propagacion).

La senal `zero` vale 1 cuando `result == 0`. Se usa para los saltos condicionales:
`BEQ` hace `rs1 - rs2` con la ALU, y si el resultado es 0 (son iguales), `zero = 1`
y el salto se toma. Comparar igualdad es restar y ver si da cero.

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

### 5.7 `register_file.v` - El banco de registros

```
Entradas: clk, reg_write, en, rs1[4:0], rs2[4:0], rd[4:0], write_data[31:0],
          debug_addr[4:0]
Salidas:  read_data1[31:0], read_data2[31:0], debug_data[31:0], exit_code[31:0]
```

Son los 32 registros x0-x31. Tiene:
- **2 puertos de lectura combinacionales**: `rs1` y `rs2` - entran las direcciones
  del primer y segundo registro fuente, salen sus valores inmediatamente
- **1 puerto de escritura sincrono**: en el flanco de reloj, si `reg_write && en`,
  escribe `write_data` en el registro `rd`
- **Puerto de debug**: `debug_addr` (viene de SW[7:3]) permite leer cualquier
  registro desde los switches sin interferir con la ejecucion
- **`exit_code`**: siempre lee x10 (a0), conectado directamente a LEDR[8:1]
  cuando el programa termina

La proteccion de x0 esta en la lectura: siempre devuelve 0 sin importar que haya
guardado. La escritura a x0 no esta bloqueada, pero no tiene efecto porque
nadie lee ese valor guardado - la lectura siempre devuelve 0.

Por que escritura sincrona y lectura asincrona? Porque en un monociclo necesitas
leer los valores del registro en el mismo ciclo en que llegas aqui, sin esperar
al siguiente flanco. Pero la escritura debe pasar al final del ciclo, cuando ya
tienes el resultado calculado - de ahi que sea sincrona.

### 5.8 `data_memory.v` - La RAM de datos

```
Entradas: clk, mem_write, mem_read, en, addr[31:0], write_data[31:0]
Salida:   read_data[31:0]
```

256 palabras de 32 bits = 1 KB de datos. Aqui viven las variables y el stack.

- Escritura sincrona: en el flanco de reloj, si `mem_write && en`
- Lectura combinacional: si `mem_read = 1`, `read_data = mem[addr[31:2]]`
  Si `mem_read = 0`, `read_data = 0` (no contaminamos el bus con basura)

El stack crece hacia abajo desde la direccion 1024 (el tope de la memoria).
La primera instruccion del crt0 pone `sp = 1024`. Cada funcion baja el sp
con `addi sp, sp, -N` para reservar espacio en el stack frame.

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

### 6.2 El modo paso a paso

```verilog
reg key1_s0, key1_s1, key1_prev;
always @(posedge clk) begin
    key1_s0   <= KEY[1];
    key1_s1   <= key1_s0;
    key1_prev <= key1_s1;
end
wire step_pulse = key1_prev & ~key1_s1;
wire en = SW[0] ? step_pulse : 1'b1;
```

Por que tres registros para un boton? Por **sincronizacion y deteccion de flanco**.

**Sincronizacion (key1_s0, key1_s1):** Las senales que vienen de fuera del chip
(botones, switches) pueden cambiar en cualquier momento, incluso en medio de un
flanco de reloj. Esto puede poner los flip-flops internos en un estado indefinido
(ni 0 ni 1 - metaestabilidad). La solucion es pasar la senal por dos flip-flops
sincronos antes de usarla. Si el primero entra en metaestabilidad, tiene un ciclo
completo para resolverse antes de que el segundo lo lea. A este patron de dos FF se le llama sincronizador de dos etapas.

**Deteccion de flanco (key1_prev):** `step_pulse = key1_prev & ~key1_s1` es 1 solo
cuando `key1_prev = 1` (antes era alto) y `key1_s1 = 0` (ahora es bajo). Eso es
exactamente un flanco de bajada - el momento en que presionas el boton. Dura
exactamente un ciclo de reloj, lo que hace avanzar la CPU exactamente un paso.

`en = SW[0] ? step_pulse : 1'b1`:
- SW[0] = 0 (libre): `en` siempre vale 1 - la CPU avanza cada ciclo a 50 MHz
- SW[0] = 1 (paso a paso): `en` solo vale 1 el ciclo en que presionas KEY[1]

### 6.3 La deteccion de halt

```verilog
reg halted;
wire cpu_en = en & ~halted;

always @(posedge clk) begin
    if (rst)
        halted <= 1'b0;
    else if (en && (instr == 32'h00000000 || instr == 32'h00100073))
        halted <= 1'b1;
end
```

`0x00000000` es una instruccion nula (zona de memoria no inicializada - el programa
termino y no hay mas instrucciones). `0x00100073` es `ebreak` - la instruccion que
el crt0 ejecuta despues de que `main()` retorna.

Cuando se detecta cualquiera de las dos, `halted` se pone a 1 y ya no baja hasta
el siguiente reset. `cpu_en = en & ~halted` asegura que aunque `en` siga siendo 1
(en modo libre), la CPU no avanza: PC, banco de registros y memoria de datos
dejan de actualizarse. Los valores quedan congelados.

Por que `halted` es un registro y no combinacional? Porque si fuera combinacional,
en el mismo ciclo en que se detecta el ebreak, `cpu_en` se pondria a 0 y el PC
no avanzaria, pero en el siguiente ciclo seguiria viendo el mismo ebreak y
nunca saldria del estado. Al ser registro, `halted` se pone a 1 en el flanco
del ciclo en que se detecta, y desde ese ciclo en adelante `cpu_en = 0` de forma estable.

### 6.4 El camino del PC (como decide donde ir)

```verilog
assign pc_src = (branch & alu_zero) | jal | jalr;

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

La logica de decision:
- `pc_src = (branch & alu_zero) | jal | jalr`
  - Para branch: solo salta si la condicion es verdadera (`alu_zero = 1` significa
    que rs1 - rs2 = 0, es decir rs1 == rs2 para BEQ)
  - Para jal: siempre salta
  - Para jalr: siempre salta, pero al resultado de la ALU en vez de PC+imm

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

1. ALU result vs dato de memoria → `mem_to_reg` elige (1 para LW, 0 para el resto)
2. Lo anterior vs PC+4 → `jal | jalr` elige (1 para JAL/JALR, guarda la
   direccion de retorno en rd)

### 6.6 El display y los LEDs

```verilog
// Decimal para el indice del registro (solo modo SW[9:8]=11)
wire [4:0] reg_idx  = SW[7:3];
wire [3:0] tens     = (reg_idx >= 30) ? 3 : (reg_idx >= 20) ? 2 :
                      (reg_idx >= 10) ? 1 : 0;
wire [4:0] tens_x10 = (tens == 3) ? 30 : (tens == 2) ? 20 :
                      (tens == 1) ? 10 : 0;
wire [3:0] ones     = reg_idx - tens_x10;
wire [15:0] reg_half = SW[1] ? debug_reg_data[31:16] : debug_reg_data[15:0];

reg [23:0] display_value;
always @(*) begin
    case (SW[9:8])
        2'b00: display_value = pc_out[23:0];
        2'b01: display_value = instr[23:0];
        2'b10: display_value = alu_result[23:0];
        2'b11: display_value = {tens, ones, reg_half};
    endcase
end
```

Los 24 bits de `display_value` van directo a los seis displays de 7 segmentos,
4 bits cada uno (un nibble = un digito hex por display).

En modo registro (SW[9:8]=11), los 24 bits se arman asi:
- bits[23:20]: digito de las decenas del indice (0-3, en decimal)
- bits[19:16]: digito de las unidades del indice (0-9, en decimal)
- bits[15:0]: 16 bits del valor del registro (hex)

Los displays 5 y 4 mostraran entonces el numero del registro en decimal (ej: "01"
para x1, "31" para x31), y los displays 3, 2, 1, 0 mostraran su valor en hex.

```verilog
assign LEDR[0]   = SW[0];
assign LEDR[8:1] = halted ? exit_code[7:0] : pc_out[9:2];
assign LEDR[9]   = halted;
```

- **LEDR[0]**: espejo de SW[0] - encendido = modo paso a paso
- **LEDR[8:1]**: dual - mientras corre muestra el indice de instruccion (PC/4),
  cuando termina muestra los 8 bits bajos del valor de retorno de main (x10/a0)
- **LEDR[9]**: se enciende cuando el programa termina, nunca baja hasta reset

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
- `alu_op = 2'b10` (alu_control mirara func3)

Al mismo tiempo:
- `imm_gen` extrae el inmediato: bits[31:20] = `000000000101` = 5, extendido a 32 bits = 32'd5
- El banco de registros lee rs1 = `instr[19:15]` = `00000` = x0, devuelve 0
- `alu_control` recibe `alu_op=10`, func3=`000`, func7=`0000000` → produce `alu_ctrl = 0000` (ADD)

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

1. **Instruction memory** → entrega la instruccion
2. **Control unit** → decodifica: `mem_read=1`, `mem_to_reg=1`, `alu_src=1`, `alu_op=00`
3. **Register file** → lee x0 = 0
4. **imm_gen** → extrae inmediato = 0
5. **Mux** → elige inmediato como operando B
6. **ALU** → suma 0 + 0 = 0 (la direccion de memoria)
7. **Data memory** → lee `mem[0]`
8. **Mux** → elige dato de memoria como resultado
9. **Register file** → espera el flanco para escribir en x5

Todo esto en cadena, sin registros intermedios. La suma de los retardos de
propagacion de cada bloque define el periodo minimo del reloj. Si el reloj
va mas rapido que eso, el dato no llega a tiempo al banco de registros y
se escribe un valor incorrecto.

---

### Trazado de `beq x1, x2, offset` - un salto condicional

1. `control_unit`: `branch=1`, `alu_op=01` (SUB fijo), `reg_write=0`
2. `alu_control`: alu_op=01 → siempre SUB
3. ALU: `x1 - x2`. Si x1 == x2, resultado = 0, `zero = 1`
4. `pc_src = branch & alu_zero = 1 & 1 = 1` → el PC toma `pc_branch = PC + offset`
5. Si x1 != x2: `zero = 0`, `pc_src = 0`, el PC toma `PC + 4`

El salto no necesita la ALU para calcular el destino - eso lo hace el sumador
`u_pc_branch` en paralelo. La ALU solo sirve para hacer la comparacion.

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
                                    alu_zero                [data_memory]
                                       |                         |
                                       v                         v
                                  [pc logic]            [register_file] (escritura)
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
La CPU detecta el `ebreak` y congela todo. En ese momento LEDR[9] se enciende.

---

## 11. Lo que NO hace esta CPU (y por que)

- **No hay pipeline**: una instruccion completa por ciclo, sin solapamiento
- **No hay cache**: acceso directo a BRAM, latencia fija de 0 ciclos adicionales
- **No hay excepciones reales**: `ebreak` se trata como halt, no como excepcion
- **No hay MMU**: la CPU ve directamente las direcciones fisicas, sin traduccion
- **No hay multiplicacion nativa**: por eso `multiplicar()` en el C usa un loop de sumas
- **No hay division nativa**: misma razon

Estas son caracteristicas de RV32I base. Las extensiones M (multiply/divide),
F (float), C (compressed) existen en RISC-V pero no se implementaron aqui.
