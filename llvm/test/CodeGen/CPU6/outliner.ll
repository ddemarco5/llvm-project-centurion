; Machine outliner. A tail outline is JMP (3 bytes) and keeps the sequence's
; RSR. A call outline is JSR (3 bytes) plus an RSR in the outlined body.
; X and S may appear in a tail. A call outline rejects them, except the
; implicit S operands on JSR (the push, and the def call lowering leaves
; for the restored S). A (PC) displacement is from the next instruction.
; A lone RSR is one byte and does not pay for the JMP.
; At -O2 the pass runs only for minsize functions.
;
; RUN: llc -mtriple=cpu6 -enable-machine-outliner=always -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=cpu6 -verify-machineinstrs < %s | FileCheck %s --check-prefix=NOOUT

; NOOUT-NOT: OUTLINED_FUNCTION

declare void @eat(ptr)
declare void @take3(i16, i16, i16)
declare void @take3b(i16, i16, i16)
declare i16 @ext(i16, i16)
declare i16 @add2(i16, i16)
declare void @side()
declare void @other()

; Same 20-byte local and the same POP Y. The calls differ, so the repeated
; tail is ADD S, POP, RSR (7 bytes). Two copies save 1 byte.
; CHECK-LABEL: epi_a:
; CHECK: JSR (take3)
; CHECK-NEXT: JMP (OUTLINED_FUNCTION_1)
; CHECK-LABEL: epi_b:
; CHECK: JSR (take3b)
; CHECK-NEXT: JMP (OUTLINED_FUNCTION_1)
define void @epi_a() nounwind {
  %slot = alloca [10 x i16], align 1
  call void @eat(ptr %slot)
  call void @take3(i16 1, i16 2, i16 7)
  ret void
}

define void @epi_b() nounwind {
  %slot = alloca [10 x i16], align 1
  call void @eat(ptr %slot)
  call void @take3b(i16 1, i16 2, i16 9)
  ret void
}

; CLR B / XFR A / JSR is register-only. The incoming argument is parked in
; X around that sequence, so the STK X stays here and the outlined body
; does not read X. The arithmetic after the call differs, so RSR is the
; one the call outline appends.
; CHECK-LABEL: rep_a:
; CHECK: JSR (OUTLINED_FUNCTION_0)
; CHECK-NOT: JSR (ext)
; CHECK: ADD X,A
; CHECK-LABEL: rep_b:
; CHECK: JSR (OUTLINED_FUNCTION_0)
; CHECK-NOT: JSR (ext)
; CHECK: SUB A,X
define i16 @rep_a(i16 %x) nounwind {
  %r = call i16 @ext(i16 40, i16 2)
  %s = add i16 %r, %x
  ret i16 %s
}

define i16 @rep_b(i16 %x) nounwind {
  %r = call i16 @ext(i16 40, i16 2)
  %s = sub i16 %r, %x
  ret i16 %s
}

; Fifth and sixth words are (S). The repeated loads plus JSR would pay, and
; they do not end in RSR, so they stay in line.
; CHECK-LABEL: stk_a:
; CHECK: XFR (S),B,4
; CHECK-NEXT: XFR (S),A,2
; CHECK-NEXT: JSR (add2)
; CHECK-NEXT: INA
; CHECK-NEXT: RSR
; CHECK-LABEL: stk_b:
; CHECK: XFR (S),A,2
; CHECK-NEXT: JSR (add2)
; CHECK-NEXT: DCA
; CHECK-NEXT: RSR
define i16 @stk_a(i16 %a, i16 %b, i16 %c, i16 %d, i16 %e, i16 %f) nounwind {
  %r = call i16 @add2(i16 %e, i16 %f)
  %s = add i16 %r, 1
  ret i16 %s
}

define i16 @stk_b(i16 %a, i16 %b, i16 %c, i16 %d, i16 %e, i16 %f) nounwind {
  %r = call i16 @add2(i16 %e, i16 %f)
  %s = sub i16 %r, 1
  ret i16 %s
}

; Realigning keeps incoming S in X. The repeated XFR (X) plus JSR does not
; end in RSR, so it stays in line.
; CHECK-LABEL: x_a:
; CHECK: XFR (X),A,4
; CHECK-NEXT: STR A,(S),0
; CHECK: JSR (ext)
; CHECK-NEXT: INA
; CHECK-LABEL: x_b:
; CHECK: XFR (X),A,4
; CHECK: JSR (ext)
; CHECK-NEXT: DCA
define i16 @x_a(i16 %a, i16 %b, i16 %c, i16 %d, i16 %e) nounwind {
  %p = alloca i16, align 4
  store i16 %e, ptr %p
  %v = load i16, ptr %p
  %r = call i16 @ext(i16 %v, i16 0)
  %s = add i16 %r, 1
  ret i16 %s
}

define i16 @x_b(i16 %a, i16 %b, i16 %c, i16 %d, i16 %e) nounwind {
  %p = alloca i16, align 4
  store i16 %e, ptr %p
  %v = load i16, ptr %p
  %r = call i16 @ext(i16 %v, i16 0)
  %s = sub i16 %r, 1
  ret i16 %s
}

; The back-edge is JMP (PC). Its displacement is from the next instruction,
; so it is not moved into an outlined body.
; CHECK-LABEL: pc_a:
; CHECK: JSR (side)
; CHECK-NEXT: JMP (PC),
; CHECK-LABEL: pc_b:
; CHECK: JSR (side)
; CHECK-NEXT: JMP (PC),
define void @pc_a() nounwind {
entry:
  br label %loop
loop:
  call void @side()
  br label %loop
}

define void @pc_b() nounwind {
entry:
  br label %loop
loop:
  call void @side()
  br label %loop
}

; The only repeated instruction is RSR. One byte does not pay for a JMP.
; CHECK-LABEL: tiny_a:
; CHECK: JSR (side)
; CHECK-NEXT: RSR
; CHECK-LABEL: tiny_b:
; CHECK: JSR (other)
; CHECK-NEXT: RSR
define void @tiny_a() nounwind {
  call void @side()
  ret void
}

define void @tiny_b() nounwind {
  call void @other()
  ret void
}

; CHECK-LABEL: OUTLINED_FUNCTION_0:
; CHECK-NOT: (PC)
; CHECK: CLR B,2
; CHECK-NEXT: XFR A,40
; CHECK-NEXT: JSR (ext)
; CHECK-NEXT: RSR
; CHECK-LABEL: OUTLINED_FUNCTION_1:
; CHECK-NOT: (PC)
; CHECK: ADD S,S,20
; CHECK-NEXT: POP Y,1
; CHECK-NEXT: RSR
