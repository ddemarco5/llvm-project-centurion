; Return the second argument. CC_CPU6 puts %a in rA and %b in rB, and
; RetCC_CPU6 puts the result in rA. Those are different physical registers,
; so the coalescer cannot delete the copy the way it deletes `$rA = COPY $rA`
; in acc.ll. copyPhysReg has to turn that copy into XFR.
;
; A load from a global is the other way to read data this function did not
; compute, and it needs a load pattern before selection can reach the copy.
;
; XFAIL until copyPhysReg emits XFR. Delete this line when the checks match.
; XFAIL: *
; RUN: llc -mtriple=cpu6 -O0 < %s | FileCheck %s

; CHECK-LABEL: ret_b:
; CHECK: XFR B,A
; CHECK: RSR
define i16 @ret_b(i16 %a, i16 %b) nounwind {
  ret i16 %b
}
