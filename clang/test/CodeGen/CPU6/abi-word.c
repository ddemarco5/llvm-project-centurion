// C calls on CPU6. int is 16 bits and the first four words arrive in A, B, Y, Z.
// A fifth word is stored at the caller's S, which the callee sees at incoming
// S + 2 because JSR has pushed X. DCR S,n is ADD S,S,-(n+1).
//
// REQUIRES: cpu6-registered-target
// RUN: %clang -target cpu6 -ffreestanding -O0 -S -mllvm -verify-machineinstrs -o - %s | FileCheck %s

_Static_assert(sizeof(int) == 2, "int is a word");
_Static_assert(sizeof(void *) == 2, "pointer is a word");

// CHECK-LABEL: {{^}}wadd:
// CHECK-NEXT:  # %bb.0:
// CHECK-NEXT:  DCR S,3
// CHECK-NEXT:  STR A,(S),2
// CHECK-NEXT:  STR B,(S),0
// CHECK-NEXT:  XFR (S),B,2
// CHECK-NEXT:  XFR (S),A,0
// CHECK-NEXT:  ADD B,A
// CHECK-NEXT:  INR S,3
// CHECK-NEXT:  RSR
int wadd(int a, int b) { return a + b; }

// The fifth and sixth words sit above the saved X. This frame is four words
// (DCR S,7 lowers S by 8), so those slots are (S),10 and (S),12.
// CHECK-LABEL: {{^}}take6:
// CHECK:       XFR (S),{{[A-Z]+}},12
// CHECK:       XFR (S),{{[A-Z]+}},10
// CHECK:       ADD
// CHECK:       RSR
int take6(int a, int b, int c, int d, int e, int f) { return a + f; }

// The caller writes the two stack words at (S),0 and (S),2, then JSR.
// CHECK-LABEL: {{^}}pass6:
// CHECK:       STR {{[A-Z]+}},(S),2
// CHECK:       STR {{[A-Z]+}},(S),0
// CHECK:       JSR (take6)
// CHECK:       RSR
int pass6(int a, int b, int c, int d, int e, int f) {
  return take6(a, b, c, d, e, f);
}

// A byte argument arrives in the low half of a word register. The result is
// zero-extended back to a word.
// CHECK-LABEL: {{^}}ubyte:
// CHECK:       STAB (S),0
// CHECK:       LDAB (S),0
// CHECK:       INA
// CHECK:       AND A,A,255
// CHECK:       RSR
unsigned char ubyte(unsigned char x) { return x + 1; }

// CHECK-LABEL: {{^}}sbyte:
// CHECK:       DCA
// CHECK:       AND A,A,255
// CHECK:       ORE A,A,128
// CHECK:       ADD A,A,-128
// CHECK:       RSR
signed char sbyte(signed char x) { return x - 1; }

// Unsigned compare is a subtract and BNL, with no sign-bit adjustment.
// CHECK-LABEL: {{^}}ucmp:
// CHECK:       SUB B,A
// CHECK:       BNL
// CHECK:       RSR
int ucmp(unsigned a, unsigned b) { return a < b; }

// A switch is a chain of compares. Nothing emits a jump table.
// CHECK-LABEL: {{^}}classify:
// CHECK:       BZ
// CHECK:       SUB A,A,1
// CHECK:       SUB A,A,7
// CHECK:       CLR A,10
// CHECK:       XFR A,20
// CHECK:       XFR A,30
// CHECK:       RSR
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
