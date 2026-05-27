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
"lleno").

### Por que esto permite un reloj mas rapido

Esta es la idea mas importante, asi que vamos despacio.

**Que es el periodo de reloj.** El reloj de una CPU es una senal que sube y baja
sin parar. Los flip-flops (registros) solo guardan datos en el flanco de subida.
El tiempo entre un flanco y el siguiente es el **periodo** (T). La **frecuencia**
es cuantos flancos hay por segundo: `frecuencia = 1 / T`. Si T = 20 ns, entonces
hay 1/20ns = 50,000,000 flancos por segundo = **50 MHz**. Periodo mas corto =
frecuencia mas alta = mas operaciones por segundo.

**La regla de oro del periodo.** Entre dos flancos, las senales tienen que viajar
por la logica combinacional (sumadores, ALU, memorias, muxes...) y **llegar
estables** a la entrada del siguiente registro antes del proximo flanco. Si el
flanco llega antes de que la senal se estabilice, el registro guarda basura. Por
lo tanto:

```
periodo de reloj >= retardo del camino combinacional mas largo
```

El camino combinacional mas largo se llama **camino critico**. El reloj no puede
ir mas rapido que su camino critico.

**El problema del monociclo.** En una CPU monociclo, UNA instruccion recorre
TODO el camino en un solo ciclo: leer la instruccion + decodificar + ALU +
acceder a memoria + escribir el registro. Supongamos (numeros de ejemplo) que
cada parte tarda:

```
IF = 2 ns,  ID = 1 ns,  EX = 2 ns,  MEM = 2 ns,  WB = 1 ns
```

En el monociclo, el camino critico es la **suma de todo**: 2+1+2+2+1 = **8 ns**.
El periodo tiene que ser >= 8 ns, asi que la frecuencia maxima es 1/8ns = 125 MHz.
Una instruccion tarda 8 ns, y el reloj no puede ir mas rapido que eso.

**Que cambia al segmentar.** Al partir el trabajo en 5 etapas con un registro de
pipeline entre cada una, ahora **entre flanco y flanco una senal solo tiene que
cruzar UNA etapa**, no las cinco. El camino critico ya no es la suma, sino la
**etapa mas lenta**:

```
camino critico segmentado = max(2, 1, 2, 2, 1) = 2 ns
```

Asi que el periodo puede bajar a ~2 ns y la frecuencia subir a ~500 MHz: el reloj
late mucho mas rapido porque en cada latido solo pide cruzar una etapa.

**El resultado.** Aunque una instruccion individual sigue tardando 5 ciclos en
cruzar el pipeline (su *latencia* no mejora, incluso empeora un poco por los
registros intermedios), como el reloj es mucho mas rapido Y sale una instruccion
por ciclo cuando el pipeline esta lleno, el *rendimiento total* (instrucciones
por segundo) sube muchisimo. En el ejemplo: el monociclo hace 1 instruccion cada
8 ns; el segmentado, una vez lleno, hace 1 instruccion cada 2 ns. ~4x mas
trabajo por segundo con el mismo hardware de calculo, solo reorganizado.

> Idea en una frase: segmentar no hace que una instruccion termine antes; hace
> que el reloj pueda ir mas rapido (porque cada ciclo solo cruza una etapa) y que
> salga una instruccion por ciclo, asi que se terminan muchas mas por segundo.

(En la DE1-SoC el reloj es fijo de 50 MHz / 20 ns, asi que no "subimos" la
frecuencia; pero el principio es el mismo: cada etapa es corta y holgada dentro
de esos 20 ns. De hecho el camino critico real de esta CPU es de ~10 ns, comodo
dentro del periodo de 20 ns.)

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

## 1.3. Los registros de pipeline (las "paredes" entre etapas)

Antes de nada, dos palabras que vas a oir mucho:

- **Flip-flop (o registro):** una celdita de memoria diminuta hecha de
  transistores que guarda unos bits. Lo especial es **cuando** cambia: solo en el
  instante del flanco del reloj (el "tic"). Entre un tic y el siguiente, mantiene
  congelado lo que tenia guardado, pase lo que pase en su entrada. Un "registro"
  de 32 bits es simplemente 32 flip-flops uno al lado del otro.
