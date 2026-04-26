#define RV32I_RESULT_BASE 0x200

#define RV32I_SET_RESULT(val) do { \
*((volatile int*)(RV32I_RESULT_BASE)) = (val); \
} while(0)

int min(int x, int y) {
if (x < y) {
return x;
} else {
return y;
}
}

int main() {
int x = min(12, 14);
RV32I_SET_RESULT(x);
return 0;
}
