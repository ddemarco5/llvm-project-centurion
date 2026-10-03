// long is 32 bits (two words) and long long is 64 bits (four). Words are
// big-endian: the high word of a long is A and the low word is B. A second
// long takes Y and Z the same way. A long long fills A, B, Y, and Z from
// high to low. RetCC_CPU6 only has A and B, so a function here never returns
// a long long; it returns the low word or a compare result. Cases codegen
// rejects are commented out below with TODOs.
//
// REQUIRES: cpu6-registered-target
// RUN: %clang -target cpu6 -ffreestanding -O0 -S -mllvm -verify-machineinstrs -o - %s | FileCheck %s

_Static_assert(sizeof(long) == 4, "long is two words");
_Static_assert(sizeof(long long) == 8, "long long is four words");

// Both halves are ANDed. The high half is returned in A and the low half in B.
// CHECK-LABEL: {{^}}land:
// CHECK:       STR B,(S),6
// CHECK:       STR A,(S),4
// CHECK:       STR Z,(S),2
// CHECK:       STR Y,(S),0
// CHECK:       AND
// CHECK:       AND
// CHECK:       RSR
long land(long a, long b) { return a & b; }

// CHECK-LABEL: {{^}}ladd:
// CHECK:       AAB
// CHECK:       RSR
long ladd(long a, long b) { return a + b; }

// TODO(cpu6): a variable shift of a long. The type legalizer emits shl_parts,
// srl_parts, or sra_parts and nothing selects them ("Cannot select").
// long lshl(long a, int n) { return a << n; }
// unsigned long lshr(unsigned long a, int n) { return a >> n; }
// long lsar(long a, int n) { return a >> n; }

// TODO(cpu6): long multiply. Expansion wants umul_lohi, which nothing selects
// ("Cannot select").
// long lmul(long a, long b) { return a * b; }

// TODO(cpu6): long divide and remainder. These become a compiler-rt call and
// the backend reports "unsupported library call operation".
// long ldiv(long a, long b) { return a / b; }
// long lmod(long a, long b) { return a % b; }

// Signed less-than flips the sign bit of each high half, then subtracts.
// CHECK-LABEL: {{^}}lcmp:
// CHECK:       ORE A,A,-32768
// CHECK:       ORE B,B,-32768
// CHECK:       RSR
int lcmp(long a, long b) { return a < b; }

// CHECK-LABEL: {{^}}lucmp:
// CHECK:       SUB
// CHECK:       BNL
// CHECK-NOT:   ORE {{.*}},-32768
// CHECK:       RSR
int lucmp(unsigned long a, unsigned long b) { return a < b; }

// The first long takes A and B, the unsigned int takes Y, and the second long
// takes Z plus one stack word. That low word is reloaded from (S),32.
// CHECK-LABEL: {{^}}lmixu:
// CHECK:       XFR (S),{{[A-Z]+}},32
// CHECK:       AAB
// CHECK:       RSR
unsigned long lmixu(unsigned long a, unsigned b, unsigned long c) {
  return a + b + c;
}

// The four words of a long long are spilled high to low at (S)+0, +2, +4, +6,
// which is A, B, Y, Z. The low word is Z, and that is what a cast to int returns.
// CHECK-LABEL: {{^}}qlow:
// CHECK-NEXT:  # %bb.0:
// CHECK-NEXT:  DCR S,7
// CHECK-NEXT:  STR Z,(S),6
// CHECK-NEXT:  STR Y,(S),4
// CHECK-NEXT:  STR B,(S),2
// CHECK-NEXT:  STR A,(S),0
// CHECK-NEXT:  XFR (S),A,6
// CHECK-NEXT:  INR S,7
// CHECK-NEXT:  RSR
int qlow(long long a) { return (int)a; }

// Bits 16..31 are the word that arrived in Y.
// CHECK-LABEL: {{^}}qhi:
// CHECK-NEXT:  # %bb.0:
// CHECK-NEXT:  DCR S,7
// CHECK-NEXT:  STR Z,(S),6
// CHECK-NEXT:  STR Y,(S),4
// CHECK-NEXT:  STR B,(S),2
// CHECK-NEXT:  STR A,(S),0
// CHECK-NEXT:  XFR (S),A,4
// CHECK-NEXT:  INR S,7
// CHECK-NEXT:  RSR
int qhi(long long a) { return (int)(a >> 16); }

// A second long long does not fit in registers. Its four words are read back
// from the stack.
// CHECK-LABEL: {{^}}qeq:
// CHECK:       XFR (S),{{[A-Z]+}},46
// CHECK:       XFR (S),{{[A-Z]+}},44
// CHECK:       XFR (S),{{[A-Z]+}},42
// CHECK:       XFR (S),{{[A-Z]+}},40
// CHECK:       ORE
// CHECK:       RSR
int qeq(long long a, long long b) { return a == b; }

// CHECK-LABEL: {{^}}qcmp:
// CHECK:       ORE A,A,-32768
// CHECK:       ORE B,B,-32768
// CHECK:       RSR
int qcmp(long long a, long long b) { return a < b; }

// CHECK-LABEL: {{^}}qand:
// CHECK:       AND
// CHECK:       RSR
int qand(long long a, long long b) { return (int)(a & b); }

// long long, int, long long: the int and the second long long are on the stack.
// Only the low word of the sum is returned.
// CHECK-LABEL: {{^}}qmix:
// CHECK:       XFR (S),{{[A-Z]+}},38
// CHECK:       XFR (S),{{[A-Z]+}},30
// CHECK:       AAB
// CHECK:       RSR
int qmix(long long a, int b, long long c) { return (int)(a + b + c); }

// TODO(cpu6): returning a long long. An i64 is four words and RetCC_CPU6 only
// assigns A and B, so lowering reports "unable to allocate function return #2".
// The same return path rejects a widening cast to long long.
// long long qadd(long long a, long long b) { return a + b; }
// long long qzext(unsigned int a) { return a; }
// long long qsext(int a) { return a; }

// TODO(cpu6): float arithmetic. Soft-float lowering emits a compiler-rt call
// and the backend reports "unsupported library call operation".
// float fadd(float a, float b) { return a + b; }

// TODO(cpu6): double arithmetic. A double is four words, so the return is
// rejected with "unable to allocate function return #2" before the soft-float
// helper would be called.
// double dadd(double a, double b) { return a + b; }
