; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; No count-leading-zeros opcode. A zero input is the width. Anything else is
; shifts and adds, not a call to __clzsi2.
; CHECK-LABEL: clz16:
; CHECK-NOT: JSR
; CHECK: XFR A,16
; CHECK: RSR
define i16 @clz16(i16 %a) {
  %v = call i16 @llvm.ctlz.i16(i16 %a, i1 false)
  ret i16 %v
}

; A variable i32 shift is two i16 halves. The bits that cross the boundary
; rotate through Link, not a call to __ashlsi3.
; CHECK-LABEL: shl32v:
; CHECK-NOT: JSR
; CHECK: RL
; CHECK: RLR
; CHECK: RSR
define i32 @shl32v(i32 %a, i32 %n) {
  %v = shl i32 %a, %n
  ret i32 %v
}

; An i64 product of two registers is M. It does not fit in A:B, and it is
; not a call to __muldi3.
; CHECK-LABEL: mul64:
; CHECK-NOT: JSR
; CHECK: M 7,7,
; CHECK: RSR
define void @mul64(i64 %a, i64 %b, ptr %p) {
  %r = mul i64 %a, %b
  store i64 %r, ptr %p, align 1
  ret void
}

declare i16 @llvm.ctlz.i16(i16, i1)
