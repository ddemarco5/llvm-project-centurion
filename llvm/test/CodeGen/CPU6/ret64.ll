; An i64 is four words, high to low in A, B, Y, Z. Y and Z are callee-saved.
; A function that returns in them does not pop them: the pop sits in front of
; RSR and would replace the result. A call that returns an i64 clobbers Y and
; Z, so a value live across that call moves to a preserved register. A function
; that does not return an i64 still restores Y and Z.
;
; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; Already in A, B, Y, Z. Nothing to save and nothing to pop.
; CHECK-LABEL: passthru:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: RSR
define i64 @passthru(i64 %a) nounwind {
  ret i64 %a
}

; %c arrives in Y. The call returns in Y and Z, so Y is copied to X, which the
; call preserves, and the epilogue still hands Y and Z back.
; CHECK-LABEL: keep:
; CHECK: STK X,5
; CHECK: XFR Y,X
; CHECK: JSR (passthru)
; CHECK: XFR X,A
; CHECK: POP X,5
; CHECK: RSR
define i16 @keep(i16 %a, i16 %b, i16 %c) nounwind {
  call i64 @passthru(i64 0)
  ret i16 %c
}

; The low word is Z. The carry chain writes Y, B, and A, and only X is popped.
; CHECK-LABEL: add1:
; CHECK: STK X,1
; CHECK: INR Z,0
; CHECK: POP X,1
; CHECK-NEXT: RSR
define i64 @add1(i64 %a) nounwind {
  %r = add i64 %a, 1
  ret i64 %r
}
