; Two byte values live at a compare. A load result is any byte register:
; LDAB writes AL and LDBB writes BL, and XFRB covers the rest. CMPB prints
; as SUBB.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; The two loads use different accumulators. SUBB names both registers.
; CHECK-LABEL: cmp2:
; CHECK:    LDBB (A),0
; CHECK:    LDAB (A),1
; CHECK:    SUBB {{[A-Z]+}},{{[A-Z]+}}
; CHECK:    RSR
define i16 @cmp2(ptr %p) nounwind {
  %a = load i8, ptr %p
  %q = getelementptr i8, ptr %p, i16 1
  %b = load i8, ptr %q
  %c = icmp eq i8 %a, %b
  %z = zext i1 %c to i16
  ret i16 %z
}

; The byte is reloaded and compared with a constant. Both have to be in
; registers at the SUBB, so the reload cannot stay pinned to AL.
; CHECK-LABEL: eqh:
; CHECK:    SUBB
; CHECK:    RSR
define i16 @eqh(i8 %c) nounwind {
  %p = alloca i8, align 1
  store i8 %c, ptr %p
  %v = load i8, ptr %p
  %e = icmp eq i8 %v, 104
  %z = zext i1 %e to i16
  ret i16 %z
}
