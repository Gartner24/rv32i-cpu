# =============================================================================
# segmented.sdc - Restricciones de tiempo (Synopsys Design Constraints).
# Sin este archivo, el Timing Analyzer asume un reloj de 1 GHz (1 ns) y reporta
# "timing not met" falsamente. El reloj real de la DE1-SoC es de 50 MHz (20 ns).
# =============================================================================

# Reloj principal: 50 MHz -> periodo 20 ns. Toda la CPU corre en este dominio.
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]

# Reloj de pixel de la VGA: CLOCK_50 dividido por 2 (~25 MHz) generado por
# clock_div dentro de vga_controller (registro state[0]).
create_generated_clock -name VGA_CLK25 -source [get_ports CLOCK_50] -divide_by 2 \
    [get_registers {*u_clkdiv|state[0]}]

derive_clock_uncertainty

# La VGA solo lee estado de la CPU para mostrarlo (no es una ruta critica);
# se tratan como grupos de reloj independientes para no analizar ese cruce.
set_clock_groups -asynchronous \
    -group {CLOCK_50} \
    -group {VGA_CLK25}
