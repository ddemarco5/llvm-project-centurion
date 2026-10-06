// long is 32 bits (two words) and long long / double are 64 bits (four).
// Words are big-endian: the high word is A and the low word is B. A second
// long takes Y and Z the same way. A long long or a double fills A, B, Y,
// and Z from high to low. There is no FPU, so each double operation is a
// compiler-rt libcall (__adddf3 and the rest) that returns in those four
// registers. The check is that -O0 and -O2 both compile.
//
// REQUIRES: cpu6-registered-target
// RUN: %clang -target cpu6 -ffreestanding -O0 -S -mllvm -verify-machineinstrs -o %t %s
// RUN: %clang -target cpu6 -ffreestanding -O2 -S -mllvm -verify-machineinstrs -o %t %s

_Static_assert(sizeof(long) == 4, "long is two words");
_Static_assert(sizeof(long long) == 8, "long long is four words");

long land(long a, long b) { return a & b; }

long ladd(long a, long b) { return a + b; }

long lshl(long a, int n) { return a << n; }

unsigned long lshr(unsigned long a, int n) { return a >> n; }

long lsar(long a, int n) { return a >> n; }

long lmul(long a, long b) { return a * b; }

long ldiv(long a, long b) { return a / b; }

long lmod(long a, long b) { return a % b; }

int lcmp(long a, long b) { return a < b; }

int lucmp(unsigned long a, unsigned long b) { return a < b; }

unsigned long lmixu(unsigned long a, unsigned b, unsigned long c) {
  return a + b + c;
}

int qlow(long long a) { return (int)a; }

int qhi(long long a) { return (int)(a >> 16); }

int qeq(long long a, long long b) { return a == b; }

int qcmp(long long a, long long b) { return a < b; }

int qand(long long a, long long b) { return (int)(a & b); }

int qmix(long long a, int b, long long c) { return (int)(a + b + c); }

// The shift is one loop over the four words. Storing the result keeps every
// word live without going through the return registers.
long long qs;
unsigned long long qu;

void qshl_store(unsigned long long a, int n) { qu = a << n; }

void qlshr_store(unsigned long long a, int n) { qu = a >> n; }

void qasr_store(long long a, int n) { qs = a >> n; }

long long qadd(long long a, long long b) { return a + b; }

long long qzext(unsigned int a) { return a; }

long long qsext(int a) { return a; }

float fadd(float a, float b) { return a + b; }

double dadd(double a, double b) { return a + b; }

double dsub(double a, double b) { return a - b; }

double dmul(double a, double b) { return a * b; }

double ddiv(double a, double b) { return a / b; }

double dneg(double a) { return -a; }

int dlt(double a, double b) { return a < b; }

int deq(double a, double b) { return a == b; }

int dtoi(double a) { return (int)a; }

double itod(int a) { return (double)a; }

double ftod(float a) { return a; }

float dtof(double a) { return (float)a; }

double dmix(double a, double b, double c) { return a * b + c; }