- **Capturar (o "latchear"):** en el tic del reloj, el registro le saca una
  *foto* a lo que hay en su entrada y la guarda en su salida hasta el proximo tic.

Ahora, **que es un registro de pipeline.** Entre cada par de etapas
(IF-ID, ID-EX, EX-MEM, MEM-WB) ponemos uno de estos registros. Hay 4:

```
 IF -> [IF/ID] -> ID -> [ID/EX] -> EX -> [EX/MEM] -> MEM -> [MEM/WB] -> WB
```

**Para que sirven (la analogia de la bandeja).** Volvamos a la linea de montaje.
Entre un trabajador y el siguiente hay una **bandeja**. Cuando suena la campana
(el tic del reloj), cada trabajador deja su trabajo a medias en la bandeja para
el de adelante, y a la vez recoge la bandeja del de atras. Esa bandeja es el
registro de pipeline: congela el trabajo a medias de cada etapa para que la
etapa siguiente lo recoja con calma el ciclo que viene.

**Por que son imprescindibles.** La logica de cada etapa (sumadores, ALU, etc.)
es combinacional: si conectaramos la salida de EX directo a la entrada de MEM sin
bandeja, en cuanto EX empezara a procesar la instruccion *siguiente*, los valores
de MEM cambiarian de golpe y se mezclaria todo. El registro de pipeline pone una
"pared": guarda la foto del ciclo y aisla una instruccion de otra.

**Que guarda cada bandeja.** Todo lo que las etapas de mas adelante van a
necesitar de esa instruccion: su PC, la instruccion misma, los datos que se
leyeron de los registros, el inmediato y **todas las senales de control**.

**Las senales de control viajan con la instruccion.** Las senales que dicen "esto
escribe memoria", "esto escribe un registro", etc., se calculan UNA sola vez (en
ID) y despues *viajan dentro de las bandejas* hasta la etapa donde se usan.
Ejemplo concreto: `mem_write` (escribir en memoria) se genera en ID, pero la
escritura en memoria pasa en MEM. Asi que `mem_write` viaja ID/EX -> EX/MEM y
recien ahi, en MEM, se usa. Es como ponerle a la pieza una etiqueta con
instrucciones que la acompana por toda la linea.

**El bit `valid`.** Cada bandeja lleva ademas un bit que dice "aqui hay una
instruccion de verdad" (`valid=1`) o "aqui no hay nada util" (`valid=0`). Ese
bit es la base de las **burbujas** (lo vemos en 1.5).

## 1.4. Latencia y throughput (rapidez de UNO vs. cuantos por segundo)

Primero, **ciclo**: el tiempo entre dos tics del reloj. En la DE1-SoC dura
**20 ns** (porque el reloj es de 50 MHz). Todo el pipeline avanza un pasito en
cada ciclo.

Hay dos formas de medir "rapidez", y se confunden mucho:

- **Latencia** = cuanto tarda **UNA** instruccion de principio a fin. En este
  pipeline, una instruccion entra por IF y sale por WB despues de **5 ciclos**.
  Esa es su latencia: 5 ciclos.
- **Throughput** (rendimiento, o "caudal") = **cuantas** instrucciones terminas
  por unidad de tiempo. Cuando el pipeline esta lleno, sale **1 instruccion por
  ciclo**.

**Analogia del lavadero de autos.** Un auto tarda, digamos, 10 minutos en pasar
por las 5 estaciones del lavadero (mojar, enjabonar, cepillar, enjuagar, secar).
Esa es la *latencia*: 10 minutos por auto, siempre. Pero como hay un auto en cada
estacion a la vez, **sale un auto terminado cada 2 minutos**. Ese es el
*throughput*. Si te preguntan "cuanto tarda lavar un auto" la respuesta es 10
min (latencia); si te preguntan "cuantos autos lavas por hora" la respuesta sale
del throughput (uno cada 2 min = 30 por hora).

