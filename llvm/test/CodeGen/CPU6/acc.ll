; Add an immediate to an argument. CC_CPU6 assigns %a to A, and the
; (add GPR, imm) pattern selects ADDimm. The result is already in A, where
; RetCC_CPU6 wants it, so the coalescer removes the copy. The AsmPrinter then
; emits `ADD A,A,1` as INR A,0, which is the one-byte INA.
;
; An i32 add is the step after this. GPR is 16 bits, so the legalizer splits
; i32 into a pair of i16 operations (add plus carry) before selection runs.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s

; CHECK-LABEL: acc:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: INA
; CHECK-NEXT: RSR
define i16 @acc(i16 %a) nounwind {
  %v = add i16 %a, 1
  ret i16 %v
}
