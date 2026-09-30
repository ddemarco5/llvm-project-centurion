; Add an immediate to an argument. -O0 keeps the add from folding into the
; argument. After load-imm.ll works, this adds:
;   CC_CPU6 assigning the i16 argument to a register
;   CPU6TargetLowering::LowerFormalArguments
;   the ADDri codegen instruction and its (add GPR, imm) pattern
;
; An i32 add is the step after this. GPR is 16 bits, so the legalizer splits
; i32 into a pair of i16 operations (add plus carry) before selection runs.
;
; XFAIL until those are in place. Delete this line when the checks match.
; XFAIL: *
; RUN: llc -mtriple=cpu6 -O0 < %s | FileCheck %s

; CHECK-LABEL: acc:
; CHECK: ADD
; CHECK: RSR
define i16 @acc(i16 %a) nounwind {
  %v = add i16 %a, 1
  ret i16 %v
}
