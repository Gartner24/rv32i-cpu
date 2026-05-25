# CPU RV32I Segmentada - Explicacion completa (estilo libro)

Este documento explica de principio a fin la CPU segmentada (`segmented_cpu/`).
Empieza por los conceptos (que es un pipeline y de que se compone), luego
explica **cada modulo** mostrando su codigo real y como se conecta con los
demas, y termina recorriendo `top.v` entero. La meta es entender **cada cosa**.

Indice:
- PARTE I. Conceptos: que es una CPU segmentada
- PARTE II. Los modulos, uno por uno (con su codigo)
- PARTE III. `top.v`: como se conecta todo
- PARTE IV. Recorridos: como fluyen las instrucciones y los riesgos

---

# PARTE I. Conceptos

## 1.1. De monociclo a segmentado

En una CPU **monociclo**, cada instruccion se ejecuta entera en un solo ciclo de
reloj: buscar la instruccion, decodificarla, operar en la ALU, acceder a memoria
y escribir el resultado, todo en el mismo ciclo. Eso es simple pero lento: el
ciclo de reloj tiene que durar lo que tarda la instruccion mas larga (por
ejemplo un `lw`, que pasa por todo el camino). Mientras tanto, el sumador del
PC, la ALU, la memoria... la mayor parte del hardware esta ociosa casi todo el
tiempo.

La idea de la **segmentacion (pipelining)** es la de una linea de montaje. Una
fabrica de autos no arma un auto entero y luego empieza el siguiente: divide el
trabajo en estaciones (chasis, motor, pintura, ruedas...) y en cada estacion hay
un auto distinto al mismo tiempo. Cuando el auto 1 pasa de "motor" a "pintura",
el auto 2 entra a "motor". Asi sale un auto terminado por unidad de tiempo,
aunque cada auto individual siga tardando lo mismo en recorrer toda la linea.

Una CPU segmentada hace lo mismo con las instrucciones: divide la ejecucion en
**5 etapas** y mantiene **5 instrucciones distintas en vuelo**, una en cada
etapa. En el mejor caso termina **una instruccion por ciclo**, aunque cada
instruccion individual tarde 5 ciclos en cruzar todo el pipeline.

```
Ciclo:      1     2     3     4     5     6     7     8
instr A:   IF    ID    EX    MEM   WB
instr B:         IF    ID    EX    MEM   WB
instr C:               IF    ID    EX    MEM   WB
instr D:                     IF    ID    EX    MEM   WB
```

A partir del ciclo 5 se retira una instruccion por ciclo (el pipeline esta
"lleno"). Eso permite subir la frecuencia de reloj: el ciclo solo tiene que durar
lo que tarda **una etapa**, no la instruccion completa.

## 1.2. Las 5 etapas

```
   IF          ID            EX           MEM           WB
 (Fetch)    (Decode)     (Execute)    (Memory)     (Write-Back)
   |            |             |            |              |
 buscar     leer reg.       ALU /      leer/escribir   escribir el
 instr.     y decodif.      saltos     data memory     registro destino
```

- **IF (Instruction Fetch):** el PC apunta a una instruccion; se lee de la
  memoria de instrucciones; se calcula PC+4.
- **ID (Instruction Decode):** se decodifica el opcode (que tipo de instruccion
  es y que senales de control activa), se leen los registros fuente `rs1`/`rs2`
  del banco de registros y se genera el inmediato.
- **EX (Execute):** la ALU hace la operacion (suma, resta, AND, comparacion...);
  tambien se calcula el destino de un salto y se decide si se toma.
- **MEM (Memory):** si es `lw`/`sw`, se lee o escribe la memoria de datos. Aqui
  tambien se actua el salto (se cambia el PC).
- **WB (Write-Back):** se escribe el resultado (de la ALU o de memoria) en el
  registro destino `rd`.

## 1.3. Los registros de pipeline

Entre una etapa y la siguiente hay un **registro de pipeline**: un banco de
flip-flops que captura, en cada flanco de reloj, todo lo que la etapa produjo,
para que la siguiente etapa lo use el ciclo siguiente. Son 4:

```
 IF -> [IF/ID] -> ID -> [ID/EX] -> EX -> [EX/MEM] -> MEM -> [MEM/WB] -> WB
```

Son imprescindibles: sin ellos, lo que calcula una etapa se perderia o se
mezclaria con la instruccion siguiente. Cada registro de pipeline lleva **todo
lo que las etapas posteriores van a necesitar** de esa instruccion: su PC, la
propia instruccion, los datos leidos, el inmediato y **todas las senales de
control** que decidira mas adelante.

Un detalle clave: las senales de control se generan una sola vez en ID y luego
**viajan con la instruccion** por los registros de pipeline hasta la etapa donde
se usan (por ejemplo, `mem_write` se genera en ID pero se usa en MEM, asi que
viaja ID/EX -> EX/MEM y ahi se usa).

## 1.4. Latencia y throughput

- **Latencia:** lo que tarda UNA instruccion en cruzar el pipeline = 5 ciclos.
- **Throughput:** instrucciones terminadas por ciclo. Ideal = 1/ciclo.

En la DE1-SoC el reloj es de 50 MHz, es decir un ciclo dura **20 ns**. Si un
programa tarda N ciclos, el tiempo real es N x 20 ns. (Por eso los reportes de
los tests muestran, por ejemplo, "640 ciclos = 12800 ns".)

El throughput ideal no se alcanza siempre, porque hay **riesgos**.

## 1.5. Los riesgos (hazards)

Tener varias instrucciones en vuelo crea conflictos. Hay tres tipos:

### Riesgo de datos (RAW: Read After Write)
Una instruccion necesita un resultado que otra mas vieja **todavia no escribio**.

```
add x3, x1, x2     # escribe x3 (en WB, varios ciclos despues)
sub x4, x3, x5     # necesita x3 YA, en EX
```

El `sub` llega a EX cuando el `add` apenas esta en MEM: x3 aun no esta en el
banco de registros. Solucion: **forwarding (adelantamiento)**: tomar el
resultado directamente de donde ya existe (la salida de la ALU guardada en
EX/MEM, o el valor de write-back en MEM/WB) y meterlo en la ALU, sin esperar a
que se escriba en el banco. Lo hace `forwarding_unit.v`.

