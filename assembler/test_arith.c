// Tests: ADD, SUB, negacion, valor absoluto, max, min
// Sin memoria, sin bucles. Objetivo: ~60-70 instrucciones.
// Retorna 0 si todo pasa, -N indica que fallo el test N.

int maximo(int a, int b) {
    if (a > b) return a;
    return b;
}

int minimo(int a, int b) {
    if (a < b) return a;
    return b;
}

int valor_abs(int x) {
    if (x < 0) return -x;
    return x;
}

int main() {
    if (maximo(3, 7)      != 7)   return -1;
    if (maximo(10, 2)     != 10)  return -2;
    if (maximo(-5, -1)    != -1)  return -3;
    if (minimo(3, 7)      != 3)   return -4;
    if (minimo(-5, -1)    != -5)  return -5;
    if (valor_abs(-42)    != 42)  return -6;
    if (valor_abs(42)     != 42)  return -7;
    if (valor_abs(0)      != 0)   return -8;
    if (10 - 3            != 7)   return -9;
    if (-10 + 3           != -7)  return -10;
    return 0;
}
