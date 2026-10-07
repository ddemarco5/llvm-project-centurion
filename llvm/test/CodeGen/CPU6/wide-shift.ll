; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; A variable shift of an i32, i64, or i128 is one loop over the words. Whole
; words move with a copy, and the leftover bits rotate through Link. A
; constant count stays an immediate SLR or SRR. There is no 0x46 shift.

@g64 = global i64 0

; CHECK-LABEL: vshl:
; CHECK:      RL
; CHECK:      RLR
; CHECK:      RLR
; CHECK:      RSR
define i32 @vshl(i32 %a, i32 %n) nounwind {
  %s = shl i32 %a, %n
  ret i32 %s
}

; CHECK-LABEL: vlshr:
; CHECK:      RL
; CHECK:      RRR
; CHECK:      RRR
; CHECK:      RSR
define i32 @vlshr(i32 %a, i32 %n) nounwind {
  %s = lshr i32 %a, %n
  ret i32 %s
}

; The high word sign-fills. The low word takes the bit SRR put in Link.
; CHECK-LABEL: vashr:
; CHECK:      SRR
; CHECK:      RRR
; CHECK:      RSR
define i32 @vashr(i32 %a, i32 %n) nounwind {
  %s = ashr i32 %a, %n
  ret i32 %s
}

; CHECK-LABEL: cshl:
; CHECK-NOT:  RLR
; CHECK:      SLR
; CHECK:      RSR
define i32 @cshl(i32 %a) nounwind {
  %s = shl i32 %a, 4
  ret i32 %s
}

; Four words, low first, so the bit loop rotates each of them.
; CHECK-LABEL: vshl64:
; CHECK:      RL
; CHECK:      RLR
; CHECK:      RLR
; CHECK:      RLR
; CHECK:      RLR
; CHECK:      RSR
define void @vshl64(i64 %a, i64 %n) nounwind {
  %s = shl i64 %a, %n
  store i64 %s, ptr @g64, align 1
  ret void
}

; Eight words. A variable count must not become __ashlti3.
; CHECK-LABEL: vshl128:
; CHECK-NOT:  JSR
; CHECK:      RL
; CHECK:      RLR
; CHECK:      RLR
; CHECK:      RLR
; CHECK:      RLR
; CHECK:      RLR
; CHECK:      RLR
; CHECK:      RLR
; CHECK:      RLR
; CHECK:      RSR
@g128 = global i128 0
define void @vshl128(i128 %a, i128 %n) nounwind {
  %s = shl i128 %a, %n
  store i128 %s, ptr @g128, align 1
  ret void
}
