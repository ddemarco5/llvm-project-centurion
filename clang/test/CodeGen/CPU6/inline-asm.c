// C inline asm. "r" lets the allocator pick a register, "{A}" names one,
// "i" is an immediate, and "m" is a load/store address. The check is that
// -O0 and -O2 both compile; llvm/test/CodeGen/CPU6/inline-asm.ll locks the
// text those constraints print.
//
// REQUIRES: cpu6-registered-target
// RUN: %clang -target cpu6 -ffreestanding -O0 -S -mllvm -verify-machineinstrs -o %t %s
// RUN: %clang -target cpu6 -ffreestanding -O2 -S -mllvm -verify-machineinstrs -o %t %s

int copy(int x) {
  int y;
  __asm__("XFR %1,%0" : "=r"(y) : "r"(x));
  return y;
}

int addimm(int x) {
  int y;
  __asm__("ADD %1,%0,%2" : "=r"(y) : "r"(x), "i"(5));
  return y;
}

int in_a(int x) {
  int y;
  __asm__("INR %0,0" : "={A}"(y) : "0"(x));
  return y;
}

unsigned char copyb(unsigned char x) {
  unsigned char y;
  __asm__("XFRB %1,%0" : "=r"(y) : "r"(x));
  return y;
}

int g = 7;

int loadg(void) {
  int y;
  __asm__("LDA %1" : "={A}"(y) : "m"(g));
  return y;
}

int loadlocal(int x) {
  int y;
  __asm__("LDA %1" : "={A}"(y) : "m"(x));
  return y;
}

void storeg(int v) { __asm__ volatile("STA %1" : : "{A}"(v), "m"(g)); }
