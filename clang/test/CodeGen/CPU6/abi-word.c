// C calls on CPU6. int is 16 bits and the first four words arrive in A, B, Y, Z.
// A fifth word is stored at the caller's S. The check is that -O0 and -O2
// both compile.
//
// REQUIRES: cpu6-registered-target
// RUN: %clang -target cpu6 -ffreestanding -O0 -S -mllvm -verify-machineinstrs -o %t %s
// RUN: %clang -target cpu6 -ffreestanding -O2 -S -mllvm -verify-machineinstrs -o %t %s

_Static_assert(sizeof(int) == 2, "int is a word");
_Static_assert(sizeof(void *) == 2, "pointer is a word");

int wadd(int a, int b) { return a + b; }

/* Fifth and sixth words go on the stack. */
int take6(int a, int b, int c, int d, int e, int f) { return a + f; }

int pass6(int a, int b, int c, int d, int e, int f) {
  return take6(a, b, c, d, e, f);
}

unsigned char ubyte(unsigned char x) { return x + 1; }

signed char sbyte(signed char x) { return x - 1; }

int ucmp(unsigned a, unsigned b) { return a < b; }

int classify(int x) {
  switch (x) {
  case 0:
    return 10;
  case 1:
    return 20;
  case 7:
    return 30;
  default:
    return x;
  }
}