### Riesgo load-use
Caso especial de riesgo de datos: una carga seguida de una instruccion que usa
el dato cargado.

```
lw   x3, 0(x1)     # el dato sale de memoria en MEM
add  x4, x3, x5    # lo necesita en EX, un ciclo antes de que exista
```

Aqui el forwarding **no alcanza**: el dato de la carga solo esta disponible
despues de la etapa MEM. Hay que **frenar 1 ciclo (stall / burbuja)** la
instruccion dependiente. Lo detecta `hazard_unit.v`.

### Riesgo de control (saltos)
Cuando hay un salto (`beq`, `jal`, `jalr`), el pipeline ya empezo a buscar las
instrucciones que venian fisicamente despues, pero si el salto se toma, esas
instrucciones **no se deben ejecutar**. Hay que **descartarlas (flush)**: se
convierten en burbujas. En esta CPU el salto se resuelve en la etapa **MEM**, asi
que se descartan **3** instrucciones jovenes.

### Una burbuja
"Burbuja" = una instruccion vacia (un NOP) que ocupa una etapa pero no hace nada:
no escribe registros ni memoria. Se crea poniendo el bit `valid` a 0 y todas las
senales de control con efecto (reg_write, mem_write, ...) a 0.

---

# PARTE II. Los modulos, uno por uno

Cada modulo es un archivo `.v`. Hay tres familias:
1. **Combinacionales puros** (sin reloj): calculan una salida a partir de sus
   entradas. adder, mux2to1, alu, alu_control, control_unit, imm_gen.
2. **Con estado / almacenamiento** (con reloj): pc, instruction_memory,
   register_file, data_memory, y los 4 registros de pipeline.
3. **Control del pipeline:** forwarding_unit, hazard_unit.

## 2.1. adder.v - Sumador

```verilog
module adder (
    input [31:0] a,
    input [31:0] b,
    output [31:0] out
);
assign out = a + b;
endmodule
```

Es lo mas simple: una suma de 32 bits, combinacional. `assign` significa "esta
salida es siempre igual a esta expresion" (no hay reloj). En `top.v` se instancia
**dos veces**:
- `u_pc_plus_4_adder`: calcula `PC + 4` (la direccion de la instruccion
  siguiente en secuencia).
- `u_branch_adder`: calcula `PC + inmediato` (el destino de un salto relativo).

## 2.2. mux2to1.v - Multiplexor 2 a 1

```verilog
module mux2to1 (
    input         sel,
    input  [31:0] a,
    input  [31:0] b,
    output [31:0] out
);
assign out = sel ? b : a;
endmodule
```

Un multiplexor elige una de dos entradas segun `sel`: si `sel=0` sale `a`, si
`sel=1` sale `b`. Es el "interruptor" basico del datapath. En la CPU segmentada
la mayoria de los multiplexores se escriben directamente como ternarios
(`sel ? x : y`) dentro de `top.v` porque se leen mejor, pero conceptualmente son
este modulo. Ejemplos de muxes en el datapath: elegir si la ALU recibe un
registro o el inmediato, elegir el dato de write-back, elegir el siguiente PC.

## 2.3. pc.v - El contador de programa

```verilog
module pc (
    input             clk,
    input             rst,
    input             en,       // clock enable (0 = freeze)
    input      [31:0] pc_next,  // siguiente direccion (viene de top.v)
    output reg [31:0] pc_out    // direccion actual (va a instruction_memory)
);
always @(posedge clk or posedge rst) begin
    if (rst)
        pc_out <= 32'h00000000;
    else if (en)
        pc_out <= pc_next;
end
endmodule
```

El PC guarda la direccion de la instruccion que se esta buscando. Es un
flip-flop: en cada flanco de subida del reloj (`posedge clk`), **si** `en=1`,
toma el valor de `pc_next`. El reset (asincrono, `posedge rst`) lo vuelve a 0.

La entrada `en` (clock-enable) es clave para el pipeline: permite **congelar** el
PC. Cuando hay un stall por load-use o cuando la CPU esta en modo paso a paso o
detenida (halt), `en=0` y el PC no avanza.

Conexion en `top.v`:
- `clk` <- `CLOCK_50`; `rst` <- reset; `en` <- `pc_enable` (logica de stall/halt).
- `pc_next` <- el mux de PC (PC+4 normal, o destino de salto si hay flush).
- `pc_out` -> alimenta a `u_pc_plus_4_adder` y a `instruction_memory`.

## 2.4. instruction_memory.v - Memoria de programa

```verilog
module instruction_memory #(
    parameter HEX_FILE  = "program.hex",
    parameter MEM_DEPTH = 1024
) (
    input  [31:0] addr,   // direccion byte desde el PC
    output [31:0] instr   // instruccion de 32 bits
);
reg [31:0] mem [0:MEM_DEPTH-1];
initial begin
    $readmemh(HEX_FILE, mem);
end
assign instr = mem[addr[31:2]];
endmodule
```

Guarda el programa. `mem` es un arreglo de palabras de 32 bits. `$readmemh` lo
carga desde un archivo `.hex` (una instruccion en hexadecimal por linea) al
arrancar; Quartus respeta esa inicializacion en la sintesis (la implementa como
ROM con esos valores constantes).

Lectura **combinacional**: `assign instr = mem[addr[31:2]]`. La direccion llega
en bytes, pero como cada instruccion ocupa 4 bytes se usa `addr[31:2]` (se
descartan los 2 bits bajos) como indice de palabra. Que sea combinacional
significa que la instruccion sale el mismo ciclo en que el PC presenta la
direccion (en la etapa IF).

Conexion: `addr` <- `pc_out`; `instr` -> se latchea en IF/ID. El parametro
`HEX_FILE` permite que cada programa de prueba elija su `.hex`.

## 2.5. control_unit.v - La unidad de control

Decodifica el `opcode` (los 7 bits bajos de la instruccion) y enciende las
senales de control que gobiernan todo el datapath. Es esencialmente una tabla.
Su cabecera y dos casos representativos:

