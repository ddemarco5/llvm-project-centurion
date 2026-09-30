; Return the second argument. CC_CPU6 puts %a in A and %b in B, and
; RetCC_CPU6 puts the result in A. Those are different physical registers,
; so the coalescer cannot delete the copy the way it deletes `$ra = COPY $ra`
; in acc.ll. copyPhysReg turns that copy into XFR, printed source first:
; `XFR B,A` is A = B.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s

; CHECK-LABEL: ret_b:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: XFR B,A
; CHECK-NEXT: RSR
define i16 @ret_b(i16 %a, i16 %b) nounwind {
  ret i16 %b
}
