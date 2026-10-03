; DIV is an unsigned word quotient. There is no byte divide and no
; remainder opcode.
;
; An i8 quotient or remainder is promoted to i16. That promotion does not
; emit the remainder: an i8 urem becomes an i16 urem. i16 urem is Expand,
; and expandREM rewrites it as udiv, mul, and sub because i16 udiv is DIV.
; Signed i16 quotient and remainder are custom-lowered onto the same DIV.
; The magnitude is an unsigned negate, so the sign bit still fits.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; CHECK-LABEL: urem16:
; CHECK:    DIV
; CHECK:    MUL
; CHECK:    RSR
define i16 @urem16(i16 %n, i16 %d) nounwind {
  %r = urem i16 %n, %d
  ret i16 %r
}

; CHECK-LABEL: urem8:
; CHECK:    DIV
; CHECK:    MUL
; CHECK:    RSR
define i8 @urem8(i8 %n, i8 %d) nounwind {
  %r = urem i8 %n, %d
  ret i8 %r
}

; CHECK-LABEL: srem16:
; CHECK:    DIV
; CHECK:    MUL
; CHECK:    RSR
define i16 @srem16(i16 %n, i16 %d) nounwind {
  %r = srem i16 %n, %d
  ret i16 %r
}

; CHECK-LABEL: sdiv16:
; CHECK:    DIV
; CHECK:    RSR
define i16 @sdiv16(i16 %n, i16 %d) nounwind {
  %q = sdiv i16 %n, %d
  ret i16 %q
}

; CHECK-LABEL: udiv8:
; CHECK:    DIV
; CHECK:    RSR
define i8 @udiv8(i8 %n, i8 %d) nounwind {
  %q = udiv i8 %n, %d
  ret i8 %q
}