```verilog
module control_unit (
    input  [6:0] opcode,
    output reg reg_write,   // habilita escritura en register file
    output reg alu_src,     // 0 = rs2, 1 = inmediato
    output reg alu_a_src,   // 0 = rs1, 1 = PC (para AUIPC)
    output reg mem_write,   // habilita escritura en data memory
    output reg mem_read,    // habilita lectura de data memory
    output reg mem_to_reg,  // 0 = ALU result, 1 = dato de memoria
    output reg branch,      // instruccion de salto condicional
    output reg jal,         // salto incondicional (JAL)
    output reg jalr,        // salto incondicional a rs1+imm (JALR)
    output reg [1:0] alu_op // pista para alu_control
);
always @(*) begin
    case (opcode)
        R_TYPE: begin   // add, sub, and, or, ...
            reg_write=1; alu_src=0; alu_a_src=0; mem_write=0; mem_read=0;
            mem_to_reg=0; branch=0; jal=0; jalr=0; alu_op=2'b10;
        end
        LOAD: begin      // lw
            reg_write=1; alu_src=1; alu_a_src=0; mem_write=0; mem_read=1;
            mem_to_reg=1; branch=0; jal=0; jalr=0; alu_op=2'b00;
        end
        // ... I_TYPE, S_TYPE, B_TYPE, LUI, AUIPC, JAL, JALR ...
    endcase
end
endmodule
```

Que significa cada senal (las decide aqui y luego viajan por el pipeline):
- `reg_write`: la instruccion escribe un registro (R, I, loads, LUI, AUIPC, JAL,
  JALR lo ponen en 1; stores y branches en 0).
- `alu_src`: el segundo operando de la ALU es el inmediato (1) o rs2 (0).
- `alu_a_src`: el primer operando es el PC (1, para AUIPC) o rs1 (0).
- `mem_read`/`mem_write`: acceso a la memoria de datos (loads/stores).
- `mem_to_reg`: lo que se escribe en rd viene de memoria (1, loads) o de la ALU (0).
- `branch`/`jal`/`jalr`: tipo de salto.
- `alu_op` (2 bits): pista para `alu_control` (00=sumar para load/store, 01=branch,
  10=R-type, 11=I-type aritmetico).

Conexion: `opcode` <- `if_id_instruction[6:0]` (en ID). Todas las salidas
`ctrl_*` se latchean en ID/EX y viajan a su etapa.

## 2.6. imm_gen.v - Generador de inmediato

```verilog
module imm_gen (
    input      [31:0] instr,
    output reg [31:0] imm_out
);
wire [6:0] opcode = instr[6:0];
always @(*) begin
    case (opcode)
        I_TYPE, LOAD, JALR: imm_out = {{20{instr[31]}}, instr[31:20]};
        S_TYPE:  imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        B_TYPE:  imm_out = {{19{instr[31]}}, instr[31], instr[7],
                            instr[30:25], instr[11:8], 1'b0};
        LUI, AUIPC: imm_out = {instr[31:12], 12'b0};
        JAL:     imm_out = {{11{instr[31]}}, instr[31], instr[19:12],
                            instr[20], instr[30:21], 1'b0};
        default: imm_out = 32'b0;
    endcase
end
endmodule
```

RV32I guarda el inmediato con sus bits **dispersos** dentro de la instruccion, y
de forma distinta segun el formato (I, S, B, U, J). Este modulo los reensambla y
los **extiende con signo** a 32 bits. La extension de signo es el `{{20{instr[31]}}, ...}`:
repite el bit 31 (el bit de signo) las veces necesarias para llenar los 32 bits.
Notar el `1'b0` final en B y J: los saltos son a direcciones pares, asi que el
bit 0 del offset siempre es 0.

Conexion: `instr` <- `if_id_instruction`; `imm_out` -> se latchea en ID/EX como
`id_ex_imm`.

## 2.7. register_file.v - Banco de 32 registros

Este es uno de los bloques que en el monociclo estaba "destripado" en `top.v` y
que aqui es un **modulo autocontenido con su puerto de escritura propio** (como
en el diagrama de Patterson). Codigo completo:

```verilog
module register_file (
    input         clk,
    input         rst,
    input         write_enable,   // RegWrite (ya con rd!=0 y valido)
    input  [4:0]  write_reg,       // registro destino (rd de la etapa WB)
    input  [31:0] write_data,      // dato a escribir (mux de write-back)
    input  [4:0]  rs1,
    input  [4:0]  rs2,
    input  [4:0]  debug_addr,      // registro a mostrar en la VGA
    output [31:0] read_data1,
    output [31:0] read_data2,
    output [31:0] debug_data
);
reg [31:0] registers [0:31];
integer i;

always @(posedge clk or posedge rst) begin
    if (rst)
        for (i = 0; i < 32; i = i + 1) registers[i] <= 32'b0;
    else if (write_enable && (write_reg != 5'b0))
        registers[write_reg] <= write_data;
end

assign read_data1 = (rs1 == 5'b0)                        ? 32'b0      :
                    (write_enable && (write_reg == rs1)) ? write_data : registers[rs1];
assign read_data2 = (rs2 == 5'b0)                        ? 32'b0      :
                    (write_enable && (write_reg == rs2)) ? write_data : registers[rs2];
assign debug_data = (debug_addr == 5'b0)                 ? 32'b0      : registers[debug_addr];
endmodule
```

Tiene **dos puertos de lectura** combinacionales (`rs1`, `rs2`, que se usan en
ID) y **un puerto de escritura** sincronico (que se usa en WB). Tres detalles
importantes:

1. **x0 siempre es 0.** En RISC-V el registro x0 esta cableado a cero. Por eso la
   lectura comprueba `rs1==0 ? 0 : ...` y la escritura comprueba `write_reg != 0`
   (escribir x0 no hace nada).

2. **Escritura sincronica:** en el flanco de reloj, si `write_enable=1`, escribe
   `write_data` en `registers[write_reg]`. Esa escritura ocurre en la etapa WB.

3. **Bypass write-first interno** (las dos lineas `(write_enable && write_reg==rs1) ? write_data : ...`):
   si en este mismo ciclo se esta escribiendo el registro que se esta leyendo, la
   lectura devuelve directamente el dato que se escribe. Esto resuelve la
   dependencia a **distancia 3** (la instruccion que escribe esta en WB justo
   cuando la que lee esta en ID). El forwarding normal (EX/MEM y MEM/WB) no llega
   a ese caso, asi que el banco lo cubre internamente.