Lo mismo aqui: segmentar **no baja la latencia** de una instruccion (sigue
tardando sus 5 ciclos, incluso un poquito mas por las bandejas). Lo que mejora
brutalmente es el **throughput**: casi una instruccion terminada por ciclo.

Cuenta practica: si un programa tarda **N ciclos**, el tiempo real es
**N x 20 ns**. Por eso los reportes dicen, por ejemplo, "640 ciclos = 12800 ns".

El throughput ideal (1 por ciclo) **no siempre se logra**, porque aparecen los
**riesgos**, que es justo lo que sigue.

## 1.5. Los riesgos (hazards): los problemas de tener varias a la vez

**Hazard** es simplemente la palabra en ingles para "riesgo" o "peligro". Aqui
significa: *una situacion en la que tener varias instrucciones en vuelo a la vez
podria dar un resultado incorrecto si no hacemos algo*. Hay tres tipos. Para cada
uno hay un nombre del problema y un nombre de la solucion; los explico en
cristiano.

### A) Riesgo de datos: "necesito un numero que todavia no esta listo"

Tambien se le dice **RAW** (de "Read After Write": leer despues de escribir). El
problema: una instruccion quiere usar un registro que una instruccion anterior
**todavia no termino de escribir**.

```
add x3, x1, x2     # calcula x3 = x1 + x2 (escribe x3 al final, en WB)
sub x4, x3, x5     # quiere usar x3 YA, en su etapa EX
```

Cuando el `sub` llega a EX para restar, el `add` apenas va por MEM: **todavia no
guardo x3 en el banco de registros**. Si el `sub` leyera el banco, agarraria el
x3 *viejo* (incorrecto).

**Solucion: forwarding (adelantamiento, tambien "bypass").** La palabra asusta
pero la idea es simple: el resultado de `x3` **ya existe** un poquito antes de
guardarse en el banco (esta a la salida de la ALU, viajando en una bandeja). En
vez de esperar a que se guarde, lo tomamos *de la bandeja directamente* y se lo
pasamos a la ALU del `sub`. Es un **atajo**: como pasarle el ingrediente
directo de una mano a otra en vez de guardarlo en la alacena y volver a sacarlo.
Esto no cuesta ningun ciclo extra. Lo decide el modulo `forwarding_unit.v`.

### B) Riesgo load-use: "el dato viene de memoria y todavia no llego"

Es un caso especial del anterior, pero **peor**, porque el dato viene de la
memoria de datos:

```
lw   x3, 0(x1)     # CARGA x3 desde memoria (el dato sale recien en MEM)
add  x4, x3, x5    # quiere x3 en EX, un ciclo ANTES de que exista
```

Aqui el atajo (forwarding) **no alcanza**: el dato cargado no existe en ningun
lado hasta despues de la etapa MEM, y el `add` lo necesita un ciclo antes. No se
puede adelantar algo que todavia no se calculo.

**Solucion: stall (frenar / hacer esperar).** "Stall" = parar, congelar por un
momento. Frenamos al `add` **un ciclo** (lo hacemos esperar quieto). En ese ciclo
de espera, el `lw` avanza y termina de traer el dato; al ciclo siguiente el `add`
arranca y ahora si recibe x3 por forwarding. Costo: **1 ciclo perdido**. Ese
hueco de espera se llama **burbuja** (ver mas abajo). Lo detecta `hazard_unit.v`.

### C) Riesgo de control: "salte, pero ya empece a hacer lo que venia despues"

Pasa con los saltos (`beq`, `jal`, `jalr`). El pipeline va siempre un paso
adelante: mientras decide si un salto se toma, **ya empezo a buscar las
instrucciones que estaban fisicamente debajo** del salto. Pero si el salto se
toma, esas instrucciones **no debian ejecutarse** (la ejecucion se fue a otro
lado).

```
        beq x1, x1, destino   # este salto SI se toma
        addi x6, x0, 99       # esta de NO deberia ejecutarse...
        ...                   # ...pero el pipeline ya la empezo
destino: addi x7, x0, 7       # aqui es donde hay que seguir
```

