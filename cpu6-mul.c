/* MUL probe. clang -target cpu6 -O0 -c cpu6-mul.c -o cpu6-mul.o
 *
 * Each letter is one multiply. The two hex fields are the even register
 * and the register after it: A then B, or X then Y. 1111 is a sentinel
 * loaded into the register that is not the multiplier's destination, so
 * an unchanged neighbor stays 1111.
 *
 * The sources disagree.
 *
 * EtchedPixels/Centurion cpu6.c mul16 writes only the low 16 bits of
 * dst * src into dst. The other register is left alone. That screen is:
 *
 *   A 0640 1111
 *   N 0640 1111
 *   B 1111 0640
 *   X 0640 1111
 *   Y 1111 0640
 *   P 0640 0028
 *   Q 0028 0640
 *   M FC90 0016
 *   I 0640 1111
 *   J 1111 0640
 *
 * Meisaka/webCenREE prints MUL's destination as a pair when that register
 * is A, X, Z, or C (A:B, X:Y, Z:S, C:P). Its @mul16 syscall stores the
 * high 16 bits in A and the low 16 bits in B, and the multiply is
 * unsigned. B, Y, S, and P are a single register and get the low 16.
 * That screen is:
 *
 *   A 0000 0640
 *   N FFB0 0640
 *   B 1111 0640
 *   X 0000 0640
 *   Y 1111 0640
 *   P 0000 0640
 *   Q 0028 0640
 *   M 0015 FC90
 *   I 0000 0640
 *   J 1111 0640
 *
 * S and C are the compiler's own multiply, not inline asm. Codegen puts
 * the i16 product in B or Y, so those lines are the low half: S is a*a
 * and C is a*b.
 *
 *   S 0640 0640
 *   C 0640 0640 FC90
 */
#define STAT (*(volatile unsigned char *)0xF200)
#define DATA (*(volatile unsigned char *)0xF201)

static volatile int v1;
static volatile int v2;
static volatile int sent;
static volatile int hi;
static volatile int lo;

static void putchar(int c) {
  while ((STAT & 2) == 0)
    ;
  DATA = (unsigned char)c;
}

static void puts(const char *s) {
  while (*s)
    putchar(*s++);
}

static void puthex(unsigned n) {
  static const char h[] = "0123456789ABCDEF";

  putchar(h[(n >> 12) & 15]);
  putchar(h[(n >> 8) & 15]);
  putchar(h[(n >> 4) & 15]);
  putchar(h[n & 15]);
}

static void nl(void) {
  putchar('\r');
  putchar('\n');
}

static void pair(const char *name) {
  puts(name);
  puthex(hi);
  putchar(' ');
  puthex(lo);
  nl();
}

/* MUL A,A. A is a pair start, so CenREE writes A:B. */
static void line_a(void) {
  v1 = 40;
  sent = 0x1111;
  __asm__ volatile(
      "XFR (v1),A\n\t"
      "XFR (sent),B\n\t"
      "MUL A,A\n\t"
      "STR A,(hi)\n\t"
      "XFR B,A\n\t"
      "STR A,(lo)");
  pair("A ");
}

/* MUL A,A of a negative. Unsigned 0xFFD8*0xFFD8 is 0xFFB00640. */
static void line_n(void) {
  v1 = -40;
  sent = 0x1111;
  __asm__ volatile(
      "XFR (v1),A\n\t"
      "XFR (sent),B\n\t"
      "MUL A,A\n\t"
      "STR A,(hi)\n\t"
      "XFR B,A\n\t"
      "STR A,(lo)");
  pair("N ");
}

/* MUL B,B. B is not a pair start. */
static void line_b(void) {
  v1 = 40;
  sent = 0x1111;
  __asm__ volatile(
      "XFR (sent),A\n\t"
      "XFR (v1),B\n\t"
      "MUL B,B\n\t"
      "STR A,(hi)\n\t"
      "XFR B,A\n\t"
      "STR A,(lo)");
  pair("B ");
}

