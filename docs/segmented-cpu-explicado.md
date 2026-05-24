# CPU RV32I Segmentada (pipeline de 5 etapas) - Explicacion completa

Este documento explica **todo** el proyecto `segmented_cpu/`: que hace cada
archivo, cada modulo (puertos y comportamiento) y, en detalle y con numeros de
linea, el archivo `top.v` que conecta todo.

Las referencias de linea son del estado actual de `segmented_cpu/top.v`. Si
editas el archivo, los numeros pueden correrse.

---

## 1. Vision general

La CPU ejecuta el ISA RV32I en un **pipeline de 5 etapas**. En vez de hacer una
instruccion completa por ciclo (monociclo), divide el trabajo en 5 pasos y tiene
varias instrucciones "en vuelo" a la vez, una en cada etapa:

```
   IF        ID         EX        MEM        WB
 (fetch)  (decode)  (execute)  (memoria) (write-back)
   |         |          |          |          |
  busca    lee reg.   ALU /     lee/escribe  escribe
  instr.   y decod.   saltos    data memory  registro
```

Entre etapa y etapa hay un **registro de pipeline** (un banco de flip-flops) que
guarda lo que la etapa produjo, para que la siguiente lo use el ciclo siguiente:

```
 IF -> [IF/ID] -> ID -> [ID/EX] -> EX -> [EX/MEM] -> MEM -> [MEM/WB] -> WB
```

### Correspondencia con el diagrama de Patterson & Hennessy

| Bloque del diagrama        | Archivo en este proyecto                    |
|----------------------------|---------------------------------------------|
| PC                         | `pc.v`                                      |
| Instruction memory         | `instruction_memory.v`                      |
| Registers                  | `register_file.v` (escritura en WB)         |
| Sign extend / immediate    | `imm_gen.v`                                 |
| Control                    | `control_unit.v`                            |
| ALU                        | `alu.v` + `alu_control.v`                   |
| Data memory                | `data_memory.v` (escritura en MEM)          |
| IF/ID, ID/EX, EX/MEM, MEM/WB | `pipe_ifid/idex/exmem/memwb.v`            |
| Forwarding unit            | `forwarding_unit.v`                         |
| Hazard detection unit      | `hazard_unit.v`                             |
| Adders (PC+4, PC+imm)      | `adder.v`                                   |
| Muxes                      | ternarios en `top.v` (y `mux2to1.v`)        |

El salto se resuelve en la etapa **MEM** (igual que el diagrama): la senal
`PCSrc` sale de EX/MEM. Un salto tomado descarta 3 instrucciones jovenes.

### Riesgos (hazards) que maneja

1. **Riesgo de datos (RAW):** una instruccion necesita un resultado que otra mas
   vieja todavia no escribio. Se resuelve con **forwarding** (adelantar el dato
   desde EX/MEM o MEM/WB) y, para la distancia 3, con un **bypass interno** en el
   banco de registros.
2. **Riesgo load-use:** un `lw` seguido de una instruccion que usa ese registro.
   El forwarding no alcanza (el dato sale de memoria un ciclo despues), asi que
   se inserta **1 burbuja (stall)**.
3. **Riesgo de control (saltos):** al tomar un salto, las instrucciones ya
   buscadas detras estan mal; se **descartan (flush)**.

### Convencion de nombres

- Prefijo de etapa completo: `if_id_`, `id_ex_`, `ex_mem_`, `mem_wb_`.
- Senales de control con prefijo `ctrl_`.
- Se conservan los terminos estandar de RISC-V: `rs1`, `rs2`, `rd`, `pc`,
  `imm`, `alu_result`.

---

## 2. Modulos combinacionales basicos (se reusan del monociclo)

Son funciones puras: la salida depende solo de las entradas, sin reloj.

### `adder.v`
Sumador de 32 bits. Puertos: `a`, `b` (entradas) -> `out = a + b`. Se usa dos
veces: para `PC + 4` y para `PC + inmediato` (objetivo de salto).

### `mux2to1.v`
Multiplexor 2 a 1 de 32 bits: `out = sel ? b : a`. (En `top.v` muchos muxes se
escriben como ternarios `sel ? x : y` en vez de instanciar este modulo, porque
es mas legible.)