**Solucion: flush (descartar / tirar a la basura).** "Flush" = vaciar, descartar.
A las instrucciones que se buscaron por error las **convertimos en burbujas**
(las anulamos para que no escriban nada) y mandamos el PC al destino correcto.
En esta CPU el salto se decide en la etapa **MEM**, asi que para cuando nos damos
cuenta ya entraron **3** instrucciones equivocadas: se descartan las 3. Costo:
3 ciclos perdidos por cada salto tomado.

### Que es exactamente una "burbuja"

Una **burbuja** es una instruccion *vacia*: ocupa un lugar en el pipeline pero no
hace absolutamente nada (no escribe registros ni memoria). Es el equivalente a un
**NOP** ("no operation", una instruccion que no hace nada). Tecnicamente se crea
poniendo el bit `valid` de esa bandeja en 0 y apagando todas las senales de
control con efecto (`reg_write=0`, `mem_write=0`, ...). Tanto el stall como el
flush funcionan **metiendo burbujas** en el pipeline.

### Mini-diccionario de esta seccion

- **hazard / riesgo:** situacion que podria dar un resultado incorrecto al tener
  varias instrucciones a la vez.
- **forwarding / adelantamiento / bypass:** atajo que pasa un resultado de una
  bandeja directo a quien lo necesita, sin esperar a guardarlo en el banco.
- **stall:** frenar (hacer esperar) una instruccion uno o mas ciclos.
- **flush:** descartar instrucciones que se buscaron por error tras un salto.
- **burbuja / NOP:** instruccion vacia que no hace nada; el "relleno" que dejan
  un stall o un flush.

## 1.6. Las memorias: por bytes, sub-palabra y RAM de bloque (M10K)

Tres ideas sobre como funcionan la memoria de programa y la de datos. Son
estandar de RV32I y, ademas, lo que pide aprovechar bien el FPGA.

**Direccionada por bytes (y palabras = 4 bytes).** La memoria se cuenta en
**bytes**. Una palabra de 32 bits son **4 bytes pegados** (little-endian: el byte
de menor direccion es el menos significativo). Como cada palabra ocupa 4 bytes,
la direccion de palabra es `addr` sin sus 2 bits bajos (`addr[1:0]` dice cual de
los 4 bytes dentro de la palabra). El PC avanza de 4 en 4 por eso mismo.

**Acceso sub-palabra (lb/lh/lw, sb/sh/sw).** RV32I no solo lee/escribe palabras
enteras: tambien puede una sola **byte** (`b`) o **media palabra** (`h`).
- Al **leer**: `lb`/`lh` extienden el **signo** (rellenan arriba con el bit mas
  alto, para numeros negativos); `lbu`/`lhu` extienden con **ceros** (sin signo).
- Al **escribir**: `sb`/`sh` cambian solo 1 o 2 bytes y dejan el resto intacto;
  por eso la RAM de datos escribe **por byte** (una habilitacion por cada uno de
  los 4 carriles). Como columnas de un casillero: pones algo en un cajon sin
  tocar los otros.

**RAM de bloque (M10K) = lectura sincronica.** El FPGA tiene bloques de memoria
dedicados (M10K). Para que Quartus los use, la lectura debe ser **registrada**
(el dato sale en el flanco siguiente, no en el mismo instante). Antes las
memorias eran de lectura combinacional y se construian con miles de celdas de
logica; ahora son M10K. El truco para no perder velocidad: ese registro de
lectura **es** el mismo registro de pipeline que ya existia (la instruccion en
IF/ID y el dato de carga en MEM/WB), solo que movido adentro de la memoria. Por
eso no se agrega ningun ciclo extra.

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
    input         clk,
    input         rst,
    input         read_en,        // avanza el fetch (= cpu_enable & ~stall)
    input  [31:0] addr,           // direccion byte desde el PC
    output [31:0] instr,          // instruccion registrada (llega en ID)
    input  [31:0] debug_addr,     // indice de palabra para la VGA
    output [31:0] debug_instr     // instruccion en debug_addr (registrada)
);
localparam [31:0] NOP_INSTRUCTION = 32'h00000013;
localparam IAW = $clog2(MEM_DEPTH);

