// float is 32 bits (two words) and there is no FPU. Each arithmetic
// operation, compare, and conversion is a compiler-rt libcall (__addsf3
// and the rest). A returned float is an i32 in A:B. The check is that -O0
// and -O2 both compile.
//
// REQUIRES: cpu6-registered-target
// RUN: %clang -target cpu6 -ffreestanding -O0 -S -mllvm -verify-machineinstrs -o %t %s
// RUN: %clang -target cpu6 -ffreestanding -O2 -S -mllvm -verify-machineinstrs -o %t %s

_Static_assert(sizeof(float) == 4, "float is two words");

float fadd(float a, float b) { return a + b; }

float fsub(float a, float b) { return a - b; }

float fmul(float a, float b) { return a * b; }

float fdiv(float a, float b) { return a / b; }

float fneg(float a) { return -a; }

int flt(float a, float b) { return a < b; }

int feq(float a, float b) { return a == b; }

int ftoi(float a) { return (int)a; }

float itof(int a) { return (float)a; }

float fmix(float a, float b, float c) { return a * b + c; }