### `alu.v`
La Unidad Aritmetico-Logica. Puertos: `a`, `b`, `alu_ctrl` (4 bits que eligen la
operacion) -> `result` (32 bits) y `zero` (1 si `result == 0`, util para `beq`).
Operaciones: suma, resta, AND, OR, XOR, shifts, SLT/SLTU.

### `alu_control.v`
Traduce la "pista" de 2 bits `alu_op` (de `control_unit`) mas los campos
`func3`/`func7` de la instruccion al codigo de 4 bits `alu_ctrl` que entiende la
ALU. Ejemplo: para R-type mira func7 para distinguir ADD de SUB.

### `control_unit.v`
Decodifica el `opcode` (7 bits) y genera todas las senales de control:
`reg_write`, `alu_src`, `alu_a_src`, `mem_write`, `mem_read`, `mem_to_reg`,
`branch`, `jal`, `jalr`, `alu_op`. Es una tabla: segun el tipo de instruccion
(R, I, Load, Store, Branch, LUI, AUIPC, JAL, JALR) pone las senales en 0/1.

### `imm_gen.v`
Genera el inmediato de 32 bits extendido en signo segun el formato de la
instruccion (I, S, B, U, J). Puertos: `instr` -> `imm_out`.

### `pc.v`
El Program Counter. Puertos: `clk`, `rst`, `en`, `pc_next` -> `pc_out`. Es el
unico registro "de la ruta de datos" propiamente: en cada flanco, si `en=1`,
`pc_out <= pc_next`. `en` permite congelarlo (stall, modo paso, halt).

### `instruction_memory.v`
La memoria de programa (ROM). Puertos: `addr` (byte) -> `instr`. Lectura
combinacional: `instr = mem[addr[31:2]]` (descarta los 2 bits bajos porque cada
instruccion ocupa 4 bytes). El programa se carga con `$readmemh(HEX_FILE)`,
tanto en simulacion como en sintesis (Quartus hornea esos valores como ROM).
El assembler tambien genera `program.mif` para el flujo del In-System Memory
Content Editor (ver `docs/program-loading.md`).

---

## 3. Bloques de almacenamiento (con escritura sincronica propia)

A diferencia del monociclo (donde el almacenamiento vivia en `top.v`), aqui
estos dos modulos son **autocontenidos**, como en el diagrama.

### `register_file.v` - Banco de 32 registros
Puertos:
- Escritura (etapa WB): `clk`, `rst`, `write_enable`, `write_reg` (rd),
  `write_data`.
- Lectura (etapa ID, combinacional): `rs1`, `rs2` -> `read_data1`, `read_data2`.
- Depuracion VGA: `debug_addr` -> `debug_data`.

Detalles importantes:
- `x0` siempre lee 0 (es la convencion RISC-V).
- La escritura es sincronica: `if (write_enable && write_reg != 0)
  registers[write_reg] <= write_data` en el flanco de reloj.
- **Bypass write-first interno:** si en el mismo ciclo se escribe el registro que
  se esta leyendo, la lectura devuelve `write_data` directamente. Esto cubre la
  dependencia a distancia 3 (productor en WB, consumidor en ID) que el
  forwarding EX/MEM y MEM/WB no alcanza.

### `data_memory.v` - Memoria de datos (RAM, 256 palabras)
Puertos:
- Escritura sincronica (etapa MEM): `clk`, `mem_write`, `addr`, `write_data`.
- Lectura combinacional: `mem_read`, `addr` -> `read_data`.
- Depuracion VGA: `debug_addr` -> `debug_data`.

`addr[31:2]` es el indice de palabra. La escritura ocurre en el flanco si
`mem_write=1`; la lectura es inmediata si `mem_read=1` (si no, devuelve 0).

---

## 4. Unidades de control del pipeline

### `forwarding_unit.v` - Adelantamiento de datos
Compara los registros fuente de la instruccion en **EX** contra los destinos de
las instrucciones en **EX/MEM** y **MEM/WB**. Entradas: `ex_rs1`, `ex_rs2`,
`mem_reg_write`, `mem_rd`, `wb_reg_write`, `wb_rd`. Salidas: `forward_a`,
`forward_b` (2 bits cada una):
- `2'b10` -> adelantar desde EX/MEM (resultado de la instruccion previa).
- `2'b01` -> adelantar desde MEM/WB (valor de write-back).
- `2'b00` -> usar el valor leido del banco (ID/EX).

