; The smallest function the codegen pipeline can emit. LowerReturn sees an
; empty Outs and builds CPU6ISD::RET_GLUE, which the CPU6retglue pattern
; selects as RSR. No register is live out and no frame is set up.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s

; CHECK-LABEL: just_return:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: RSR
define void @just_return() nounwind {
  ret void
}
