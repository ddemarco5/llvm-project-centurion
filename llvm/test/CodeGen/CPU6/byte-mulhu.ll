; i8 mulhu is bits [15:8] of the zero-extended product. MUL is the word
; opcode, and SRR with count 7 shifts by 8. The sign bits that shift writes
; above the result byte are dropped.
;
; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; CHECK-LABEL: mulhu_rr:
; CHECK:    MUL
; CHECK:    SRR {{[A-Z]}},7
; CHECK:    RSR
define i8 @mulhu_rr(i8 %a, i8 %b) nounwind {
  %za = zext i8 %a to i16
  %zb = zext i8 %b to i16
  %p = mul i16 %za, %zb
  %s = lshr i16 %p, 8
  %r = trunc i16 %s to i8
  ret i8 %r
}

; Remainder by 10 is the fractal's -O2 narrowing. The magic multiply is an
; i8 mulhu by 0xCD, printed as the signed constant -51 before this lowering.
; CHECK-LABEL: rem10:
; CHECK:    MUL
; CHECK:    SRR {{[A-Z]}},7
; CHECK:    RSR
define i8 @rem10(i8 %n) nounwind {
  %r = urem i8 %n, 10
  ret i8 %r
}