EX/MEM tiene prioridad (dato mas reciente). Nunca adelanta desde/para `x0`.

### `hazard_unit.v` - Deteccion de riesgo load-use
Si la instruccion en **EX** es una carga (`idex_mem_read=1`) y su destino
coincide con un fuente (`rs1`/`rs2`) de la instruccion en **ID**, activa
`load_use_stall=1`. Eso congela el PC e IF/ID e inyecta 1 burbuja en ID/EX, para
que el dato cargado este disponible (via forwarding MEM/WB) un ciclo despues.

---

## 5. Registros de pipeline (modulos discretos)

Los 4 son flip-flops de 32 bits con un reloj `clk`, reset `rst` y un `enable`
(el clock-enable global `cpu_enable`). Guardan los datos y senales de control de
una etapa para la siguiente. Una **burbuja** = poner `valid<=0` y las senales de
control con efecto a 0 (una instruccion "vacia", un NOP que no escribe nada).

### `pipe_ifid.v` (IF/ID)
Guarda `pc`, `pc_plus_4`, `instruction`, `valid`. Control:
- `flush` -> burbuja (salto tomado). Prioridad sobre `stall`.
- `stall` -> congela (mantiene la misma instruccion; load-use).
- si no, captura la instruccion buscada.

### `pipe_idex.v` (ID/EX)
Guarda `pc`, `pc_plus_4`, `instruction`, `imm`, `rs1_data`, `rs2_data`, `valid`
y todas las senales `ctrl_*`. Control: `bubble` (flush o stall) -> burbuja.

### `pipe_exmem.v` (EX/MEM)
Guarda `alu_result`, `store_data`, `pc_plus_4`, `instruction`, `branch_target`,
`pc_src`, `valid` y `ctrl_*` de MEM/WB. Control: `flush` -> burbuja (la
instruccion joven en EX se descarta cuando un salto mas viejo se toma en MEM).

### `pipe_memwb.v` (MEM/WB)
Guarda `alu_result`, `mem_read_data`, `pc_plus_4`, `instruction`, `valid` y
`ctrl_*` de WB. Avanza siempre (no recibe flush: la instruccion en MEM ya esta
confirmada).

---

## 6. Periféricos / depuracion

### `vga_controller.v`
Genera la temporizacion VGA 640x480: senales `hsync`, `vsync`, el reloj de pixel
`clk` (~25 MHz), la posicion del pixel `x`,`y` y `video_on` (1 dentro del area
visible).

### `vga_debug.v`
Dibuja en pantalla el estado del pipeline (combinacional, sin estado). Una fila
por etapa (IF/ID/EX/MEM/WB) con su PC e instruccion, una fila de riesgos
(STALL/FLUSH/forwarding/HALT) y dos paneles con los 32 registros y 32 palabras
de memoria. Recibe los campos de cada registro de pipeline desde `top.v`.

### `clock_div.v` y `hex_display.v`
`clock_div.v`: divisor de reloj (utilidad). `hex_display.v`: decodificador a 7
segmentos (HEX0..5). No son criticos para el pipeline.

---

## 7. `top.v` explicado por secciones (con numeros de linea)

`top.v` no contiene logica de almacenamiento: solo **instancia** los modulos y
los **conecta**. Es el "diagrama" hecho codigo.

### Cabecera y parametro (lineas 23-37)
- `module top #(parameter DEBOUNCE_LIMIT = 50000)` con los puertos fisicos de la
  DE1-SoC (`CLOCK_50`, `KEY`, `SW`, `LEDR`, `VGA_*`). Estos puertos no cambian:
  las asignaciones de pines en `segmented.qsf` dependen de ellos.
- Lineas 36-37: constantes `NOP_INSTRUCTION` (0x00000013 = `addi x0,x0,0`) y
  `EBREAK_INSTRUCTION` (0x00100073).

### Reset y anti-rebote de KEY[1] (lineas 40-70)
- Linea 40: `rst = ~KEY[0]` (reset activo en bajo: el boton presionado da 0).
- Lineas 43-67: sincronizan y filtran el rebote del boton KEY[1] y generan
  `step_pulse` (un pulso de 1 ciclo por cada pulsacion fisica). Sirve para el
  modo paso a paso.

