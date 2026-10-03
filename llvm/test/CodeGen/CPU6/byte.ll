; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; i8 lives in the byte halves (GPRB). A byte argument arrives widened in its
; word register and a byte result goes back in A, so AL and BL are the low
; bytes of the first two arguments.

; Byte register/register ALU is two-address: the destination nibble is read
; and written. ADDB src,dst is dst += src. ADDB is commutable, so the sum is
; built in AL, where the result goes, and no copy follows.
; CHECK-LABEL: add_rr:
; CHECK:      ADDB BL,AL
; CHECK-NEXT: RSR
define i8 @add_rr(i8 %a, i8 %b) {
  %v = add i8 %a, %b
  ret i8 %v
}

; SUBB src,dst is dst = src - dst, so a - b leaves the result in b's byte.
; SUBB AL,BL is printed as the one-byte SABB (see compress.mir).
; CHECK-LABEL: sub_rr:
; CHECK:      SABB
; CHECK-NEXT: XFR B,A
; CHECK-NEXT: RSR
define i8 @sub_rr(i8 %a, i8 %b) {
  %v = sub i8 %a, %b
  ret i8 %v
}

; INRB/DCRB r,n add or subtract n + 1, so 1-16 fit in the count nibble.
; CHECK-LABEL: inc1:
; CHECK:      INAB
; CHECK-NEXT: RSR
define i8 @inc1(i8 %a) {
  %v = add i8 %a, 1
  ret i8 %v
}

; CHECK-LABEL: inc16:
; CHECK:      INRB AL,15
; CHECK-NEXT: RSR
define i8 @inc16(i8 %a) {
  %v = add i8 %a, 16
  ret i8 %v
}

; CHECK-LABEL: dec3:
; CHECK:      DCRB AL,2
; CHECK-NEXT: RSR
define i8 @dec3(i8 %a) {
  %v = sub i8 %a, 3
  ret i8 %v
}

; Past 16 the word literal ADD on the containing register is used; only the
; low byte of the result matters.
; CHECK-LABEL: add17:
; CHECK:      ADD A,A,17
; CHECK-NEXT: RSR
define i8 @add17(i8 %a) {
  %v = add i8 %a, 17
  ret i8 %v
}

; SUB's literal form is dst = imm - src.
; CHECK-LABEL: rsub:
; CHECK:      SUB A,A,10
; CHECK-NEXT: RSR
define i8 @rsub(i8 %a) {
  %v = sub i8 10, %a
  ret i8 %v
}

; CHECK-LABEL: not:
; CHECK:      IVAB
; CHECK-NEXT: RSR
define i8 @not(i8 %a) {
  %v = xor i8 %a, -1
  ret i8 %v
}

; SLRB r,n shifts left by n + 1.
; CHECK-LABEL: shl3:
; CHECK:      SLRB AL,2
; CHECK-NEXT: RSR
define i8 @shl3(i8 %a) {
  %v = shl i8 %a, 3
  ret i8 %v
}

; SRRB r,n is an arithmetic shift right by n + 1.
; CHECK-LABEL: ashr3:
; CHECK:      SRRB AL,2
; CHECK-NEXT: RSR
define i8 @ashr3(i8 %a) {
  %v = ashr i8 %a, 3
  ret i8 %v
}

; Same sign-fill correction as a word, in the low byte. 31 is 0x1f.
; CHECK-LABEL: lshr3:
; CHECK:      SRRB AL,2
; CHECK:      AND {{.*}},31
; CHECK:      RSR
define i8 @lshr3(i8 %a) {
  %v = lshr i8 %a, 3
  ret i8 %v
}

; SLAB is SLRB AL,0. The count is widened to a word, so the decrement is DCR.
; CHECK-LABEL: shl_var:
; CHECK:      BZ
; CHECK:      {{SLAB|SLRB}}
; CHECK:      {{DCA|DCR}}
; CHECK:      BNZ
; CHECK:      RSR
define i8 @shl_var(i8 %a, i8 %n) {
  %v = shl i8 %a, %n
  ret i8 %v
}

; CHECK-LABEL: ashr_var:
; CHECK:      BZ
; CHECK:      {{SRAB|SRRB}}
; CHECK:      {{DCA|DCR}}
; CHECK:      BNZ
; CHECK:      RSR
define i8 @ashr_var(i8 %a, i8 %n) {
  %v = ashr i8 %a, %n
  ret i8 %v
}

; Each step clears Link and rotates the byte right by one, shifting in a zero.
; CHECK-LABEL: lshr_var:
; CHECK:      BZ
; CHECK:      RL
; CHECK:      RRRB
; CHECK:      {{DCA|DCR}}
; CHECK:      BNZ
; CHECK:      RSR
define i8 @lshr_var(i8 %a, i8 %n) {
  %v = lshr i8 %a, %n
  ret i8 %v
}

; CLRB r,n writes n (0-15); a byte store goes through AL with STAB.
; CHECK-LABEL: store5:
; CHECK:      DCR S,0
; CHECK-NEXT: CLRB AL,5
; CHECK-NEXT: STAB (S),0
; CHECK-NEXT: INR S,0
; CHECK-NEXT: RSR
define void @store5() {
  %p = alloca i8
  store volatile i8 5, ptr %p
  ret void
}

; A truncating store is a truncate (the low byte, AL) plus STAB.
; CHECK-LABEL: trunc_store:
; CHECK:      DCR S,0
; CHECK:      STAB (S),0
; CHECK-NEXT: INR S,0
; CHECK-NEXT: RSR
define void @trunc_store(i16 %a) {
  %p = alloca i8
  %t = trunc i16 %a to i8
  store volatile i8 %t, ptr %p
  ret void
}

; An extending load is LDAB into AL plus an extension of A. zext clears the
; upper half; sext is ((x & 0xff) ^ 0x80) - 0x80.
; CHECK-LABEL: zext_load:
; CHECK:      DCR S,0
; CHECK:      STAB (S),0
; CHECK-NEXT: LDAB (S),0
; CHECK:      AND A,A,255
; CHECK-NEXT: INR S,0
; CHECK-NEXT: RSR
define i16 @zext_load(i8 %a) {
  %p = alloca i8
  store volatile i8 %a, ptr %p
  %v = load volatile i8, ptr %p
  %z = zext i8 %v to i16
  ret i16 %z
}

; CHECK-LABEL: sext_load:
; CHECK:      DCR S,0
; CHECK:      STAB (S),0
; CHECK-NEXT: LDAB (S),0
; CHECK:      AND A,A,255
; CHECK-NEXT: ORE A,A,128
; CHECK-NEXT: ADD A,A,-128
; CHECK-NEXT: INR S,0
; CHECK-NEXT: RSR
define i16 @sext_load(i8 %a) {
  %p = alloca i8
  store volatile i8 %a, ptr %p
  %v = load volatile i8, ptr %p
  %z = sext i8 %v to i16
  ret i16 %z
}

; zeroext on the result: the callee clears the upper half of A.
; CHECK-LABEL: zext_ret:
; CHECK:      AND A,A,255
; CHECK-NEXT: RSR
define zeroext i8 @zext_ret(i8 %a) {
  ret i8 %a
}

; signext on the argument: the caller already extended A.
; CHECK-LABEL: sext_arg:
; CHECK-NOT:  AND
; CHECK:      RSR
define i16 @sext_arg(i8 signext %a) {
  %z = sext i8 %a to i16
  ret i16 %z
}