Conexion en `top.v`:
- `write_enable` <- `cpu_enable & write_back_enable`, `write_reg` <- `write_back_rd`,
  `write_data` <- `write_back_data` (todo de la etapa WB).
- `rs1`/`rs2` <- campos de `if_id_instruction`; `read_data1/2` -> se latchean en ID/EX.
- `debug_addr`/`debug_data` <- -> la VGA, para mostrar el contenido en pantalla.

## 2.8. alu_control.v - Decodificacion fina de la ALU

```verilog
module alu_control (
    input [1:0] alu_op,    // viene de control_unit
    input [2:0] func3,     // viene de la instruccion
    input [6:0] func7,     // viene de la instruccion
    output reg [3:0] alu_ctrl  // va a la ALU
);
always @(*) begin
    case (alu_op)
        2'b00: alu_ctrl = 4'b0000; // ADD fijo (loads/stores: base+offset)
        2'b01: case (func3)        // branches
            3'b000, 3'b001: alu_ctrl = 4'b0001; // BEQ/BNE -> SUB
            3'b100, 3'b101: alu_ctrl = 4'b1000; // BLT/BGE -> SLT
            3'b110, 3'b111: alu_ctrl = 4'b1001; // BLTU/BGEU -> SLTU
            default:        alu_ctrl = 4'b0001;
        endcase
        2'b10: case (func3)        // R-type
            3'b000: alu_ctrl = func7[5] ? 4'b0001 : 4'b0000; // SUB : ADD
            3'b101: alu_ctrl = func7[5] ? 4'b0111 : 4'b0110; // SRA : SRL
            // ... XOR, OR, AND, SLL, SLT, SLTU ...
        endcase
        2'b11: case (func3) ... endcase // I-type aritmetico
    endcase
end
endmodule
```

`control_unit` solo mira el opcode y da una pista de 2 bits (`alu_op`). Pero
"R-type" abarca add, sub, and, or, xor, shifts, slt... Para saber **cual**, hay
que mirar `func3` y `func7`. Eso hace este modulo: combina `alu_op` + `func3` +
`func7` y produce el codigo de 4 bits `alu_ctrl` que la ALU entiende. El truco de
`func7[5]` distingue ADD de SUB (mismo func3=000) y SRL de SRA.

Conexion: `alu_op` <- `id_ex_ctrl_alu_op`; `func3`/`func7` <- campos de
`id_ex_instruction`; `alu_ctrl` -> a la ALU. Todo en la etapa EX.

## 2.9. alu.v - La Unidad Aritmetico-Logica

```verilog
module alu (
    input [31:0] a,
    input [31:0] b,
    input [3:0] alu_ctrl,
    output reg [31:0] result,
    output zero
);
always @(*) begin
    case (alu_ctrl)
        4'b0000: result = a + b;                              // ADD
        4'b0001: result = a - b;                              // SUB
        4'b0100: result = a ^ b;                              // XOR
        4'b0011: result = a | b;                              // OR
        4'b0010: result = a & b;                              // AND
        4'b0101: result = a << b[4:0];                        // SLL
        4'b0110: result = a >> b[4:0];                        // SRL
        4'b0111: result = $signed(a) >>> b[4:0];              // SRA
        4'b1000: result = $signed(a) < $signed(b) ? 1 : 0;    // SLT (con signo)
        4'b1001: result = (a < b) ? 1 : 0;                    // SLTU (sin signo)
        default: result = 32'b0;
    endcase
end
assign zero = (result == 32'b0);
endmodule
```

Es el corazon aritmetico. Segun `alu_ctrl` hace suma, resta, logicas, shifts o
comparaciones. Dos sutilezas:
- En los shifts solo se usan `b[4:0]` (0..31) porque desplazar mas de 31 bits no
  tiene sentido en 32 bits.
- `$signed(...) >>> ` es el shift aritmetico (extiende el signo); `>>` es el
  logico (mete ceros). `$signed(a) < $signed(b)` compara con signo (SLT) vs sin
  signo (SLTU).

La salida `zero` (1 si `result==0`) la usa la logica de saltos: para `beq` se
hace `a-b` y si `zero=1` los operandos eran iguales.

Conexion: `a` <- `alu_operand_a`, `b` <- `alu_operand_b` (los operandos despues
del forwarding y de los muxes), `alu_ctrl` <- de `alu_control`. `result` ->
se latchea en EX/MEM (y se usa para saltos JALR y para la condicion de branch).

## 2.10. data_memory.v - Memoria de datos

Igual que el banco de registros, aqui es un modulo autocontenido con escritura
sincronica propia (en el monociclo vivia en `top.v`).

```verilog
module data_memory (
    input         clk,
    input         mem_write,     // ya con valido y cpu_enable
    input         mem_read,
    input  [31:0] addr,
    input  [31:0] write_data,
    output [31:0] read_data,
    input  [4:0]  debug_addr,    // palabra 0..31 a mostrar en la VGA
    output [31:0] debug_data
);
reg [31:0] memory [0:255];

always @(posedge clk) begin
    if (mem_write)
        memory[addr[31:2]] <= write_data;
end

assign read_data  = mem_read ? memory[addr[31:2]] : 32'b0;
assign debug_data = memory[debug_addr];
endmodule
```

Es la RAM de la CPU (256 palabras = 1 KB) para variables y la pila (stack). La
**escritura es sincronica** (en el flanco, si `mem_write=1`) y la **lectura es
combinacional** (si `mem_read=1`, sale el dato; si no, 0). `addr[31:2]` es el
indice de palabra (igual que en la memoria de instrucciones).

Conexion (todo en la etapa MEM): `addr` <- `ex_mem_alu_result` (la ALU calculo
la direccion = base + offset), `write_data` <- `ex_mem_store_data` (el valor a
guardar, con forwarding aplicado), `mem_write` <- `cpu_enable & ex_mem_valid &
ex_mem_ctrl_mem_write` (no escribe si la etapa es una burbuja), `read_data` ->
se latchea en MEM/WB.

## 2.11. forwarding_unit.v - Adelantamiento de datos

