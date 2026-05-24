# Cargar el programa "desde afuera" (sin hornearlo en la compilacion)

La memoria de instrucciones (`instruction_memory.v`) ya no depende de recompilar
el HDL para cambiar el programa. El programa vive en un archivo `program.mif`
(Memory Initialization File de Intel/Altera) que se puede regenerar y recargar.

## 1. Generar el `.mif` desde el ensamblador

El ensamblador ahora emite un `.mif` junto al `.hex`:

```
cd assembler
python assembler.py mi_programa.asm program.hex program.bin
# produce ademas program.mif
cp program.mif ../segmented_cpu/program.mif
```

El `.mif` tiene una palabra de 32 bits por direccion (la direccion es el indice
de palabra = PC/4) y rellena con ceros hasta `DEPTH=1024`.

## 2. Sintesis (Quartus)

`instruction_memory.v` inicializa la RAM on-chip desde `program.mif` mediante el
atributo `(* ram_init_file = "program.mif" *)`. El `.mif` esta listado en
`segmented.qsf` (`MIF_FILE program.mif`). Compila el proyecto una vez.

## 3. Cambiar el programa SIN recompilar el HDL

Opcion A - Update MIF (rapido, sin re-fitting):
1. Regenera `program.mif` (paso 1) con el nuevo programa.
2. En Quartus: `Processing > Update Memory Initialization File`.
3. `Processing > Start > Start Assembler` (solo el assembler, no el fitter).
4. Reprograma la placa con el nuevo `.sof`.

Opcion B - In-System Memory Content Editor (edicion en vivo por JTAG):
Para editar el contenido de la RAM en la placa sin regenerar el `.sof`, la
memoria debe exponerse como "In-System Memory". En Quartus Lite esto se hace
con el IP de RAM:
1. `Tools > IP Catalog > Basic Functions > On Chip Memory > RAM: 1-PORT`.
   - Ancho 32 bits, 1024 palabras, salida **no registrada** (la CPU espera
     lectura combinacional), init con `program.mif`.
   - Marca "Allow In-System Memory Content Editor to capture and update content
     independently of the system clock" y ponle un Instance ID (p.ej. `IMEM`).
2. Reemplaza la RAM inferida por la instancia del IP en `instruction_memory.v`
   (rama de sintesis), manteniendo la rama `SIMULATION` con `$readmemh`.
3. Compila una vez. Luego `Tools > In-System Memory Content Editor`, conecta por
   JTAG, importa el `.mif` y escribe la RAM en vivo (resetea la CPU con KEY[0]
   despues de cargar).

> El IP de RAM se genera con el asistente grafico de Quartus (produce un `.qip`),
> por eso no esta incluido como Verilog en el repo. La ruta por `ram_init_file`
> (Opcion A) ya funciona sin el IP.

## 4. Simulacion

Los testbenches compilan con `-DSIMULATION` (ver `test/Makefile`), asi que en
simulacion la memoria usa `$readmemh(HEX_FILE)` y cada testbench elige su
programa con `defparam dut.u_imem.HEX_FILE = "...";`. El camino de sintesis
(`.mif`) no afecta la simulacion.

## Fallback

Si en la placa el atributo `ram_init_file` diera problemas, compila definiendo
`SIMULATION` tambien en sintesis (Assignments > Settings > Verilog HDL Input >
Macro: `SIMULATION`). Eso vuelve a `$readmemh(program.hex)`, el camino probado
del monociclo. En ese caso cambiar el programa si requiere recompilar.
