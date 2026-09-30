; Materialize a constant and return it.
; After ret-void.ll works, this adds:
;   RetCC_CPU6 assigning i16 to a register (rA is the suggestion)
;   the LI16 codegen instruction and its pattern in CPU6InstrPatterns.td
;   CPU6InstrInfo::copyPhysReg, if the coalescer cannot fold the copy away
;
; XFAIL until those are in place. Delete this line when the checks match.
; XFAIL: *
; RUN: llc -mtriple=cpu6 -O0 < %s | FileCheck %s

; CHECK-LABEL: load_imm:
; CHECK: XFR A,42
; CHECK: RSR
define i16 @load_imm() nounwind {
  ret i16 42
}
