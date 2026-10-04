; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; The carry of a multi-word add, and the borrow of a subtract, steps the high
; word with a branch around an INR or DCR. No 0 or 1 is made for it: those were
; two registers live across the compare, and one pair of them was shared by
; every carry in a block. A carry is Link clear after the compare (BNL), so the
; step is skipped with BL.

define i32 @add32(i32 %a, i32 %b) nounwind {
; CHECK-LABEL: add32:
; CHECK-NOT:   CLR
; CHECK:       BL [[SKIP:\.LBB[0-9_]+]]
; CHECK-NEXT:  .LBB
; CHECK-NEXT:  IN{{[A-Z]}}
; CHECK-NEXT:  [[SKIP]]:
; CHECK-NOT:   CLR
  %r = add i32 %a, %b
  ret i32 %r
}

define i32 @sub32(i32 %a, i32 %b) nounwind {
; CHECK-LABEL: sub32:
; CHECK-NOT:   CLR
; CHECK:       BL [[SKIP:\.LBB[0-9_]+]]
; CHECK-NEXT:  .LBB
; CHECK-NEXT:  DC{{[A-Z]}}
; CHECK-NEXT:  [[SKIP]]:
; CHECK-NOT:   CLR
  %r = sub i32 %a, %b
  ret i32 %r
}

; Two carries in one block shared one pair of constants. Each is a step now.
define i32 @add3(i32 %a, i32 %b, i32 %c) nounwind {
; CHECK-LABEL: add3:
; CHECK-NOT:   CLR
; CHECK:       BL [[SKIP1:\.LBB[0-9_]+]]
; CHECK-NEXT:  .LBB
; CHECK-NEXT:  IN{{[A-Z]}}
; CHECK-NEXT:  [[SKIP1]]:
; CHECK:       BL [[SKIP2:\.LBB[0-9_]+]]
; CHECK-NEXT:  .LBB
; CHECK-NEXT:  IN{{[A-Z]}}
; CHECK-NEXT:  [[SKIP2]]:
; CHECK-NOT:   CLR
  %s = add i32 %a, %b
  %t = add i32 %s, %c
  ret i32 %t
}