(* ramstyle = "M10K" *) reg [31:0] mem [0:MEM_DEPTH-1];
initial $readmemh(HEX_FILE, mem);

reg [31:0] instr_q;               // registro de salida = registro de instruccion IF/ID
always @(posedge clk) begin
    if (rst)          instr_q <= NOP_INSTRUCTION;
    else if (read_en) instr_q <= mem[addr[IAW+1:2]];
end
assign instr = instr_q;

reg [31:0] dbg_q;                 // puerto B, solo lectura, para la VGA
always @(posedge clk) dbg_q <= mem[debug_addr[IAW-1:0]];
assign debug_instr = dbg_q;
endmodule
```

Guarda el programa. `mem` es un arreglo de palabras de 32 bits (recuerda: una
palabra = 4 bytes concatenados). `$readmemh` lo carga desde un `.hex` (una
instruccion en hexadecimal por linea) al arrancar; Quartus respeta esa
inicializacion en la sintesis.

**Direccionada por bytes:** `addr` llega en bytes, pero como cada instruccion
ocupa 4 bytes se usa `addr[IAW+1:2]` (se descartan los 2 bits bajos) como indice
de palabra. `IAW = $clog2(MEM_DEPTH)` es la cantidad de bits de direccion (10
para 1024 palabras).

**Lectura sincronica (registrada).** Antes era combinacional; ahora la lectura
pasa por el registro `instr_q`, que se actualiza en el flanco de reloj. Esto se
hace por dos razones que van juntas:
- Permite que Quartus implemente la memoria como bloque **M10K** (la RAM de
  bloque del FPGA *exige* lectura registrada). La etiqueta `(* ramstyle="M10K"
  *)` se lo pide. Antes, con lectura combinacional, se gastaban miles de celdas
  de logica.
- Ese registro de salida `instr_q` **es** el registro de instruccion de IF/ID.
  No se agrega un ciclo extra: simplemente se mueve el registro que antes estaba
  en `pipe_ifid` hacia adentro de la memoria. Por eso `pipe_ifid` ya **no**
  latchea la instruccion (ver 2.13).

`read_en` (= `cpu_enable & ~stall`) hace que el fetch avance igual que
`pipe_ifid`; `rst` arranca `instr_q` en NOP para no decodificar basura.
`debug_instr` es un segundo puerto de solo lectura (tambien registrado) para la
columna de programa de la VGA.

Conexion: `addr` <- `pc_out`; `instr` -> entra a la etapa ID (a traves del
multiplexor de validez de `top.v`, ver 3.5). El parametro `HEX_FILE` permite que
cada programa de prueba elija su `.hex`.

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

## 2.10. data_memory.v - Memoria de datos (byte-direccionable, M10K)

Es la RAM de la CPU (256 palabras = 1 KB) para variables y la pila (stack).
Tiene dos cosas importantes que la hacen "estandar": guarda **por bytes** y su
lectura es **sincronica** (para M10K).

```verilog
module data_memory #(parameter WORDS = 256) (
    input         clk,
    input         read_en,        // = cpu_enable (congela en paso/halt)
    input         mem_read,
    input  [3:0]  byte_we,        // habilitacion por byte (sb/sh/sw)
    input  [31:0] addr,
    input  [31:0] write_data,     // dato ya alineado al carril destino
    output [31:0] read_data,
    input  [$clog2(WORDS)-1:0] debug_addr,
    output [31:0] debug_data
);
localparam AW = $clog2(WORDS);
wire [AW-1:0] w = addr[AW+1:2];

(* ramstyle = "M10K" *) reg [31:0] memory [0:WORDS-1];

always @(posedge clk) begin                 // escritura POR BYTE (4 carriles)
    if (byte_we[0]) memory[w][7:0]   <= write_data[7:0];
    if (byte_we[1]) memory[w][15:8]  <= write_data[15:8];
    if (byte_we[2]) memory[w][23:16] <= write_data[23:16];
    if (byte_we[3]) memory[w][31:24] <= write_data[31:24];
end

reg [31:0] read_q;                          // lectura registrada (llega en WB)
always @(posedge clk)
    if (read_en) read_q <= mem_read ? memory[w] : 32'b0;