```verilog
module forwarding_unit (
    input  [4:0] ex_rs1,
    input  [4:0] ex_rs2,
    input        mem_reg_write,
    input  [4:0] mem_rd,
    input        wb_reg_write,
    input  [4:0] wb_rd,
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);
always @(*) begin
    // Operando A (rs1)
    if (mem_reg_write && (mem_rd != 5'b0) && (mem_rd == ex_rs1))
        forward_a = 2'b10;      // adelantar desde EX/MEM
    else if (wb_reg_write && (wb_rd != 5'b0) && (wb_rd == ex_rs1))
        forward_a = 2'b01;      // adelantar desde MEM/WB
    else
        forward_a = 2'b00;      // usar el valor de ID/EX
    // Operando B (rs2): mismo criterio
    ...
end
endmodule
```

Resuelve el riesgo de datos. Mira la instruccion que esta en **EX** (sus fuentes
`ex_rs1`, `ex_rs2`) y la compara con los destinos de las instrucciones que ya van
mas adelante:
- Si la instruccion en **EX/MEM** va a escribir el mismo registro que EX necesita
  -> `forward = 2'b10`: usar el resultado de la ALU que ya esta en EX/MEM.
- Si no, y la instruccion en **MEM/WB** lo escribe -> `forward = 2'b01`: usar el
  valor de write-back.
- Si ninguna -> `forward = 2'b00`: usar el valor leido del banco (ID/EX).

EX/MEM tiene prioridad (es el dato mas reciente). Nunca adelanta desde/para x0.
Las salidas `forward_a`/`forward_b` controlan los multiplexores de operando en EX
(ver `top.v`).

## 2.12. hazard_unit.v - Deteccion de riesgo load-use

```verilog
module hazard_unit (
    input        idex_valid,
    input        idex_mem_read,
    input  [4:0] idex_rd,
    input  [4:0] ifid_rs1,
    input  [4:0] ifid_rs2,
    output       load_use_stall
);
assign load_use_stall = idex_valid && idex_mem_read && (idex_rd != 5'b0) &&
                        ((idex_rd == ifid_rs1) || (idex_rd == ifid_rs2));
endmodule
```

Detecta el unico caso que el forwarding no puede arreglar: una **carga en EX**
(`idex_mem_read=1`) cuyo destino (`idex_rd`) coincide con un registro fuente de
la instruccion que viene detras, en **ID** (`ifid_rs1` o `ifid_rs2`). Cuando eso
pasa, `load_use_stall=1` y `top.v`:
- congela el PC y el registro IF/ID (la instruccion dependiente se queda quieta),
- inyecta una burbuja en ID/EX.

Asi la instruccion dependiente espera un ciclo, y cuando finalmente llega a EX la
carga ya esta en MEM/WB y el forwarding le pasa el dato. Resultado: 1 ciclo de
penalizacion.

## 2.13. Los 4 registros de pipeline

Son flip-flops que separan las etapas. Todos comparten el mismo patron: en cada
flanco, si `enable` (= `cpu_enable`), capturan sus entradas `in_*`; en reset o
ante una orden de burbuja, ponen `valid<=0` y las senales de control a 0.

### pipe_ifid.v (entre IF e ID)

```verilog
module pipe_ifid (
    input clk, rst, enable, flush, stall,
    input [31:0] in_pc, in_pc_plus_4, in_instruction,
    output reg [31:0] pc, pc_plus_4, instruction,
    output reg valid
);
localparam [31:0] NOP_INSTRUCTION = 32'h00000013;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc <= 0; pc_plus_4 <= 0; instruction <= NOP_INSTRUCTION; valid <= 0;
    end else if (enable) begin
        if (flush) begin
            instruction <= NOP_INSTRUCTION; valid <= 0;   // burbuja
        end else if (stall) begin
            // mantener (la instruccion espera en ID)
        end else begin
            pc <= in_pc; pc_plus_4 <= in_pc_plus_4;
            instruction <= in_instruction; valid <= 1;
        end
    end
end
endmodule
```

Guarda lo que produce IF (PC, PC+4, instruccion). Su control tiene prioridades:
`flush` (salto tomado) -> burbuja; `stall` (load-use) -> congelar; si no ->
capturar la instruccion nueva.

### pipe_idex.v (entre ID y EX)
Guarda PC, PC+4, instruccion, inmediato, los dos datos leidos (`rs1_data`,
`rs2_data`), `valid` y **todas** las senales de control. Su control es `bubble`
(= flush O stall): si hay burbuja, pone `valid` y las `ctrl_*` a 0; si no,
captura todo.

### pipe_exmem.v (entre EX y MEM)
Guarda `alu_result`, el dato a almacenar (`store_data`), PC+4, la instruccion, y
ademas la **decision y el destino de salto** calculados en EX (`pc_src` y
`branch_target`), mas las `ctrl_*` que faltan usar (mem, wb). Su control es
`flush`: cuando un salto se toma en MEM, la instruccion joven que esta en EX se
descarta.

### pipe_memwb.v (entre MEM y WB)
Guarda `alu_result`, el dato leido de memoria (`mem_read_data`), PC+4, la
instruccion y las `ctrl_*` de write-back. **Avanza siempre** (no recibe flush):
la instruccion que esta en MEM ya esta confirmada y va a escribir su resultado.

Por que las burbujas ponen las senales de control a 0 y no solo `valid`: la
`forwarding_unit` mira `ex_mem_ctrl_reg_write` y `mem_wb_ctrl_reg_write`
**directamente** (sin filtrar por `valid`). Si una burbuja dejara `reg_write=1`
con basura, el forwarding podria adelantar un valor falso. Por eso la burbuja
limpia las senales de control.

## 2.14. La VGA (depuracion en pantalla)

No son parte del calculo de la CPU, sino una ayuda visual.

- **vga_controller.v** genera la temporizacion VGA 640x480: las senales `hsync`,
  `vsync`, el reloj de pixel (~25 MHz, derivado de los 50 MHz con `clock_div.v`),
  la posicion del pixel `x`,`y` y `video_on` (1 cuando el haz esta en el area
  visible).
- **vga_debug.v** es combinacional: dado `(x,y)` y el estado del pipeline, decide
  el color de ese pixel. Dibuja una fila por etapa (IF/ID/EX/MEM/WB) con su PC e
  instruccion, una fila de riesgos (STALL/FLUSH/forwarding/HALT) y dos paneles
  con los 32 registros y 32 palabras de memoria. Usa una fuente de mapa de bits
  (`font128.hex`) para dibujar texto.

