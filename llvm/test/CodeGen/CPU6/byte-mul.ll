; There is no byte multiply. MUL is the word opcode 0x77, and 0x67 is the
; block-memory group. An i8 product is promoted to i16; the low byte of that
; MUL is the result. The constant 10 is the -O2 narrowing of a remainder by
; a byte divisor.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; CHECK-LABEL: mulb:
; CHECK:    MUL
; CHECK:    RSR
define i8 @mulb(i8 %a, i8 %b) nounwind {
  %v = mul i8 %a, %b
  ret i8 %v
}

; CHECK-LABEL: mulb10:
; CHECK:    MUL {{[A-Z]}},{{[A-Z]}},10
; CHECK:    RSR
define i8 @mulb10(i8 %a) nounwind {
  %v = mul i8 %a, 10
  ret i8 %v
}
