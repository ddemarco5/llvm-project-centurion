// A machine multiply is 16x16 -> 32. int is 16 bits, long is 32, and long
// long is 64. The type legalizer splits a long or long long multiply into
// i16 umul_lohi and smul_lohi, and those select MUL with destination A
// (high half in A, low half in B). A plain i16 multiply selects MUL with
// destination B. A function here returns a long or an int. A long long
// return does not fit in A and B.
//
// REQUIRES: cpu6-registered-target
// RUN: %clang -target cpu6 -ffreestanding -O0 -S -mllvm -verify-machineinstrs -o %t %s
// RUN: %clang -target cpu6 -ffreestanding -O2 -S -mllvm -verify-machineinstrs -o %t %s

_Static_assert(sizeof(int) == 2, "int is one word");
_Static_assert(sizeof(long) == 4, "long is two words");
_Static_assert(sizeof(long long) == 8, "long long is four words");

// Sign-extended 16x16 -> 32. Both values fit in a word, so the high half is
// the signed product and the node is smul_lohi.
long smul16(int a, int b) { return (long)a * (long)b; }

// Zero-extended 16x16 -> 32. One unsigned widening multiply.
unsigned long umul16(unsigned a, unsigned b) {
  return (unsigned long)a * (unsigned long)b;
}

// 32x32 -> 32. The low halves widen, then the cross terms are added in.
long lmul(long a, long b) { return a * b; }

unsigned long ulmul(unsigned long a, unsigned long b) { return a * b; }

// 64x64 -> 64, truncated to the low word. The 64-bit multiply splits into
// 32-bit multiplies, and each of those splits into the i16 pair.
int qprod(long long a, long long b) { return (int)(a * b); }

int uqprod(unsigned long long a, unsigned long long b) {
  return (int)(a * b);
}

// Q16.16 product: the full signed 32x32 -> 64, then a shift of 16.
long qmul(long a, long b) {
  return (long)(((long long)a * (long long)b) >> 16);
}
