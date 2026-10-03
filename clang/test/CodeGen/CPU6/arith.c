// Fixed-point arithmetic from the CRT0 probe and the 78x23 Mandelbrot.
// int is 16 bits. The check is that -O0 and -O2 both compile: these are
// the patterns that used to fail selection or run out of registers.
//
// REQUIRES: cpu6-registered-target
// RUN: %clang -target cpu6 -ffreestanding -O0 -S -mllvm -verify-machineinstrs -o %t %s
// RUN: %clang -target cpu6 -ffreestanding -O2 -S -mllvm -verify-machineinstrs -o %t %s

static volatile int in;
static volatile int in2;

int sq(int a) { return a * a; }
int mul(int a, int b) { return a * b; }
int shr3(int a) { return a >> 3; }
int shr4(int a) { return a >> 4; }
int inc(int a) { return a + 1; }
int dec2(int a) { return a - 2; }
int sub(int a, int b) { return a - b; }

int lt10(int n) { return n < 10; }
int lt23(int n) { return n < 23; }
int lt78(int n) { return n < 78; }
int sge(int n) { return n >= 1024; }
int ugt(unsigned n) { return n > 1023; }
int lt(int a, int b) { return a < b; }

/* Two volatile loads, then a call. */
int both(void) { return lt(in, in2); }
int diff(void) { return in - in2; }

/* Q4 step: 1.0 == 16, so >>4 returns to Q4. The 2 in 2*zr*zi is the extra bit. */
int real(int zr2, int zi2, int cr) { return ((zr2 - zi2) >> 4) + cr; }
int imag(int zr, int zi, int ci) { return ((zr * zi * 2) >> 4) + ci; }

static const char ramp[] = "  .:-=+*#%@";

int shade(int n) { return ramp[n]; }

int iter(int cr, int ci) {
  int zr = 0, zi = 0, n;

  for (n = 0; n < 10; n++) {
    int zr2 = zr * zr;
    int zi2 = zi * zi;

    if (zr2 + zi2 >= 1024)
      break;
    zi = ((zr * zi * 2) >> 4) + ci;
    zr = ((zr2 - zi2) >> 4) + cr;
  }
  return n;
}

/* lim iterations, or cap if the limit test never fails. */
int count(int lim, int cap) {
  int i = 0, c = 0, g = cap;

  while (i < lim) {
    if (g == 0)
      break;
    g = g - 1;
    i = i + 1;
    c = c + 1;
  }
  return c;
}

/* The picture, writing into a buffer instead of CRT0. */
int picture(char *out) {
  int row, ci = 22, n = 0;

  for (row = 0; row < 23; row++) {
    int col, cr = -40;

    for (col = 0; col < 78; col++) {
      out[n++] = ramp[iter(cr, ci)];
      cr += 1;
    }
    ci -= 2;
  }
  return n;
}

void emit(volatile unsigned char *stat, volatile unsigned char *data, int c) {
  while ((*stat & 2) == 0)
    ;
  *data = (unsigned char)c;
}
