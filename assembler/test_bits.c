// Tests: AND, OR, XOR, SLL, SRL, SRA, ANDI, ORI, XORI.
// Sin bucles, sin memoria. Objetivo: ~50-60 instrucciones.
// Retorna 0 si todo pasa, -N indica que fallo el test N.

int main() {
    // AND
    if ((0xFF & 0x0F)   != 0x0F) return -1;
    if ((0xAA & 0x55)   != 0)    return -2;

    // OR
    if ((0xF0 | 0x0F)   != 0xFF) return -3;
    if ((0x00 | 0x42)   != 0x42) return -4;

    // XOR
    if ((0xFF ^ 0xFF)   != 0)    return -5;
    if ((0xAA ^ 0x55)   != 0xFF) return -6;

    // Shift izquierda
    if ((1 << 4)        != 16)   return -7;
    if ((1 << 8)        != 256)  return -8;

    // Shift derecha logico (unsigned)
    if ((256 >> 4)      != 16)   return -9;
    if ((0xFF >> 4)     != 0x0F) return -10;

    // Shift derecha aritmetico (signed)
    int neg = -32;
    if ((neg >> 2)      != -8)   return -11;

    // Potencia de dos: n & (n-1) == 0
    if ((16 & 15)       != 0)    return -12;
    if ((15 & 14)       != 14)   return -13;

    return 0;
}
