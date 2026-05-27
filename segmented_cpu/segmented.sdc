# Reloj principal de 50 MHz (entrada CLOCK_50).
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]

# VGA_CLK ahora se maneja directamente desde CLOCK_50 (800x600@72, 50 MHz).
# Reloj generado 1:1 sobre el pin de salida para acotar el clock-forwarding.
create_generated_clock -name VGA_CLK \
    -source [get_ports CLOCK_50] \
    [get_ports VGA_CLK]

derive_clock_uncertainty
