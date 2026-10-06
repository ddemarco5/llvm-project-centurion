// long is 32 bits (two words) and long long is 64 bits (four). Words are
// big-endian: the high word of a long is A and the low word is B. A second
// long takes Y and Z the same way. A long long fills A, B, Y, and Z from
// high to low. RetCC_CPU6 only has A and B, so a function here never returns
// a long long; it returns the low word or a compare result. The check is
// that -O0 and -O2 both compile. Cases codegen rejects stay commented out.
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

// A long long still cannot be returned (see below). The shift itself is one
// loop over the four words; these keep every word live by storing it.
long long qs;
unsigned long long qu;

void qshl_store(unsigned long long a, int n) { qu = a << n; }

void qlshr_store(unsigned long long a, int n) { qu = a >> n; }

void qasr_store(long long a, int n) { qs = a >> n; }

// TODO(cpu6): returning a long long. An i64 is four words and RetCC_CPU6 only
// assigns A and B, so lowering reports "unable to allocate function return #2".
// The same return path rejects a widening cast to long long.
// long long qadd(long long a, long long b) { return a + b; }
// long long qzext(unsigned int a) { return a; }
// long long qsext(int a) { return a; }

float fadd(float a, float b) { return a + b; }

// TODO(cpu6): double arithmetic. A double softens to i64, four words, and
// RetCC_CPU6 only assigns A and B, so the return is rejected with
// "unable to allocate function return #2".
// double dadd(double a, double b) { return a + b; }
