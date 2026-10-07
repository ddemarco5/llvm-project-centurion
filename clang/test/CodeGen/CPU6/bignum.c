// C source that selects the 0x46 bignum instructions. long is 32 bits, long
// long is 64 bits, and __int128 is 128 bits, so these use the 3,3, 7,7, and
// 15,15 length forms. The 4- and 8-byte forms were run on the machine
// (cent_stdlibs/bignum.c, bignum2.c, bnprobe.c), including negative values
// and the source at the destination.
//
// ZAD is a copy, BNA and BNS add and subtract, BNC compares, ZSU negates, M
// and D multiply and divide, and DRM divides and writes the remainder to the
// address in A. Dest is the left operand of BNA, BNS, M and D. DRM sends its
// quotient to a copy of the dividend, since a remainder written over the
// quotient's bytes picks up the quotient's sign fix. The comment on each
// function names the instruction it selects at -O2. Both optimization levels
// must still compile and pass the machine verifier.
//
// REQUIRES: cpu6-registered-target
// RUN: %clang -target cpu6 -ffreestanding -O0 -S -mllvm -verify-machineinstrs -o %t %s
// RUN: %clang -target cpu6 -ffreestanding -O2 -S -mllvm -verify-machineinstrs -o %t %s

_Static_assert(sizeof(long) == 4, "long is four bytes");
_Static_assert(sizeof(long long) == 8, "long long is eight bytes");
_Static_assert(sizeof(__int128) == 16, "__int128 is sixteen bytes");
_Static_assert(_Alignof(__int128) == 1, "__int128 alignment is one byte");

long g_a, g_b, g_r;
unsigned long u_a, u_b;
long long q_a, q_b, q_r;

// ---- 4-byte globals ----

void copy32(void) { g_b = g_a; }          // ZAD
void add32(void) { g_b = g_b + g_a; }     // BNA
void sub32(void) { g_b = g_b - g_a; }     // BNS
void neg32(void) { g_b = -g_a; }          // ZSU
void mul32(void) { g_b = g_b * g_a; }     // M
void div32(void) { g_b = g_b / g_a; }     // D

// The remainder is written where A points, and A is loaded after the copy.
void rem32(void) { g_r = g_a % g_b; }     // ZAD, then DRM

// BNC sets the flags of Dest - Src.
int ult32(void) { return u_a < u_b; }     // BNC
int eq32(void) { return g_a == g_b; }     // BNC

// ---- 4-byte, the source at the destination ----

void negself32(void) { g_a = -g_a; }      // ZSU
void square32(void) { g_a = g_a * g_a; }  // M

// ---- 4-byte through pointers ----

void neg32p(long *d, long *s) { *d = -*s; }       // ZSU
void mul32p(long *p, long *q) { *p = *p * *q; }   // M
void div32p(long *p, long *q) { *p = *p / *q; }   // D

// The pointer may be the same one: both operands name one register.
void negself32p(long *p) { *p = -*p; }            // ZSU
void square32p(long *p) { *p = *p * *p; }         // M

// The remainder may go over the divisor, so r and b may be one pointer.
void rem32p(long *r, long *a, long *b) { *r = *a % *b; }  // ZAD, then DRM

// ---- 8-byte globals ----

void copy64(void) { q_b = q_a; }          // ZAD
void add64(void) { q_b = q_b + q_a; }     // BNA
void sub64(void) { q_b = q_b - q_a; }     // BNS
void neg64(void) { q_b = -q_a; }          // ZSU
void mul64(void) { q_b = q_b * q_a; }     // M
void div64(void) { q_b = q_b / q_a; }     // D
void rem64(void) { q_r = q_a % q_b; }     // ZAD, then DRM

// ---- 8-byte, the source at the destination, and through pointers ----

void square64(void) { q_a = q_a * q_a; }                  // M
void mul64p(long long *p, long long *q) { *p = *p * *q; } // M

// Unsigned divide is not D. These must compile as library calls.
unsigned long long uq_a, uq_b, uq_r;
void udiv64(void) { uq_r = uq_a / uq_b; } // __udivdi3
void urem64(void) { uq_r = uq_a % uq_b; } // __umoddi3

// ---- 16-byte globals ----

__int128 t_a, t_b, t_r;
unsigned __int128 ut_a, ut_b;

void copy128(void) { t_b = t_a; }         // ZAD
void add128(void) { t_b = t_b + t_a; }    // BNA
void sub128(void) { t_b = t_b - t_a; }    // BNS
void neg128(void) { t_b = -t_a; }         // ZSU
void mul128(void) { t_b = t_b * t_a; }    // M
void div128(void) { t_b = t_b / t_a; }    // D
void rem128(void) { t_r = t_a % t_b; }    // ZAD, then DRM
int eq128(void) { return t_a == t_b; }    // BNC
int ult128(void) { return ut_a < ut_b; }  // BNC

// The result is the caller's sret memory, which is neither operand.
__int128 mul128_ret(__int128 *p, __int128 *q) { return *p * *q; } // ZAD, then M

// A third pointer. restrict makes the copy land in the destination.
void mul128_out(__int128 *restrict p, __int128 *restrict q,
                __int128 *restrict r) {
  *r = *p * *q; // ZAD, then M
}
