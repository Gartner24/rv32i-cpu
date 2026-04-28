int suma(int a, int b) {
    return a + b;
}

int main() {
    int r1 = suma(3, 4);        // r1 = 7
    int r2 = suma(r1, -2);      // r2 = 5
    int r3 = r1 + r2;           // r3 = 12
    if (r3 == 12) return 0;     // exito: a0 = 0
    return -1;                   // fallo: a0 = -1
}
