// Constant block moves under register pressure. Each function keeps four
// integer arguments live across the memory operation and returns their sum,
// so A, B, Y, and Z compete with the address registers.
//
// Baseline, -O2, before absolute and indexed MVF/FIL selection.
// spills, reloads, instructions, (spills+reloads)/instructions.
// STK/POP and ADD S,S or DCR/INR S are frame traffic, not folded spills.
// inLoop is a block commented "in Loop". header is "Inner Loop Header".
//
// Improvement, instruction count should fall, spills must not rise:
//   copy_glob16        0  0   9   0.0%  STK 1 POP 1
//   copy_glob1k        0  0  18   0.0%  STK 1 POP 1
//   fill_glob32        0  0   6   0.0%
//   fill_glob1k        0  0  12   0.0%
//   copy_glob_to_ptr   0  0   9   0.0%  STK 1 POP 1
//   copy_ptr_to_glob   0  0   9   0.0%  STK 1 POP 1
//   copy_two_fields    0  0  11   0.0%  STK 1 POP 1
//   copy_one_field     0  0  10   0.0%  STK 1 POP 1
//   fill_field         0  0   7   0.0%
// fill_local and fill_far have FIL. The asm also names the object, so the
// address is not the fill's alone and the count is not required to fall.
// fill_far's filled slot is at offset 0. Frame adjustment is listed.
//   fill_local         0  0   8   0.0%  ADD S,S,-32 / ADD S,S,32
//   fill_far           0  0   8   0.0%  ADD S,S,-232 / ADD S,S,232
//
// Common flows, spills, reloads, and instructions must not rise:
//   copy_ptr2          0  0  10   0.0%  STK 1 POP 1   (word load/store)
//   copy_ptr16         0  0   9   0.0%  STK 1 POP 1
//   copy_ptr300        0  0  12   0.0%  STK 1 POP 1
//   copy_locals        0  0  11   0.0%  STK 1 POP 1  ADD S,S,-32 / ADD S,S,32
//   copy_reused        0  0  27   0.0%  STK 1 POP 1
//   copy_var           5  6  37  29.7%  STK 1 POP 1  DCR S,7 / INR S,7
//                      header 3 spills, 4 reloads, 14 instrs, 50.0%
//   fill_var           7  9  48  33.3%  STK 1 POP 1  DCR S,9 / INR S,9
//                      header 1 spill, 1 reload, 9 instrs, 22.2%
//   move_var           2  2  39  10.3%  STK 1 POP 1  DCR S,3 / INR S,3
//                      inLoop 0/0/6 0.0%   header 0/0/8 0.0%
//   move_down          0  0   9   0.0%  STK 1 POP 1
//   move_up            2  2  39  10.3%  STK 1 POP 1  DCR S,3 / INR S,3
//                      inLoop 0/0/6 0.0%   header 0/0/8 0.0%
//
// After. No spill or reload count rose. No common-flow instruction count rose.
//   copy_glob16        0  0   5   0.0%
//   copy_glob1k        0  0   8   0.0%
//   fill_glob32        0  0   5   0.0%
//   fill_glob1k        0  0   8   0.0%
//   copy_glob_to_ptr   0  0   6   0.0%
//   copy_ptr_to_glob   0  0   6   0.0%
//   copy_two_fields    0  0   9   0.0%  STK 1 POP 1
//   copy_one_field     0  0   9   0.0%  STK 1 POP 1
//   fill_field         0  0   6   0.0%
//   fill_local         0  0   7   0.0%  ADD S,S,-32 / ADD S,S,32
//   fill_far           0  0   7   0.0%  ADD S,S,-232 / ADD S,S,232
//   copy_ptr2          0  0  10   0.0%  STK 1 POP 1
//   copy_ptr16         0  0   9   0.0%  STK 1 POP 1
//   copy_ptr300        0  0  12   0.0%  STK 1 POP 1
//   copy_locals        0  0   8   0.0%  ADD S,S,-32 / ADD S,S,32
//   copy_reused        0  0  25   0.0%  STK 1 POP 1
//   copy_var           5  6  37  29.7%  STK 1 POP 1  DCR S,7 / INR S,7
//                      header 3 spills, 4 reloads, 14 instrs, 50.0%
//   fill_var           7  9  48  33.3%  STK 1 POP 1  DCR S,9 / INR S,9
//                      header 1 spill, 1 reload, 9 instrs, 22.2%
//   move_var           2  2  39  10.3%  STK 1 POP 1  DCR S,3 / INR S,3
//                      inLoop 0/0/6 0.0%   header 0/0/8 0.0%
//   move_down          0  0   6   0.0%
//   move_up            2  2  39  10.3%  STK 1 POP 1  DCR S,3 / INR S,3
//                      inLoop 0/0/6 0.0%   header 0/0/8 0.0%
//
// REQUIRES: cpu6-registered-target
// RUN: %clang -target cpu6 -ffreestanding -O0 -S -mllvm -verify-machineinstrs -o %t %s
// RUN: %clang -target cpu6 -ffreestanding -O2 -S -mllvm -verify-machineinstrs -o %t %s