### Halt y clock-enable global (lineas 73-75)
- Linea 73: `reg halted`.
- Linea 75: `cpu_enable`. Si `SW[0]=1` (paso a paso) avanza solo con
  `step_pulse`; si `SW[0]=0` (libre) avanza siempre, hasta `halted`. Este
  `cpu_enable` es el `enable` de todos los registros de pipeline: cuando es 0,
  todo el pipeline se congela.

### Declaracion de las salidas de los registros de pipeline (lineas 81-101)
Son `wire` manejados por los modulos `pipe_*`. Agrupados por etapa: `if_id_*`,
`id_ex_*`, `ex_mem_*`, `mem_wb_*`. Aqui se ve que cada etapa lleva la
instruccion, el PC, los datos y las senales de control que necesitara mas
adelante.

### Etapa WB (lineas 107-112)
Se calcula primero en el archivo porque su resultado (`write_back_data`)
realimenta a la etapa ID (escritura del banco):
- Linea 107: `write_back_rd` = rd de la instruccion en MEM/WB.
- Linea 108: `write_back_value_pre` = elige entre dato de memoria (load) o
  resultado de ALU (`mem_to_reg`).
- Linea 110: `write_back_data` = si es JAL/JALR escribe `PC+4` (direccion de
  retorno); si no, `write_back_value_pre`.
- Linea 112: `write_back_enable` = escribe solo si la instruccion es valida,
  tiene `reg_write` y `rd != 0`.

### Etapa IF - fetch (lineas 118-146)
- Linea 118: `pc_out`, `if_instruction`, `if_pc_plus_4`.
- Linea 122: `ebreak_in_fetch` = se busco un `ebreak` o instruccion nula (fin de
  programa); frena el fetch para no pasar del final.
- Linea 132: `flush = ex_mem_valid & ex_mem_pc_src` (salto tomado, resuelto en
  MEM).
- Linea 133: `stall_effective = load_use_stall & ~flush` (el flush gana al
  stall).
- Linea 137: `pc_enable`. El PC avanza salvo que haya stall o ebreak; pero el
  **flush tiene prioridad sobre el freno por ebreak** para que un salto pueda
  redirigir aunque detras se haya buscado un ebreak especulativo.
- Linea 139: `pc_next = flush ? ex_mem_branch_target : if_pc_plus_4` (el mux
  PCSrc del diagrama).
- Lineas 141-146: instancias `u_pc`, `u_pc_plus_4_adder` (PC+4) y
  `u_instruction_memory`.

### Etapa ID - decode (lineas 151-184)
- Lineas 151-152: `rs1`, `rs2` = campos de la instruccion en IF/ID.
- Linea 159: `u_control_unit` decodifica el opcode -> senales `ctrl_*`.
- Linea 174: `u_register_file`. Su puerto de escritura se conecta a las senales
  de WB (`write_back_*`), gateado por `cpu_enable`. Las lecturas
  (`rs1_data`, `rs2_data`) salen aqui en ID.
- Linea 184: `u_imm_gen` genera el inmediato.

### Etapa EX - execute (lineas 190-254)
- Linea 191: `u_forwarding` decide `forward_a`/`forward_b`.
- Linea 199: `u_hazard` decide `load_use_stall`.
- Linea 207: `ex_mem_forward_value` = el valor a adelantar desde EX/MEM (para
  JAL/JALR es `PC+4`, no el resultado de ALU).
- Lineas 210-212: `rs1_forwarded`/`rs2_forwarded` = muxes de forwarding que
  eligen entre el dato de ID/EX, el de EX/MEM o el de MEM/WB.
- Lineas 215-216: `alu_operand_a`/`alu_operand_b` = ultimo mux antes de la ALU:
  A puede ser el PC (AUIPC/JAL), B puede ser el inmediato.
- Lineas 222-231: `u_alu_control` y `u_alu` calculan `alu_result` y `alu_zero`.
- Linea 234: `u_branch_adder` calcula `PC + imm` (objetivo de salto relativo).
- Lineas 236-248: `branch_condition` segun `func3` (BEQ usa `alu_zero`, BLT usa
  `alu_result[0]`, etc.).
