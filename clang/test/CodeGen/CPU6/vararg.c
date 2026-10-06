// Variadic functions. A va_list walks the argument-register homes and then
// the stack words. int is one word, long is two. The check is that -O0 and
// -O2 both compile.
//
// REQUIRES: cpu6-registered-target
// RUN: %clang -target cpu6 -ffreestanding -O0 -S -mllvm -verify-machineinstrs -o %t %s
// RUN: %clang -target cpu6 -ffreestanding -O2 -S -mllvm -verify-machineinstrs -o %t %s

typedef __builtin_va_list va_list;
#define va_start(ap, last) __builtin_va_start(ap, last)
#define va_arg(ap, type) __builtin_va_arg(ap, type)
#define va_end(ap) __builtin_va_end(ap)
#define va_copy(dst, src) __builtin_va_copy(dst, src)

int sum_n(int n, ...) {
  va_list ap;
  int s = 0;
  int i;
  va_start(ap, n);
  for (i = 0; i < n; i++)
    s += va_arg(ap, int);
  va_end(ap);
  return s;
}

int stack_pair(int a, int b, int c, int d, ...) {
  va_list ap;
  int x, y;
  va_start(ap, d);
  x = va_arg(ap, int);
  y = va_arg(ap, int);
  va_end(ap);
  return x + y;
}

int after_long(int tag, ...) {
  va_list ap;
  long v;
  int n;
  va_start(ap, tag);
  v = va_arg(ap, long);
  n = va_arg(ap, int);
  va_end(ap);
  return n + (int)v;
}

int copied(int n, ...) {
  va_list ap, aq;
  int x, y;
  va_start(ap, n);
  va_copy(aq, ap);
  x = va_arg(ap, int);
  y = va_arg(aq, int);
  va_end(aq);
  va_end(ap);
  return x + y;
}

int split_long(int a, int b, int c, ...) {
  va_list ap;
  long v;
  int n;
  va_start(ap, c);
  v = va_arg(ap, long);
  n = va_arg(ap, int);
  va_end(ap);
  return n + (int)v;
}
