; Materialize a constant and return it. RetCC_CPU6 returns i16 in A, and the
; i16 immediate pattern selects XFRimm, printed as `XFR A,42`.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s

; CHECK-LABEL: load_imm:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: XFR A,42
; CHECK-NEXT: RSR
define i16 @load_imm() nounwind {
  ret i16 42
}
