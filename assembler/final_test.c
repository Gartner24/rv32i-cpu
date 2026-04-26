// ============================================================
// Libreria de estructuras y algoritmos usando solo RV32I
// Sin multiplicacion nativa, sin division, sin punto flotante
// ============================================================

// --- Utilidades basicas ---

int multiplicar(int a, int b) {
    int result = 0;
    int i = 0;
    int neg = 0;
    if (a < 0) { a = -a; neg = neg + 1; }
    if (b < 0) { b = -b; neg = neg + 1; }
    while (i < b) {
        result = result + a;
        i = i + 1;
    }
    if (neg == 1) return -result;
    return result;
}

int valor_absoluto(int x) {
    if (x < 0) return -x;
    return x;
}

int maximo(int a, int b) {
    if (a > b) return a;
    return b;
}

int minimo(int a, int b) {
    if (a < b) return a;
    return b;
}

// --- Algoritmos de busqueda ---

int busqueda_lineal(int *arr, int n, int objetivo) {
    int i = 0;
    while (i < n) {
        if (arr[i] == objetivo) return i;
        i = i + 1;
    }
    return -1;
}

int busqueda_binaria(int *arr, int n, int objetivo) {
    int bajo = 0;
    int alto = n - 1;
    while (bajo <= alto) {
        int mid = (bajo + alto) >> 1;
        if (arr[mid] == objetivo) return mid;
        if (arr[mid] < objetivo) {
            bajo = mid + 1;
        } else {
            alto = mid - 1;
        }
    }
    return -1;
}

// --- Algoritmos de ordenamiento ---

void intercambiar(int *arr, int i, int j) {
    int temp = arr[i];
    arr[i] = arr[j];
    arr[j] = temp;
}

void bubble_sort(int *arr, int n) {
    int i = 0;
    while (i < n - 1) {
        int j = 0;
        while (j < n - i - 1) {
            if (arr[j] > arr[j + 1]) {
                intercambiar(arr, j, j + 1);
            }
            j = j + 1;
        }
        i = i + 1;
    }
}

void selection_sort(int *arr, int n) {
    int i = 0;
    while (i < n - 1) {
        int min_idx = i;
        int j = i + 1;
        while (j < n) {
            if (arr[j] < arr[min_idx]) {
                min_idx = j;
            }
            j = j + 1;
        }
        if (min_idx != i) {
            intercambiar(arr, i, min_idx);
        }
        i = i + 1;
    }
}

// --- Operaciones sobre arrays ---

int suma_array(int *arr, int n) {
    int suma = 0;
    int i = 0;
    while (i < n) {
        suma = suma + arr[i];
        i = i + 1;
    }
    return suma;
}

int promedio_entero(int *arr, int n) {
    int suma = suma_array(arr, n);
    int prom = 0;
    int acum = 0;
    int i = 0;
    while (acum + n <= suma) {
        acum = acum + n;
        prom = prom + 1;
    }
    return prom;
}

int contar_si(int *arr, int n, int valor) {
    int count = 0;
    int i = 0;
    while (i < n) {
        if (arr[i] == valor) count = count + 1;
        i = i + 1;
    }
    return count;
}

void revertir_array(int *arr, int n) {
    int i = 0;
    int j = n - 1;
    while (i < j) {
        intercambiar(arr, i, j);
        i = i + 1;
        j = j - 1;
    }
}

// --- Teoria de numeros ---

int mcd(int a, int b) {
    if (a < 0) a = -a;
    if (b < 0) b = -b;
    while (a != b) {
        if (a > b) a = a - b;
        else b = b - a;
    }
    return a;
}

int mcm(int a, int b) {
    int g = mcd(a, b);
    int prod = multiplicar(a, b);
    int result = 0;
    int acum = 0;
    while (acum + g <= prod) {
        acum = acum + g;
        result = result + 1;
    }
    return result;
}

int es_primo(int n) {
    if (n < 2) return 0;
    int divisor = 2;
    while (divisor < n) {
        int temp = n;
        while (temp > 0) temp = temp - divisor;
        if (temp == 0) return 0;
        divisor = divisor + 1;
    }
    return 1;
}

int fibonacci(int n) {
    if (n <= 0) return 0;
    if (n == 1) return 1;
    int a = 0;
    int b = 1;
    int i = 2;
    while (i <= n) {
        int temp = a + b;
        a = b;
        b = temp;
        i = i + 1;
    }
    return b;
}

int sqrt_entera(int n) {
    if (n < 0) return -1;
    if (n == 0) return 0;
    int bajo = 1;
    int alto = n;
    int resultado = 0;
    while (bajo <= alto) {
        int mid = (bajo + alto) >> 1;
        int mid2 = multiplicar(mid, mid);
        if (mid2 == n) return mid;
        if (mid2 < n) {
            resultado = mid;
            bajo = mid + 1;
        } else {
            alto = mid - 1;
        }
    }
    return resultado;
}

// --- Operaciones de bits ---

int contar_bits(int n) {
    int count = 0;
    int i = 0;
    while (i < 32) {
        if (n & 1) count = count + 1;
        n = n >> 1;
        i = i + 1;
    }
    return count;
}

int es_potencia_de_dos(int n) {
    if (n <= 0) return 0;
    return (n & (n - 1)) == 0;
}

int bit_mas_significativo(int n) {
    int pos = 0;
    int i = 0;
    while (i < 32) {
        if (n & 1) pos = i;
        n = n >> 1;
        i = i + 1;
    }
    return pos;
}

// --- Cadenas de caracteres (como arrays de int) ---

int longitud(int *str) {
    int len = 0;
    while (str[len] != 0) {
        len = len + 1;
    }
    return len;
}

int comparar(int *a, int *b) {
    int i = 0;
    while (a[i] != 0 && b[i] != 0) {
        if (a[i] < b[i]) return -1;
        if (a[i] > b[i]) return 1;
        i = i + 1;
    }
    if (a[i] == 0 && b[i] == 0) return 0;
    if (a[i] == 0) return -1;
    return 1;
}

void copiar(int *dest, int *src) {
    int i = 0;
    while (src[i] != 0) {
        dest[i] = src[i];
        i = i + 1;
    }
    dest[i] = 0;
}