assign read_data = read_q;

reg [31:0] debug_q;                         // puerto B para la VGA (registrado)
always @(posedge clk) debug_q <= memory[debug_addr];
assign debug_data = debug_q;
endmodule
```

**Guarda por bytes (4 carriles).** Cada palabra son 4 bytes. La entrada
`byte_we` de 4 bits dice cuales bytes escribir: para un `sw` se ponen los 4
(`1111`), para un `sh` 2, para un `sb` 1. Asi una escritura de 1 byte NO pisa los
otros 3 bytes de la palabra. El alineamiento (poner el dato en el carril
correcto) y el calculo de `byte_we` se hacen en `top.v` (ver 3.8) a partir de
`funct3` y `addr[1:0]`. La seleccion/extension al leer (lb/lh/lbu/lhu) tambien se
hace en `top.v`, en WB (ver 3.4).

**Lectura sincronica (registrada), igual que la memoria de instrucciones.** El
dato sale por el registro `read_q` un ciclo despues. Esto:
- permite el bloque **M10K** (`ramstyle="M10K"`); antes, con lectura
  combinacional, la RAM se hacia con miles de celdas de logica;
- NO agrega latencia: antes el dato de carga se latcheaba en el registro MEM/WB;
  ahora lo latchea la propia RAM, asi que llega a WB en el mismo momento. Por eso
  `pipe_memwb` ya no lleva el campo del dato leido (ver 2.13).

`read_en` (= `cpu_enable`) congela el registro de lectura en modo paso/halt para
que WB siga viendo el dato correcto. `addr[AW+1:2]` es el indice de palabra
(`addr[1:0]` selecciona el byte). El tamano se fija con `WORDS` (una sola
perilla; potencia de 2 multiplo de 32).

Conexion (etapa MEM): `addr` <- `ex_mem_alu_result`, `write_data` <- dato de
store ya alineado, `byte_we` <- mascara calculada en `top.v` (0 si la etapa es
burbuja o no es store), `read_data` -> va directo a la logica de carga de WB.

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
    input [31:0] in_pc, in_pc_plus_4,
    output reg [31:0] pc, pc_plus_4,
    output reg valid
);
always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc <= 0; pc_plus_4 <= 0; valid <= 0;
    end else if (enable) begin
        if (flush) begin
            valid <= 0;                       // burbuja
        end else if (stall) begin
            // mantener (la instruccion espera en ID)
        end else begin
            pc <= in_pc; pc_plus_4 <= in_pc_plus_4; valid <= 1;
        end
    end
end
endmodule
```

Guarda PC, PC+4 y `valid`. **Ya no guarda la instruccion**: como la memoria de
instrucciones ahora tiene lectura registrada (M10K, ver 2.4), su registro de
salida `instr_q` hace de registro de instruccion IF/ID. `top.v` arma la
instruccion de ID asi: `if_id_instruction = valid ? instr_q : NOP`. Por eso aqui
el `flush` solo necesita poner `valid<=0` (el multiplexor de afuera la convierte
en NOP). Su control tiene prioridades: `flush` (salto tomado) -> burbuja;
`stall` (load-use) -> congelar; si no -> capturar PC nuevo.

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
Guarda `alu_result`, PC+4, la instruccion y las `ctrl_*` de write-back. **Avanza
siempre** (no recibe flush): la instruccion que esta en MEM ya esta confirmada y
va a escribir su resultado. **Ya no guarda el dato leido de memoria**: la RAM de
datos tiene lectura registrada (M10K, ver 2.10), asi que su propio registro
entrega el dato en WB; `top.v` lo toma directo de la salida de la RAM.

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

## 3.1. Puertos y controles fisicos (lineas 23-43)

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

## 3.2. Reset, anti-rebote y clock-enable global (lineas 40-90)

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

## 3.3. Cables de los registros de pipeline (lineas 79-103)

Aqui se declaran los `wire` que llevan las salidas de cada registro de pipeline,
agrupados por etapa con prefijos completos: `if_id_*`, `id_ex_*`, `ex_mem_*`,
`mem_wb_*`. Por ejemplo `id_ex_instruction`, `ex_mem_alu_result`,
`mem_wb_ctrl_reg_write`. Solo verlos da el mapa de que informacion viaja en cada
etapa.