`clock_div.v` divide el reloj a la mitad (25 MHz para la VGA). `hex_display.v`
(decodificador a 7 segmentos) existe en el proyecto pero el `top` segmentado no
lo usa.

---

# PARTE III. `top.v`: como se conecta todo

`top.v` es el plano: **no calcula nada por si mismo**, solo instancia los modulos
y los conecta con cables (`wire`). Es el diagrama hecho codigo. Aqui se ve como
las salidas de un modulo se vuelven entradas de otro y como las cosas fluyen de
etapa en etapa. Los numeros de linea son del archivo actual.

## 3.1. Puertos y controles fisicos (lineas 23-37)

```verilog
module top #(parameter DEBOUNCE_LIMIT = 50000) (
    input         CLOCK_50,
    input  [3:0]  KEY,
    input  [9:0]  SW,
    output [9:0]  LEDR,
    output [7:0]  VGA_R, VGA_G, VGA_B,
    output        VGA_HS, VGA_VS, VGA_CLK, VGA_BLANK_N, VGA_SYNC_N
);
```

Estos son los pines reales de la DE1-SoC. `CLOCK_50` es el reloj de 50 MHz;
`KEY[0]` es el reset; `KEY[1]` el paso manual; `SW[0]` elige modo libre o paso a
paso; `LEDR` y `VGA_*` son salidas. (Las asignaciones de pin estan en
`segmented.qsf`; este modulo no debe cambiar de puertos para no romperlas.)

## 3.2. Reset, anti-rebote y clock-enable global (lineas 40-75)

```verilog
wire rst = ~KEY[0];                    // el boton da 0 al presionar
...                                    // anti-rebote de KEY[1] -> step_pulse
reg halted;
wire cpu_enable = SW[0] ? (step_pulse && ~halted) : ~halted;
```

`cpu_enable` es el **clock-enable global** del pipeline. Si `SW[0]=1` (paso a
paso) solo avanza un tick por cada pulsacion de KEY[1] (`step_pulse`); si
`SW[0]=0` (libre) avanza siempre hasta que `halted=1`. Este `cpu_enable` entra
como `enable` a los 4 registros de pipeline y como condicion de las escrituras a
registros y memoria: cuando es 0, **todo el pipeline se congela**.

## 3.3. Cables de los registros de pipeline (lineas 81-101)

Aqui se declaran los `wire` que llevan las salidas de cada registro de pipeline,
agrupados por etapa con prefijos completos: `if_id_*`, `id_ex_*`, `ex_mem_*`,
`mem_wb_*`. Por ejemplo `id_ex_instruction`, `ex_mem_alu_result`,
`mem_wb_ctrl_reg_write`. Solo verlos da el mapa de que informacion viaja en cada
etapa.

## 3.4. Etapa WB (lineas 107-112)

Se calcula primero en el archivo porque su resultado realimenta a ID (la
escritura del banco):

```verilog
wire [4:0]  write_back_rd        = mem_wb_instruction[11:7];
wire [31:0] write_back_value_pre = mem_wb_ctrl_mem_to_reg ? mem_wb_mem_read_data
                                                          : mem_wb_alu_result;
wire [31:0] write_back_data      = (mem_wb_ctrl_jal | mem_wb_ctrl_jalr)
                                   ? mem_wb_pc_plus_4 : write_back_value_pre;
wire        write_back_enable    = mem_wb_valid & mem_wb_ctrl_reg_write
                                   & (write_back_rd != 5'b0);
```

- `write_back_rd`: el registro destino (campo rd de la instruccion en MEM/WB).
- `write_back_value_pre`: primer mux: dato de memoria (loads) o resultado de ALU.
- `write_back_data`: segundo mux: si es JAL/JALR escribe `PC+4` (la direccion de
  retorno); si no, lo anterior.
- `write_back_enable`: escribe solo si la instruccion es valida, tiene
  `reg_write` y `rd != 0`.

Estos cuatro cables alimentan el puerto de escritura de `register_file`.

## 3.5. Etapa IF (lineas 118-146)

```verilog
wire ebreak_in_fetch = (if_instruction == EBREAK_INSTRUCTION)
                     || (if_instruction == 32'h00000000);
wire load_use_stall;
wire flush           = ex_mem_valid & ex_mem_pc_src;
wire stall_effective = load_use_stall & ~flush;
wire pc_enable = cpu_enable & ~stall_effective & (flush | ~ebreak_in_fetch);
assign pc_next = flush ? ex_mem_branch_target : if_pc_plus_4;

pc u_pc (.clk(CLOCK_50), .rst(rst), .en(pc_enable),
         .pc_next(pc_next), .pc_out(pc_out));
adder u_pc_plus_4_adder (.a(pc_out), .b(32'd4), .out(if_pc_plus_4));
instruction_memory u_instruction_memory (.addr(pc_out), .instr(if_instruction));
```

Aqui se decide la **direccion siguiente**:
- `flush` (linea 132): un salto se tomo y se resolvio en MEM (`ex_mem_pc_src`).
- `pc_next` (linea 139): el mux PCSrc del diagrama -> destino del salto si hay
  flush, o PC+4 si no.
- `pc_enable` (linea 137): el PC avanza salvo que haya stall o un `ebreak` recien
  buscado. **El flush tiene prioridad** sobre el freno por ebreak: si detras del
  salto se busco especulativamente un ebreak, la redireccion debe ganar para no
  congelar el PC en una instruccion que no se debe ejecutar. (Este detalle fue un
  bug real: sin el, la CPU se detenia antes de tiempo.)
- Las tres instancias: el PC, el sumador de PC+4 y la memoria de instrucciones.

Lo que sale de IF (`pc_out`, `if_pc_plus_4`, `if_instruction`) entra al registro
IF/ID.

## 3.6. Etapa ID (lineas 151-184)

```verilog
wire [4:0]  rs1 = if_id_instruction[19:15];
wire [4:0]  rs2 = if_id_instruction[24:20];
wire [31:0] rs1_data, rs2_data, imm;
wire ctrl_reg_write, ctrl_alu_src, ... ;

control_unit u_control_unit (.opcode(if_id_instruction[6:0]),
    .reg_write(ctrl_reg_write), ... , .alu_op(ctrl_alu_op));

register_file u_register_file (
    .clk(CLOCK_50), .rst(rst),
    .write_enable(cpu_enable & write_back_enable),
    .write_reg(write_back_rd), .write_data(write_back_data),
    .rs1(rs1), .rs2(rs2),
    .read_data1(rs1_data), .read_data2(rs2_data), ...);

imm_gen u_imm_gen (.instr(if_id_instruction), .imm_out(imm));
```

