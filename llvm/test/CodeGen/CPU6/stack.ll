; Frame layout for allocas. The stack grows down. A slot's displacement is its
; offset from the incoming S, plus the frame size, which is its distance from
; S after the prologue has lowered S by that frame size. The epilogue raises
; S by the same amount.
;
; The stack alignment is one byte, so S has no alignment of its own. A slot
; aligned above that makes the prologue save X, copy S into it, lower S, and
; round S down with AND. The epilogue restores S from X, not with a constant,
; because the rounding depends on S at run time.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s

; No slot, so S is not moved.
; CHECK-LABEL: none:
; CHECK-NOT: ADD
; CHECK-NOT: STA
; CHECK: RSR
define i16 @none(i16 %a) nounwind {
  ret i16 %a
}

; No align directive. The alloca takes the i16 ABI alignment from the data
; layout (i16:8, one byte), so it matches align1 and does not realign S.
; CHECK-LABEL: noalign:
; CHECK-NOT: STK
; CHECK: DCR S,1
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: INR S,1
; CHECK-NEXT: RSR
define i16 @noalign(i16 %a) nounwind {
  %p = alloca i16
  store i16 %a, ptr %p
  %v = load i16, ptr %p
  ret i16 %v
}

; Two bytes, alignment 1. Frame size 2, slot at the final S.
; CHECK-LABEL: align1:
; CHECK-NOT: STK
; CHECK: DCR S,1
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: INR S,1
; CHECK-NEXT: RSR
define i16 @align1(i16 %a) nounwind {
  %p = alloca i16, align 1
  store i16 %a, ptr %p
  %v = load i16, ptr %p
  ret i16 %v
}

; Alignment 2 is already more than the stack guarantees. X's save slot is
; at -2 and the local at -4, so the frame is 4 bytes and 2 of them are locals.
; CHECK-LABEL: align2:
; CHECK: STK X,1
; CHECK-NEXT: XFR S,X
; CHECK-NEXT: DCR S,1
; CHECK-NEXT: AND S,S,-2
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: XFR X,S
; CHECK-NEXT: POP X,1
; CHECK-NEXT: RSR
define i16 @align2(i16 %a) nounwind {
  %p = alloca i16, align 2
  store i16 %a, ptr %p
  %v = load i16, ptr %p
  ret i16 %v
}

; The local is placed at -4, directly below X's slot, and the frame is 4.
; CHECK-LABEL: align4:
; CHECK: STK X,1
; CHECK-NEXT: XFR S,X
; CHECK-NEXT: DCR S,1
; CHECK-NEXT: AND S,S,-4
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: XFR X,S
; CHECK-NEXT: POP X,1
; CHECK-NEXT: RSR
define i16 @align4(i16 %a) nounwind {
  %p = alloca i16, align 4
  store i16 %a, ptr %p
  %v = load i16, ptr %p
  ret i16 %v
}

; The local is placed at -8, leaving 4 bytes of padding under X's slot.
; CHECK-LABEL: align8:
; CHECK: STK X,1
; CHECK-NEXT: XFR S,X
; CHECK-NEXT: DCR S,5
; CHECK-NEXT: AND S,S,-8
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: XFR X,S
; CHECK-NEXT: POP X,1
; CHECK-NEXT: RSR
define i16 @align8(i16 %a) nounwind {
  %p = alloca i16, align 8
  store i16 %a, ptr %p
  %v = load i16, ptr %p
  ret i16 %v
}

; LLVM folds the low three bits of an align-8 slot address to zero. That is
; only true because the prologue rounded S down to a multiple of 8.
; CHECK-LABEL: knownbits:
; CHECK: AND S,S,-8
; CHECK: CLA
; CHECK: XFR X,S
define i16 @knownbits() nounwind {
  %p = alloca i16, align 8
  store i16 1, ptr %p
  %i = ptrtoint ptr %p to i16
  %m = and i16 %i, 7
  ret i16 %m
}

; Six bytes, not a power of two. No padding at alignment 1.
; CHECK-LABEL: six:
; CHECK-NOT: STK
; CHECK: DCR S,5
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: INR S,5
; CHECK-NEXT: RSR
define i16 @six(i16 %a) nounwind {
  %p = alloca [3 x i16], align 1
  store i16 %a, ptr %p
  %v = load i16, ptr %p
  ret i16 %v
}

; Sixteen-byte object at alignment 2. The i16 access is the first two bytes,
; at displacement 0.
; CHECK-LABEL: wide:
; CHECK: STK X,1
; CHECK-NEXT: XFR S,X
; CHECK-NEXT: DCR S,15
; CHECK-NEXT: AND S,S,-2
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: XFR X,S
; CHECK-NEXT: POP X,1
; CHECK-NEXT: RSR
define i16 @wide(i16 %a) nounwind {
  %p = alloca [8 x i16], align 2
  store i16 %a, ptr %p
  %v = load i16, ptr %p
  ret i16 %v
}

; Two slots. The argument is stored only to the first, then a constant to the
; second, so the value in A is not live across both stores. The first alloca
; is nearer the incoming S (displacement 2). The second is at the final S.
; CHECK-LABEL: two:
; CHECK: DCR S,3
; CHECK-NEXT: STR A,(S),2
; CHECK-NEXT: CLR A,7
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,2
; CHECK-NEXT: INR S,3
; CHECK-NEXT: RSR
define i16 @two(i16 %a) nounwind {
  %lo = alloca i16, align 1
  %hi = alloca i16, align 1
  store i16 %a, ptr %lo
  store i16 7, ptr %hi
  %v = load i16, ptr %lo
  ret i16 %v
}

; X's slot is at -2, the align-4 slot at -4, and the align-1 slot at -6. The
; frame is rounded up to 8. The padding is at the bottom, so the align-4
; slot is at displacement 4 and the align-1 slot at 2.
; CHECK-LABEL: padded:
; CHECK: STK X,1
; CHECK-NEXT: XFR S,X
; CHECK-NEXT: DCR S,5
; CHECK-NEXT: AND S,S,-4
; CHECK-NEXT: STR A,(S),4
; CHECK-NEXT: CLR A,7
; CHECK-NEXT: STR A,(S),2
; CHECK-NEXT: XFR (S),A,4
; CHECK-NEXT: XFR X,S
; CHECK-NEXT: POP X,1
; CHECK-NEXT: RSR
define i16 @padded(i16 %a) nounwind {
  %wide = alloca i16, align 4
  %byte = alloca i16, align 1
  store i16 %a, ptr %wide
  store i16 7, ptr %byte
  %v = load i16, ptr %wide
  ret i16 %v
}