## 3.4. Etapa WB (lineas 107-130)

Se calcula primero en el archivo porque su resultado realimenta a ID (la
escritura del banco). Aqui esta la **seleccion y extension de cargas sub-palabra**
(lb/lh/lbu/lhu/lw):

```verilog
wire [4:0]  write_back_rd = mem_wb_instruction[11:7];

wire [2:0]  wb_funct3 = mem_wb_instruction[14:12];   // tipo/tamano de carga
wire [4:0]  wb_sh     = {mem_wb_alu_result[1:0], 3'b0}; // 8 * offset de byte
wire [7:0]  wb_byte   = mem_read_data >> wb_sh;       // byte seleccionado
wire [15:0] wb_half   = mem_read_data >> wb_sh;       // media palabra seleccionada
reg  [31:0] wb_load;
always @(*) begin
    case (wb_funct3)
        3'b000:  wb_load = {{24{wb_byte[7]}},  wb_byte};  // lb  (con signo)
        3'b001:  wb_load = {{16{wb_half[15]}}, wb_half};  // lh  (con signo)
        3'b100:  wb_load = {24'b0, wb_byte};              // lbu (sin signo)
        3'b101:  wb_load = {16'b0, wb_half};              // lhu (sin signo)
        default: wb_load = mem_read_data;                 // lw
    endcase
end

wire [31:0] write_back_value_pre = mem_wb_ctrl_mem_to_reg ? wb_load
                                                          : mem_wb_alu_result;
wire [31:0] write_back_data      = (mem_wb_ctrl_jal | mem_wb_ctrl_jalr)
                                   ? mem_wb_pc_plus_4 : write_back_value_pre;
wire        write_back_enable    = mem_wb_valid & mem_wb_ctrl_reg_write
                                   & (write_back_rd != 5'b0);
```

- **Carga sub-palabra:** `mem_read_data` es la palabra completa que entrego la
  RAM. Con `addr[1:0]` (offset del byte) se corre la palabra para traer el byte o
  la media palabra al fondo, y segun `funct3` se extiende con signo (lb/lh) o con
  ceros (lbu/lhu). Para `lw` se usa la palabra tal cual. Nota: `mem_read_data`
  viene **directo de la RAM** (su registro de lectura), no de `pipe_memwb`.
- `write_back_value_pre`: primer mux: dato de carga (loads) o resultado de ALU.
- `write_back_data`: segundo mux: si es JAL/JALR escribe `PC+4`; si no, lo anterior.
- `write_back_enable`: escribe solo si la instruccion es valida, tiene
  `reg_write` y `rd != 0`.

Estos cables alimentan el puerto de escritura de `register_file`.

## 3.5. Etapa IF (lineas 133-175)

```verilog
wire ebreak_in_fetch = (if_instruction == EBREAK_INSTRUCTION)
                     || (if_instruction == 32'h00000000);
wire load_use_stall;
wire flush           = ex_mem_valid & ex_mem_pc_src;
wire stall_effective = load_use_stall & ~flush;
wire pc_enable = cpu_enable & ~stall_effective & (flush | ~ebreak_in_fetch);

// La ROM tiene lectura registrada (M10K): su salida es el registro de
// instruccion IF/ID. Avanza con el fetch; el flush se aplica via valid -> NOP.
wire        fetch_en = cpu_enable & ~load_use_stall;
wire [31:0] if_id_instruction = if_id_valid ? if_instruction : NOP_INSTRUCTION;

assign pc_next = flush ? ex_mem_branch_target : if_pc_plus_4;

pc u_pc (.clk(CLOCK_50), .rst(rst), .en(pc_enable),
         .pc_next(pc_next), .pc_out(pc_out));
adder u_pc_plus_4_adder (.a(pc_out), .b(32'd4), .out(if_pc_plus_4));
instruction_memory u_instruction_memory (
    .clk(CLOCK_50), .rst(rst), .read_en(fetch_en),
    .addr(pc_out), .instr(if_instruction), /* ...puertos VGA... */ );
```