En ID se decodifica la instruccion que dejo IF/ID:
- `rs1`/`rs2`: los campos de registro fuente.
- `control_unit` genera las senales `ctrl_*` a partir del opcode.
- `register_file` lee `rs1_data`/`rs2_data` (y a la vez su puerto de escritura
  esta sirviendo a la instruccion que esta en WB; de ahi el bypass write-first).
- `imm_gen` genera el inmediato.

Todo esto (datos, inmediato, senales de control) entra al registro ID/EX.

## 3.7. Etapa EX (lineas 190-254)

Es la etapa mas densa. Primero las dos unidades de control de riesgos:

```verilog
forwarding_unit u_forwarding (
    .ex_rs1(id_ex_instruction[19:15]), .ex_rs2(id_ex_instruction[24:20]),
    .mem_reg_write(ex_mem_ctrl_reg_write), .mem_rd(ex_mem_instruction[11:7]),
    .wb_reg_write(mem_wb_ctrl_reg_write),  .wb_rd(mem_wb_instruction[11:7]),
    .forward_a(forward_a), .forward_b(forward_b));

hazard_unit u_hazard (
    .idex_valid(id_ex_valid), .idex_mem_read(id_ex_ctrl_mem_read),
    .idex_rd(id_ex_instruction[11:7]),
    .ifid_rs1(if_id_instruction[19:15]), .ifid_rs2(if_id_instruction[24:20]),
    .load_use_stall(load_use_stall));
```

Luego los multiplexores de forwarding y de operandos:

```verilog
wire [31:0] ex_mem_forward_value = (ex_mem_ctrl_jal | ex_mem_ctrl_jalr)
                                   ? ex_mem_pc_plus_4 : ex_mem_alu_result;
wire [31:0] rs1_forwarded = (forward_a == 2'b10) ? ex_mem_forward_value :
                            (forward_a == 2'b01) ? write_back_data : id_ex_rs1_data;
wire [31:0] rs2_forwarded = (forward_b == 2'b10) ? ex_mem_forward_value :
                            (forward_b == 2'b01) ? write_back_data : id_ex_rs2_data;
wire [31:0] alu_operand_a = id_ex_ctrl_alu_a_src ? id_ex_pc  : rs1_forwarded;
wire [31:0] alu_operand_b = id_ex_ctrl_alu_src   ? id_ex_imm : rs2_forwarded;
```

- `ex_mem_forward_value`: el valor a adelantar desde EX/MEM. Ojo: para JAL/JALR
  ese valor es `PC+4` (la direccion de retorno), no el resultado de la ALU.
- `rs1_forwarded`/`rs2_forwarded`: los multiplexores que controla la
  `forwarding_unit`: eligen entre el dato de ID/EX, el de EX/MEM o el de MEM/WB.
- `alu_operand_a/b`: ultimo mux antes de la ALU. A puede ser el PC (AUIPC/JAL); B
  puede ser el inmediato (loads, stores, I-type).

La ALU y su control:

```verilog
alu_control u_alu_control (.alu_op(id_ex_ctrl_alu_op),
    .func3(id_ex_instruction[14:12]), .func7(id_ex_instruction[31:25]),
    .alu_ctrl(alu_control));
alu u_alu (.a(alu_operand_a), .b(alu_operand_b), .alu_ctrl(alu_control),
    .result(alu_result), .zero(alu_zero));
```

Y la resolucion del salto (que se calcula en EX pero se **actua** en MEM):

```verilog
adder u_branch_adder (.a(id_ex_pc), .b(id_ex_imm), .out(branch_target_pcrel));

always @(*) begin    // condicion segun func3
    case (id_ex_instruction[14:12])
        3'b000:  branch_condition =  alu_zero;       // BEQ
        3'b001:  branch_condition = ~alu_zero;       // BNE
        3'b100:  branch_condition =  alu_result[0];  // BLT
        3'b101:  branch_condition = ~alu_result[0];  // BGE
        3'b110:  branch_condition =  alu_result[0];  // BLTU
        3'b111:  branch_condition = ~alu_result[0];  // BGEU
        default: branch_condition = 1'b0;
    endcase
end
wire        branch_taken     = id_ex_valid & id_ex_ctrl_branch & branch_condition;
wire        pc_src_ex        = branch_taken | (id_ex_valid & (id_ex_ctrl_jal | id_ex_ctrl_jalr));
wire [31:0] branch_target_ex = id_ex_ctrl_jalr ? alu_result : branch_target_pcrel;
wire [31:0] store_data_ex    = rs2_forwarded;
```

- `branch_target_pcrel`: el destino de un salto relativo = PC + inmediato.
- `branch_condition`: para `beq` se usa `alu_zero` (la ALU hizo a-b); para `blt`
  se usa `alu_result[0]` (la ALU hizo SLT, cuyo resultado es 0 o 1).
- `pc_src_ex`: hay que cambiar el PC (branch tomado, JAL o JALR).
- `branch_target_ex`: a donde ir. JALR salta a `rs1+imm` (= resultado de la ALU);
  el resto a PC+imm.
- `store_data_ex`: el dato a guardar en un `sw`, ya con forwarding (por si el
  valor a guardar lo produjo una instruccion inmediatamente anterior).

`pc_src_ex` y `branch_target_ex` se **latchean** en EX/MEM y se usan en MEM.

## 3.8. Etapa MEM (lineas 259-269)

```verilog
data_memory u_data_memory (
    .clk(CLOCK_50),
    .mem_write(cpu_enable & ex_mem_valid & ex_mem_ctrl_mem_write),
    .mem_read(ex_mem_ctrl_mem_read),
    .addr(ex_mem_alu_result),
    .write_data(ex_mem_store_data),
    .read_data(mem_read_data), ...);
```

La memoria de datos accede en MEM. La direccion es `ex_mem_alu_result` (la ALU la
calculo en EX). La escritura se habilita solo si la etapa es valida y tiene
`mem_write` (y el `cpu_enable` global). El dato leido `mem_read_data` se latchea
en MEM/WB.

