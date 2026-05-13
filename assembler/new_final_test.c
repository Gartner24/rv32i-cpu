// Test final compacto: aritmetica, memoria, bucles, bits, llamadas.
// Disenado para caber en 256 instrucciones (incluido crt0).
// Retorna 0 si todo pasa, -N indica que fallo el test N.

int maximo(int a, int b) {
    if (a > b) return a;
    return b;
}

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

int suma_array(int *arr, int n) {
    int s = 0;
    int i = 0;
    while (i < n) {
        s = s + arr[i];
        i = i + 1;
    }
    return s;
}

int main() {
    // Aritmetica y ramas
    if (maximo(10, 42) != 42) return -1;
    if (maximo(42, 10) != 42) return -2;

    // Bucles
    if (fibonacci(8)   != 21) return -3;
    if (fibonacci(1)   != 1)  return -4;

    // Memoria: SW + LW con direccion calculada (el escenario del bug del latch)
    int arr[5];
    arr[0] = 10;
    arr[1] = 20;
    arr[2] = 30;
    arr[3] = 40;
    arr[4] = 50;
    if (suma_array(arr, 5) != 150) return -5;
    if (arr[2]             != 30)  return -6;

    // Bits
    if ((0xF0 & 0xFF) != 0xF0) return -7;
    if ((0x0F | 0xF0) != 0xFF) return -8;
    if ((1 << 3)      != 8)    return -9;

    return 0;
}