_Static_assert(sizeof(int) == 2, "int is a word");
_Static_assert(sizeof(void *) == 2, "pointer is a word");

struct Block {
  char b[16];
};

char ga16[16], gb16[16];
char ga1k[1024], gb1k[1024];
char gfill32[32], gfill1k[1024];

// Improvement: addresses used only by the copy or fill.

int copy_glob16(int a, int b, int c, int d) {
  __builtin_memcpy(ga16, gb16, 16);
  return a + b + c + d;
}

int copy_glob1k(int a, int b, int c, int d) {
  __builtin_memcpy(ga1k, gb1k, 1024);
  return a + b + c + d;
}

int fill_glob32(int a, int b, int c, int d) {
  __builtin_memset(gfill32, 0, 32);
  return a + b + c + d;
}

int fill_glob1k(int a, int b, int c, int d) {
  __builtin_memset(gfill1k, 0, 1024);
  return a + b + c + d;
}

int copy_glob_to_ptr(int a, int b, int c, int d, void *p) {
  __builtin_memcpy(p, gb16, 16);
  return a + b + c + d;
}

int copy_ptr_to_glob(int a, int b, int c, int d, const void *p) {
  __builtin_memcpy(ga16, p, 16);
  return a + b + c + d;
}

int copy_two_fields(int a, int b, int c, int d, char *p, const char *q) {
  __builtin_memcpy(p + 4, q + 8, 16);
  return a + b + c + d;
}

int copy_one_field(int a, int b, int c, int d, char *p, const char *q) {
  __builtin_memcpy(p + 4, q, 16);
  return a + b + c + d;
}

int fill_field(int a, int b, int c, int d, char *p) {
  __builtin_memset(p + 4, 0, 16);
  return a + b + c + d;
}

int fill_local(int a, int b, int c, int d) {
  char buf[32];
  __builtin_memset(buf, 0, 32);
  // Name the buffer so the fill is not deleted. This is a second use of the
  // address, so the fold is not required to shorten this function.
  __asm__ volatile("" : "+m"(buf));
  return a + b + c + d;
}

int fill_far(int a, int b, int c, int d) {
  char pad[200];
  char buf[32];
  __builtin_memset(buf, 0, 32);
  __asm__ volatile("" : "+m"(buf), "+m"(pad));
  return a + b + c + d;
}

// Common flows. These stay on the register forms.

int copy_ptr2(int a, int b, int c, int d, void *dst, const void *src) {
  __builtin_memcpy(dst, src, 2);
  return a + b + c + d;
}

int copy_ptr16(int a, int b, int c, int d, void *dst, const void *src) {
  __builtin_memcpy(dst, src, 16);
  return a + b + c + d;
}

int copy_ptr300(int a, int b, int c, int d, void *dst, const void *src) {
  __builtin_memcpy(dst, src, 300);
  return a + b + c + d;
}

int copy_locals(int a, int b, int c, int d) {
  struct Block x, y;
  // Both slots are read and written by the asm, and the assignment copies
  // one into the other. The bytes are not constants the compiler can fold.
  __asm__ volatile("" : "+m"(y));
  x = y;
  __asm__ volatile("" : "+m"(x));
  return a + b + c + d;
}

int copy_reused(int a, int b, int c, int d) {
  __builtin_memcpy(ga16, gb16, 16);
  return ga16[0] + gb16[0] + a + b + c + d;
}

int copy_var(int a, int b, int c, int d, void *dst, const void *src,
             unsigned n) {
  __builtin_memcpy(dst, src, n);
  return a + b + c + d;
}

int fill_var(int a, int b, int c, int d, void *dst, int v, unsigned n) {
  __builtin_memset(dst, v, n);
  return a + b + c + d;
}

int move_var(int a, int b, int c, int d, void *dst, const void *src,
             unsigned n) {
  __builtin_memmove(dst, src, n);
  return a + b + c + d;
}

int move_down(int a, int b, int c, int d, char *p) {
  __builtin_memmove(p, p + 4, 20);
  return a + b + c + d;
}

int move_up(int a, int b, int c, int d, char *p) {
  __builtin_memmove(p + 4, p, 20);
  return a + b + c + d;
}
