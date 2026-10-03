// Pointers, strings, and aggregates. A pointer is a word in A. Clang's default
// ABI passes and returns a struct indirectly, as a pointer, so this does not
// hit the backend's byval fatal error.
//
// REQUIRES: cpu6-registered-target
// RUN: %clang -target cpu6 -ffreestanding -O0 -S -mllvm -verify-machineinstrs -o - %s | FileCheck %s

_Static_assert(sizeof(int) == 2, "int is a word");
_Static_assert(sizeof(void *) == 2, "pointer is a word");

const char msg[] = "hello";

// CHECK-LABEL: {{^}}loadw:
// CHECK:       XFR (A),A,0
// CHECK:       RSR
int loadw(int *p) { return *p; }

// CHECK-LABEL: {{^}}storew:
// CHECK:       STR A,(B),0
// CHECK:       RSR
void storew(int *p, int v) { *p = v; }

// Indexing an int scales by 2.
// CHECK-LABEL: {{^}}indexw:
// CHECK:       SLA
// CHECK:       ADD
// CHECK:       XFR (A),A,0
// CHECK:       RSR
int indexw(int *p, int i) { return p[i]; }

int glob;

// CHECK-LABEL: {{^}}loadg:
// CHECK-NEXT:  # %bb.0:
// CHECK-NEXT:  LDA (glob)
// CHECK-NEXT:  RSR
int loadg(void) { return glob; }

// CHECK-LABEL: {{^}}storeg:
// CHECK:       STA (glob)
// CHECK:       RSR
void storeg(int v) { glob = v; }

// CHECK-LABEL: {{^}}sum3:
// CHECK:       XFR (A),{{[A-Z]+}},0
// CHECK:       XFR (A),{{[A-Z]+}},2
// CHECK:       XFR (A),{{[A-Z]+}},4
// CHECK:       RSR
int sum3(int *p) { return p[0] + p[1] + p[2]; }

// The address of the local array is S itself, passed in A.
// CHECK-LABEL: {{^}}local_sum:
// CHECK:       ADD S,A,0
// CHECK:       JSR (sum3)
// CHECK:       RSR
int local_sum(int a, int b, int c) {
  int v[3];
  v[0] = a;
  v[1] = b;
  v[2] = c;
  return sum3(v);
}

// An indirect call jumps through the register that held the function pointer.
// CHECK-LABEL: {{^}}apply:
// CHECK:       JSR (C)
// CHECK:       RSR
int apply(int (*f)(int, int), int a, int b) { return f(a, b); }

// CHECK-LABEL: {{^}}slen:
// CHECK:       LDAB (A),0
// CHECK:       BZ
// CHECK:       INA
// CHECK:       RSR
int slen(const char *s) {
  int n = 0;
  while (*s) {
    n++;
    s++;
  }
  return n;
}

// CHECK-LABEL: {{^}}hello_len:
// CHECK-NEXT:  # %bb.0:
// CHECK-NEXT:  XFR A,msg
// CHECK-NEXT:  JSR (slen)
// CHECK-NEXT:  RSR
int hello_len(void) { return slen(msg); }

// CHECK-LABEL: {{^}}firstc:
// CHECK:       LDAB (msg)
// CHECK:       RSR
char firstc(void) { return msg[0]; }

// CHECK-LABEL: {{^}}copy5:
// CHECK:       LDAB (A),0
// CHECK:       STAB (B),0
// CHECK:       RSR
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

// CHECK-LABEL: {{^}}pair_sum:
// CHECK:       XFR (A),{{[A-Z]+}},0
// CHECK:       XFR (A),{{[A-Z]+}},2
// CHECK:       ADD
// CHECK:       RSR
int pair_sum(struct Pair *p) { return p->x + p->y; }

// The struct comes back through a pointer in a register. The two words are
// stored at displacements 0 and 2.
// CHECK-LABEL: {{^}}pair_make:
// CHECK:       STR A,(B),0
// CHECK:       STR A,(B),2
// CHECK:       RSR
struct Pair pair_make(int x, int y) {
  struct Pair p;
  p.x = x;
  p.y = y;
  return p;
}

// A struct argument is a pointer to the caller's object, in A.
// CHECK-LABEL: {{^}}pair_arg:
// CHECK-NEXT:  # %bb.0:
// CHECK-NEXT:  XFR (A),B,0
// CHECK-NEXT:  XFR (A),A,2
// CHECK-NEXT:  ADD B,A
// CHECK-NEXT:  RSR
int pair_arg(struct Pair p) { return p.x + p.y; }

struct Big {
  int a, b, c, d, e;
};

// The last int of a five-word struct is displacement 8.
// CHECK-LABEL: {{^}}big_last:
// CHECK:       XFR (A),{{[A-Z]+}},0
// CHECK:       XFR (A),{{[A-Z]+}},8
// CHECK:       RSR
int big_last(struct Big *p) { return p->a + p->e; }

// Globals are emitted after the functions.
// CHECK-LABEL: {{^}}msg:
// CHECK-NEXT:  .asciz "hello"
