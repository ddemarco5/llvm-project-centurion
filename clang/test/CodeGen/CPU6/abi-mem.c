// Pointers, strings, and aggregates. A pointer is a word. Clang's default
// ABI passes and returns a struct indirectly, as a pointer, so this does not
// hit the backend's byval fatal error. The check is that -O0 and -O2 both
// compile.
//
// REQUIRES: cpu6-registered-target
// RUN: %clang -target cpu6 -ffreestanding -O0 -S -mllvm -verify-machineinstrs -o %t %s
// RUN: %clang -target cpu6 -ffreestanding -O2 -S -mllvm -verify-machineinstrs -o %t %s

_Static_assert(sizeof(int) == 2, "int is a word");
_Static_assert(sizeof(void *) == 2, "pointer is a word");

const char msg[] = "hello";

int loadw(int *p) { return *p; }

void storew(int *p, int v) { *p = v; }

int indexw(int *p, int i) { return p[i]; }

int glob;

int loadg(void) { return glob; }

void storeg(int v) { glob = v; }

int sum3(int *p) { return p[0] + p[1] + p[2]; }

int local_sum(int a, int b, int c) {
  int v[3];
  v[0] = a;
  v[1] = b;
  v[2] = c;
  return sum3(v);
}

int apply(int (*f)(int, int), int a, int b) { return f(a, b); }

int slen(const char *s) {
  int n = 0;
  while (*s) {
    n++;
    s++;
  }
  return n;
}

int hello_len(void) { return slen(msg); }

char firstc(void) { return msg[0]; }

void copy5(char *d, const char *s) {
  int i;
  for (i = 0; i < 5; i++)
    d[i] = s[i];
}

// TODO(cpu6): a local array initialized from a string. Clang expands it to a
// copy, and register allocation reports "ran out of registers during register
// allocation". Walking a pointer or copying in a loop, as above, is fine.
// int starts_h(void) {
//   char buf[6] = "hello";
//   return buf[0] == 'h' && buf[4] == 'o';
// }

struct Pair {
  int x;
  int y;
};

int pair_sum(struct Pair *p) { return p->x + p->y; }

struct Pair pair_make(int x, int y) {
  struct Pair p;
  p.x = x;
  p.y = y;
  return p;
}

int pair_arg(struct Pair p) { return p.x + p.y; }

struct Big {
  int a, b, c, d, e;
};

int big_last(struct Big *p) { return p->a + p->e; }
