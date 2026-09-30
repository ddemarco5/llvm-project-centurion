; The smallest function the codegen pipeline can emit.
; Filling this in exercises, in the order llc reaches them:
;   CPU6RegisterInfo::getReservedRegs
;   CPU6TargetLowering::LowerReturn          (Outs is empty)
;   RSR's isReturn / isTerminator / isBarrier flags, and the CPU6retglue pattern
;   CPU6MCInstLower::lowerInstruction
;
; XFAIL until those are in place. Delete this line when llc prints RSR.
; XFAIL: *
; RUN: llc -mtriple=cpu6 -O0 < %s | FileCheck %s

; CHECK-LABEL: just_return:
; CHECK: RSR
define void @just_return() nounwind {
  ret void
}