Tambien es **aqui** donde el salto surte efecto: recordar que en IF
`flush = ex_mem_valid & ex_mem_pc_src` y `pc_next = flush ? ex_mem_branch_target : ...`.

## 3.9. Las 4 instancias de registros de pipeline (lineas 274-333)

Aqui se conectan los modulos `pipe_*`. Cada uno toma como entradas las salidas de
su etapa y produce las salidas registradas que usan las etapas siguientes. El
control de stall/flush se reparte asi:

```verilog
pipe_ifid u_if_id (... .flush(flush), .stall(load_use_stall), ...);
pipe_idex u_id_ex (... .bubble(flush | load_use_stall), ...);
pipe_exmem u_ex_mem (... .flush(flush), ...);
pipe_memwb u_mem_wb (... );   // avanza siempre
```

- IF/ID recibe `flush` y `stall` por separado (flush hace burbuja, stall congela).
- ID/EX recibe `bubble = flush | stall` (en cualquiera de los dos casos, burbuja).
- EX/MEM recibe `flush` (descarta la instruccion joven cuando el salto se toma en
  MEM). Esta es la tercera instruccion que se descarta al saltar.
- MEM/WB avanza siempre.

Asi, cuando un salto se toma (flush), se hacen burbujas en IF/ID, ID/EX y EX/MEM:
las **3** instrucciones jovenes detras del salto se descartan, y el PC se
redirige al destino.

## 3.10. Halt (lineas 336-343)

```verilog
always @(posedge CLOCK_50 or posedge rst) begin
    if (rst)
        halted <= 1'b0;
    else if (cpu_enable && mem_wb_valid &&
             (mem_wb_instruction == EBREAK_INSTRUCTION ||
              mem_wb_instruction == 32'h00000000))
        halted <= 1'b1;
end
```

Cuando un `ebreak` (o instruccion nula) **valido** llega a la etapa WB, la CPU se
detiene (`halted<=1`). Que se detenga recien en WB garantiza que todas las
instrucciones anteriores ya se retiraron y escribieron sus resultados (por
ejemplo el codigo de salida en x10). `halted` apaga `cpu_enable`, congelando todo.

## 3.11. VGA y LEDs (lineas 351 en adelante)

Se instancian `vga_controller` y `vga_debug`, pasandole a este ultimo los campos
de cada etapa (PC, instruccion, ALU) y las senales de riesgo/forwarding para que
los dibuje. `LEDR[0]` espeja `SW[0]` (modo paso); `LEDR[9]` muestra `halted`.

---

# PARTE IV. Recorridos: como fluye todo

## 4.1. Una instruccion sin complicaciones

`addi x5, x6, 10` (x5 = x6 + 10):
1. **IF:** el PC apunta a esta instruccion; sale de `instruction_memory`; se
   calcula PC+4. Al final del ciclo, IF/ID la captura.
2. **ID:** `control_unit` ve opcode I-type -> `reg_write=1`, `alu_src=1`
   (inmediato), `alu_op=11`. `register_file` lee x6 (`rs1_data`). `imm_gen` saca
   10. Todo entra a ID/EX.
3. **EX:** `alu_control` con func3=000 -> ADD. `alu_operand_a = x6`,
   `alu_operand_b = 10` (porque `alu_src=1`). La ALU da x6+10. Entra a EX/MEM.
4. **MEM:** no hace nada (no es load/store). El resultado pasa a MEM/WB.
5. **WB:** `write_back_data = alu_result`, `write_back_enable=1`,
   `write_back_rd=5` -> en el flanco, x5 <- x6+10.

## 4.2. Forwarding (riesgo de datos)

```
add x3, x1, x2
sub x4, x3, x5
```

Cuando el `sub` esta en EX, el `add` esta en MEM (su resultado vive en
`ex_mem_alu_result`). La `forwarding_unit` ve que `ex_mem_rd (=3) == ex_rs1 (=3)`
y pone `forward_a = 2'b10`. El mux `rs1_forwarded` toma entonces
`ex_mem_forward_value` en vez del valor (viejo) leido del banco. La resta usa el
x3 correcto sin frenarse. **Cero ciclos de penalizacion.**

## 4.3. Load-use (stall)

```
lw   x3, 0(x1)
add  x4, x3, x5
```

Cuando el `lw` esta en EX, el `add` esta en ID. La `hazard_unit` ve
`idex_mem_read=1` y `idex_rd (=3) == ifid_rs1 (=3)` -> `load_use_stall=1`.
`top.v` congela el PC e IF/ID y mete una burbuja en ID/EX. Un ciclo despues, el
`lw` esta en MEM/WB (ya tiene el dato) y el `add`, ahora si, entra a EX y recibe
x3 por forwarding desde MEM/WB. **Un ciclo de penalizacion.**

## 4.4. Salto tomado (flush)

```
        beq x1, x1, destino   # siempre se cumple
        addi x6, x0, 99       # NO se debe ejecutar
        ...
destino: addi x7, x0, 7
```

El `beq` viaja IF -> ID -> EX (donde se calcula que se toma) -> MEM (donde se
actua). Mientras tanto el pipeline busco las instrucciones de mas abajo. Cuando
el `beq` llega a MEM, `ex_mem_pc_src=1` -> `flush=1`: se hacen burbujas en IF/ID,
ID/EX y EX/MEM (se descartan las 3 instrucciones jovenes, incluido el `addi x6`),
y `pc_next = ex_mem_branch_target` (la direccion de `destino`). El ciclo
siguiente se busca `destino`. **Tres ciclos de penalizacion**, que es el precio
de resolver el salto en MEM (como el diagrama).

## 4.5. Resumen del ciclo completo

En cada flanco de `CLOCK_50` (si `cpu_enable=1`):
- El PC toma `pc_next`.
- Cada registro de pipeline captura su etapa anterior (o burbuja/congela segun
  stall/flush).
- El banco de registros escribe el resultado de la instruccion en WB.
- La memoria de datos escribe si la instruccion en MEM es un store.

Y combinacionalmente, dentro del ciclo, fluye: PC -> instruccion -> decodificacion
-> ALU/forwarding -> memoria -> write-back, con las unidades de forwarding y
hazard vigilando para que los datos sean siempre los correctos.
