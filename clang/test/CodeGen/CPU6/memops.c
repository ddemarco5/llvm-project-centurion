// Block memory ops from C: struct copy, memcpy/memset, a char buffer init,
// and alloca. FileCheck is an exception for this file; the other CPU6 C
// tests only check that they compile.
//
// memcpy and memset are not keywords. Under -ffreestanding Clang does not
// treat those names as builtins, so a call would be a real library call and
// there is no memcpy to link. __builtin_memcpy / __builtin_memset are the
// freestanding spellings; they lower to llvm.memcpy / llvm.memset, which
// the CPU6 backend expands inline.
//
// REQUIRES: cpu6-registered-target
// RUN: %clang -target cpu6 -ffreestanding -O0 -S -mllvm -verify-machineinstrs -o NUL %s
// RUN: %clang -target cpu6 -ffreestanding -O2 -S -mllvm -verify-machineinstrs -o - %s | FileCheck %s --check-prefix=O2
// RUN: %clang -target cpu6 -ffreestanding -Os -S -mllvm -verify-machineinstrs -o - %s | FileCheck %s --check-prefix=OS

_Static_assert(sizeof(int) == 2, "int is a word");
_Static_assert(sizeof(void *) == 2, "pointer is a word");

struct Block {
  char b[16];
};

// O2-LABEL: copy_block:
// O2: MVF
void copy_block(struct Block *d, const struct Block *s) { *d = *s; }

// O2-LABEL: cpy10:
// O2: MVF 9
void cpy10(void *d, const void *s) { __builtin_memcpy(d, s, 10); }

// O2-LABEL: cpyvar:
// O2: MVFR
void cpyvar(void *d, const void *s, unsigned n) { __builtin_memcpy(d, s, n); }

// OS-LABEL: cpyvar:
// OS: LDAB_I
// OS: STAB_I

// O2-LABEL: set10:
// O2: FIL
void set10(void *d) { __builtin_memset(d, 0, 10); }

// O2-LABEL: setvar:
// O2: STAB
// O2: MVFR
void setvar(void *d, int v, unsigned n) { __builtin_memset(d, v, n); }

void use(void *);

// Clang turns a small local memset into word stores. The check is that the
// slot is allocated and passed to use(), not that FIL is selected.
// O2-LABEL: buf_init:
// O2: DCR S
// O2: JSR (use)
void buf_init(void) {
  char buf[8];
  __builtin_memset(buf, 0, 8);
  use(buf);
}

// O2-LABEL: dyn:
// O2: XFR S,X
// O2: SUB S
// O2: XAS
void dyn(unsigned n) {
  char *p = __builtin_alloca(n);
  use(p);
}
