// Tests: SW + LW con direcciones calculadas por la ALU.
// Este es el escenario exacto del bug del latch: addr = base + offset calculado.
// Retorna 0 si todo pasa, -N indica que fallo el test N.

int leer(int *arr, int i) {
    return arr[i];
}

void escribir(int *arr, int i, int val) {
    arr[i] = val;
}

int main() {
    int arr[8];

    // Store directo, load directo
    arr[0] = 42;
    if (arr[0] != 42) return -1;

    // Store con indice calculado
    int i = 3;
    arr[i] = 99;
    if (arr[i] != 99) return -2;

    // Store via funcion (addr = base + i*4 calculado en ALU)
    escribir(arr, 5, 77);
    if (leer(arr, 5) != 77) return -3;

    // Escritura secuencial, lectura fuera de orden
    arr[1] = 10;
    arr[2] = 20;
    arr[3] = 30;
    if (arr[2] != 20) return -4;
    if (arr[1] != 10) return -5;
    if (arr[3] != 30) return -6;

    // Sobreescritura
    arr[0] = 0;
    arr[0] = 55;
    if (arr[0] != 55) return -7;

    return 0;
}
