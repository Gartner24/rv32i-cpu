// Tests: BEQ, BNE, BLT, BGE dentro de bucles reales.
// Retorna 0 si todo pasa, -N indica que fallo el test N.

int fibonacci(int n) {
    if (n <= 0) return 0;
    if (n == 1) return 1;
    int a = 0;
    int b = 1;
    int i = 2;
    while (i <= n) {
        int t = a + b;
        a = b;
        b = t;
        i = i + 1;
    }
    return b;
}

int suma_hasta(int n) {
    int s = 0;
    int i = 1;
    while (i <= n) {
        s = s + i;
        i = i + 1;
    }
    return s;
}

int main() {
    // Fibonacci: valores conocidos
    if (fibonacci(0)  != 0)  return -1;
    if (fibonacci(1)  != 1)  return -2;
    if (fibonacci(6)  != 8)  return -3;
    if (fibonacci(10) != 55) return -4;

    // Suma de Gauss: 1+2+...+10 = 55
    if (suma_hasta(10) != 55) return -5;
    if (suma_hasta(1)  != 1)  return -6;
    if (suma_hasta(0)  != 0)  return -7;

    return 0;
}
