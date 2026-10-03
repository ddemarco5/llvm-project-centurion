; A byte object that is still more than 127 bytes from the final S is a
; hardware limit. Both objects are byte accesses, so reordering keeps their
; relative order and the first one stays above the 200-byte array.
;
; RUN: not llc -mtriple=cpu6 -O0 2>&1 < %s | FileCheck %s

; CHECK: CPU6 byte frame access is out of displacement range
define void @still_far(i8 %c) nounwind {
  %a = alloca i8, align 1
  %pad = alloca [200 x i8], align 1
  store i8 %c, ptr %a
  store i8 %c, ptr %pad
  ret void
}