- Linea 249: `branch_taken` = es branch y se cumple la condicion.
- Linea 250: `pc_src_ex` = hay que cambiar el PC (branch tomado, JAL o JALR).
- Linea 251: `branch_target_ex` = a donde saltar (JALR usa `alu_result` =
  rs1+imm; el resto usa PC+imm). Esta decision y este objetivo se **latchean** en
  EX/MEM y se actuan en MEM.
- Linea 254: `store_data_ex` = dato a guardar en un `sw`, ya con forwarding.

### Etapa MEM (lineas 259-269)
- Linea 260: `u_data_memory`. La escritura se gatea con
  `cpu_enable & ex_mem_valid & ex_mem_ctrl_mem_write` (no escribe si la etapa es
  una burbuja). La lectura combinacional sale en `mem_read_data`.

### Instancias de los registros de pipeline (lineas 274-333)
- Linea 274: `u_if_id` (IF/ID): recibe `flush` y `stall`.
- Linea 282: `u_id_ex` (ID/EX): recibe `bubble = flush | load_use_stall`.
- Linea 303: `u_ex_mem` (EX/MEM): recibe `flush` (descarta la instruccion joven
  cuando el salto se toma en MEM). Aqui se latchean `pc_src` y `branch_target`.
- Linea 321: `u_mem_wb` (MEM/WB): avanza siempre.

Cada instancia conecta las salidas de su etapa (entradas `in_*`) con las salidas
registradas (`if_id_*`, `id_ex_*`, etc.) que usan las etapas siguientes.

### Halt (lineas 336-343)
Un pequeno flip-flop: cuando un `ebreak`/instruccion nula **valida** llega a
MEM/WB (etapa WB), pone `halted<=1`. Como llega a WB recien despues de que todas
las instrucciones anteriores se retiraron, garantiza que el resultado final
(p.ej. `x10`) ya esta escrito.

### VGA y LEDs (lineas 351-378 aprox.)
- `u_vga_controller` + `u_vga_debug` dibujan el estado del pipeline. A
  `u_vga_debug` se le pasan los campos de cada etapa (PC, instruccion, ALU) y las
  senales de riesgo/forwarding.
- `LEDR[0]` espeja `SW[0]` (modo paso); `LEDR[9]` = `halted`.

---

## 8. Como se prueba

En `segmented_cpu/test/` hay testbenches que se corren con iverilog:
- Unitarios: `make test_alu`, `test_register_file`, `test_data_memory`, etc.
- Integracion: `make test_top`, `make test_final_test` (corre el programa
  completo y verifica `x10=0`).
- Pipeline: `make test_pipe_smoke` (NOPs, sin riesgos), `make test_pipe_forward`
  (dependencias sin NOPs -> prueba forwarding), `make test_pipe_hazard`
  (load-use + salto tomado -> prueba stall y flush).
- `make all` corre los unitarios + integracion.

Los testbenches miran el estado interno con rutas jerarquicas:
`dut.u_register_file.registers[N]`, `dut.u_data_memory.memory[N]`,
`dut.u_pc.pc_out`, `dut.halted`.

> Nota: la memoria de instrucciones usa `$readmemh(HEX_FILE)` en simulacion y
> en sintesis. En Quartus se necesita `segmented.sdc` (reloj de 50 MHz); sin el,
> el Timing Analyzer asume 1 GHz y reporta fallos de timing falsos.

---

## 9. Glosario rapido de senales de `top.v`

| Senal                | Que es                                                   |
|----------------------|----------------------------------------------------------|
| `cpu_enable`         | clock-enable global (paso a paso / halt)                 |
| `flush`              | salto tomado resuelto en MEM -> descartar 3 jovenes      |
| `load_use_stall`     | riesgo carga-uso -> 1 burbuja                            |
| `stall_effective`    | stall que de verdad aplica (flush tiene prioridad)       |
| `forward_a/b`        | seleccion de forwarding para operando A/B                |
| `rs1_forwarded`      | valor de rs1 despues del forwarding                      |
| `alu_operand_a/b`    | entradas finales de la ALU                               |
| `branch_target_ex`   | objetivo de salto calculado en EX                        |
| `ex_mem_pc_src`      | PCSrc latcheado: la decision de salto, actuada en MEM    |
| `write_back_data`    | dato que se escribe en el banco de registros             |
| `write_back_enable`  | habilita esa escritura (valido, reg_write, rd!=0)        |
| `halted`             | CPU detenida (ebreak llego a WB)                         |