/* MUL X,X. X is a pair start (X:Y). X holds the return address, so save it. */
static void line_x(void) {
  v1 = 40;
  sent = 0x1111;
  __asm__ volatile(
      "STK X,3\n\t"
      "XFR (v1),X\n\t"
      "XFR (sent),Y\n\t"
      "MUL X,X\n\t"
      "XFR X,A\n\t"
      "STR A,(hi)\n\t"
      "XFR Y,A\n\t"
      "STR A,(lo)\n\t"
      "POP X,3");
  pair("X ");
}

/* MUL Y,Y. Y is not a pair start. */
static void line_y(void) {
  v1 = 40;
  sent = 0x1111;
  __asm__ volatile(
      "STK X,3\n\t"
      "XFR (sent),X\n\t"
      "XFR (v1),Y\n\t"
      "MUL Y,Y\n\t"
      "XFR X,A\n\t"
      "STR A,(hi)\n\t"
      "XFR Y,A\n\t"
      "STR A,(lo)\n\t"
      "POP X,3");
  pair("Y ");
}

/* MUL B,A. Destination A, both registers start at 40. */
static void line_p(void) {
  v1 = 40;
  v2 = 40;
  __asm__ volatile(
      "XFR (v1),A\n\t"
      "XFR (v2),B\n\t"
      "MUL B,A\n\t"
      "STR A,(hi)\n\t"
      "XFR B,A\n\t"
      "STR A,(lo)");
  pair("P ");
}

/* MUL A,B. Destination B, both registers start at 40. */
static void line_q(void) {
  v1 = 40;
  v2 = 40;
  __asm__ volatile(
      "XFR (v1),A\n\t"
      "XFR (v2),B\n\t"
      "MUL A,B\n\t"
      "STR A,(hi)\n\t"
      "XFR B,A\n\t"
      "STR A,(lo)");
  pair("Q ");
}

/* MUL B,A of -40 and 22. Unsigned product is 0x0015FC90.
 * A signed 32-bit product would be 0xFFFFFC90. */
static void line_m(void) {
  v1 = -40;
  v2 = 22;
  __asm__ volatile(
      "XFR (v1),A\n\t"
      "XFR (v2),B\n\t"
      "MUL B,A\n\t"
      "STR A,(hi)\n\t"
      "XFR B,A\n\t"
      "STR A,(lo)");
  pair("M ");
}

/* Literal MUL A,A,40. Same pair question as the register form. */
static void line_i(void) {
  v1 = 40;
  sent = 0x1111;
  __asm__ volatile(
      "XFR (v1),A\n\t"
      "XFR (sent),B\n\t"
      "MUL A,A,40\n\t"
      "STR A,(hi)\n\t"
      "XFR B,A\n\t"
      "STR A,(lo)");
  pair("I ");
}

/* Literal MUL B,B,40. */
static void line_j(void) {
  v1 = 40;
  sent = 0x1111;
  __asm__ volatile(
      "XFR (sent),A\n\t"
      "XFR (v1),B\n\t"
      "MUL B,B,40\n\t"
      "STR A,(hi)\n\t"
      "XFR B,A\n\t"
      "STR A,(lo)");
  pair("J ");
}

static int sq(int a) { return a * a; }
static int mul(int a, int b) { return a * b; }

static void line_s(void) {
  puts("S ");
  v1 = 40;
  puthex(sq(v1));
  putchar(' ');
  v1 = -40;
  puthex(sq(v1));
  nl();
}

static void line_c(void) {
  puts("C ");
  v1 = 40;
  v2 = 40;
  puthex(mul(v1, v2));
  putchar(' ');
  v1 = -40;
  v2 = -40;
  puthex(mul(v1, v2));
  putchar(' ');
  v1 = -40;
  v2 = 22;
  puthex(mul(v1, v2));
  nl();
}

int main(void) {
  sent = 0x1111;
  putchar(0x0C);
  line_a();
  line_n();
  line_b();
  line_x();
  line_y();
  line_p();
  line_q();
  line_m();
  line_i();
  line_j();
  line_s();
  line_c();
  __asm__ volatile("HLT");
}
