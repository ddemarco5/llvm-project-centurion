// Pointers, strings, and aggregates. A pointer is a word. An aggregate is
// passed and returned as i16s when the whole value fits in the registers
// still free (four for arguments, two for a return). Otherwise it is one
// pointer to the caller's memory, not a byval copy into the outgoing area.
// A return that does not fit is an sret pointer in A. The check is that -O0
// and -O2 both compile.
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

int starts_h(void) {
  char buf[6] = "hello";
  return buf[0] == 'h' && buf[4] == 'o';
}

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

int pair_use(int x, int y) {
  struct Pair p;
  p.x = x;
  p.y = y;
  return pair_arg(p);
}

/* Five words do not fit in A, B, Y, Z. One pointer. */
int big_arg(struct Big b) { return b.a + b.e; }

int big_use(void) {
  struct Big b;
  b.a = 1;
  b.b = 2;
  b.c = 3;
  b.d = 4;
  b.e = 5;
  return big_arg(b);
}

/* Five words do not fit in A and B. sret pointer, then the int in B. */
struct Big big_make(int a) {
  struct Big b;
  b.a = a;
  b.b = 0;
  b.c = 0;
  b.d = 0;
  b.e = 0;
  return b;
}

/* One byte. Coerced to i8 and promoted to a word. */
struct Byte {
  char c;
};

char byte_arg(struct Byte b) { return b.c; }

struct Byte byte_make(char c) {
  struct Byte b;
  b.c = c;
  return b;
}

char byte_use(char c) {
  struct Byte b;
  b.c = c;
  return byte_arg(b);
}

/* Three bytes, two words. Fits in A and B, including as a return. */
struct Trio {
  char a;
  int b;
};

int trio_arg(struct Trio t) { return t.a + t.b; }

struct Trio trio_make(char a, int b) {
  struct Trio t;
  t.a = a;
  t.b = b;
  return t;
}

int trio_use(char a, int b) {
  struct Trio t;
  t.a = a;
  t.b = b;
  return trio_arg(t);
}

/* Exactly four words: all of A, B, Y, Z. */
struct Quad {
  int a, b, c, d;
};

int quad_arg(struct Quad q) { return q.a + q.d; }

int quad_use(int a, int b, int c, int d) {
  struct Quad q;
  q.a = a;
  q.b = b;
  q.c = c;
  q.d = d;
  return quad_arg(q);
}

/* Three words are taken, so Quad does not fit and is one pointer in Z. */
int mix(int a, int b, int c, struct Quad q) { return a + q.d; }

int mix_use(int a, int b, int c, int d) {
  struct Quad q;
  q.a = a;
  q.b = b;
  q.c = c;
  q.d = d;
  return mix(a, b, c, q);
}