Aqui se decide la **direccion siguiente**:
- `flush`: un salto se tomo y se resolvio en MEM (`ex_mem_pc_src`).
- `pc_next`: el mux PCSrc del diagrama -> destino del salto si hay flush, o PC+4.
- `pc_enable`: el PC avanza salvo que haya stall o un `ebreak` recien buscado.
  **El flush tiene prioridad** sobre el freno por ebreak: si detras del salto se
  busco especulativamente un ebreak, la redireccion debe ganar para no congelar
  el PC. (Fue un bug real: sin esto la CPU se detenia antes de tiempo.)

**Fetch registrado (M10K).** `if_instruction` ya no es combinacional: es la
salida registrada de la ROM. Esa salida hace de registro de instruccion IF/ID,
asi que NO se agrega un ciclo (el registro solo se movio de `pipe_ifid` a la
ROM). `fetch_en = cpu_enable & ~load_use_stall` avanza el fetch igual que
`pipe_ifid`. El flush se aplica afuera: `if_id_instruction = valid ?
if_instruction : NOP`, asi una instruccion invalida (burbuja) se ve como NOP en
ID. `ebreak_in_fetch` ahora se decodifica de la instruccion ya registrada (queda
un ciclo "atrasado", efecto solo cosmetico en el PC mostrado al detenerse).

Lo que entra al registro IF/ID: `pc_out`, `if_pc_plus_4` (a `pipe_ifid`) y la
instruccion (la salida registrada de la ROM, via el mux de validez).

## 3.6. Etapa ID (lineas 178-216)

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

## 3.7. Etapa EX (lineas 218-289)

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

## 3.8. Etapa MEM (lineas 291-319)

Aqui se prepara el **store sub-palabra** (sb/sh/sw): se calcula la mascara de
bytes y se alinea el dato al carril correcto antes de entrar a la RAM.

```verilog
wire [2:0] dm_funct3 = ex_mem_instruction[14:12];
wire [1:0] dm_off    = ex_mem_alu_result[1:0];
wire       dm_store  = cpu_enable & ex_mem_valid & ex_mem_ctrl_mem_write;
reg  [3:0]  dm_be;       // habilitacion por byte
reg  [31:0] dm_wdata;    // dato corrido al carril
always @(*) begin
    case (dm_funct3)
        3'b000:  begin dm_be = 4'b0001 << dm_off; dm_wdata = ex_mem_store_data << (8*dm_off); end // sb
        3'b001:  begin dm_be = 4'b0011 << dm_off; dm_wdata = ex_mem_store_data << (8*dm_off); end // sh
        default: begin dm_be = 4'b1111;           dm_wdata = ex_mem_store_data;               end // sw
    endcase
end

data_memory #(.WORDS(DATA_WORDS)) u_data_memory (
    .clk(CLOCK_50), .read_en(cpu_enable), .mem_read(ex_mem_ctrl_mem_read),
    .byte_we(dm_store ? dm_be : 4'b0),
    .addr(ex_mem_alu_result), .write_data(dm_wdata),
    .read_data(mem_read_data), /* ...puertos VGA... */ );
```

La memoria de datos accede en MEM. La direccion es `ex_mem_alu_result` (la ALU la
calculo en EX). Para un store, `funct3` y `addr[1:0]` deciden cuantos bytes y en
que carril: el shift coloca el dato y `byte_we` enmascara los carriles que NO se
escriben (asi un `sb` no pisa el resto de la palabra). `byte_we` es 0 si la etapa
es burbuja o no es store. El dato leido `mem_read_data` ya viene registrado por la
propia RAM (lectura sincronica) y va directo a WB.

Tambien es **aqui** donde el salto surte efecto: recordar que en IF
`flush = ex_mem_valid & ex_mem_pc_src` y `pc_next = flush ? ex_mem_branch_target : ...`.

## 3.9. Las 4 instancias de registros de pipeline (lineas 321-384)

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

## 3.10. Halt (lineas 386-395)

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

## 3.11. VGA y LEDs (lineas 397 en adelante)

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
