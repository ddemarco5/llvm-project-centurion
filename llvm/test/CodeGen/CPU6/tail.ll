; Tail calls. JMP (addr) does not push X, so the callee's RSR returns to our
; caller. X already holds that address from the JSR that entered this function.
; A call stays a JSR when the jump would be wrong: a new argument in Y or Z
; (the epilogue POP reloads the incoming value), a stack argument, or an
; address in a register.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s

declare i16 @ext(i16)
declare i16 @add2(i16, i16)
declare i16 @take3(i16, i16, i16)
declare i16 @take5(i16, i16, i16, i16, i16)

; The argument is already in A. There is no RSR in this function.
; CHECK-LABEL: fwd:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: JMP (ext)
define i16 @fwd(i16 %a) nounwind {
  %r = tail call i16 @ext(i16 %a)
  ret i16 %r
}

; A and B are caller-saved, so the new values are still there after the jump.
; CHECK-LABEL: imm:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: XFR A,40
; CHECK-NEXT: CLR B,2
; CHECK-NEXT: JMP (add2)
define i16 @imm() nounwind {
  %r = tail call i16 @add2(i16 40, i16 2)
  ret i16 %r
}

; Y already holds the third argument, and this function does not write it.
; CHECK-LABEL: fwd3:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: JMP (take3)
define i16 @fwd3(i16 %a, i16 %b, i16 %c) nounwind {
  %r = tail call i16 @take3(i16 %a, i16 %b, i16 %c)
  ret i16 %r
}

; 3 is a new Y. POP would replace it, so this is a JSR and our RSR returns.
; CHECK-LABEL: newy:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: STK Y,1
; CHECK-NEXT: CLR A,1
; CHECK-NEXT: CLR B,2
; CHECK-NEXT: CLR Y,3
; CHECK-NEXT: JSR (take3)
; CHECK-NEXT: POP Y,1
; CHECK-NEXT: RSR
define i16 @newy() nounwind {
  %r = tail call i16 @take3(i16 1, i16 2, i16 3)
  ret i16 %r
}

; The local is read while the frame is still up. INR puts S back, then JMP.
; CHECK-LABEL: frame:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: DCR S,1
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: INR S,1
; CHECK-NEXT: JMP (ext)
define i16 @frame(i16 %a) nounwind {
  %p = alloca i16
  store i16 %a, ptr %p
  %v = load i16, ptr %p
  %r = tail call i16 @ext(i16 %v)
  ret i16 %r
}

; Realigning uses X as the frame pointer. XFR X,S and POP X put the return
; address back in X before the jump.
; CHECK-LABEL: align:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: STK X,1
; CHECK-NEXT: XFR S,X
; CHECK-NEXT: DCR S,1
; CHECK-NEXT: AND S,S,-4
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: XFR X,S
; CHECK-NEXT: POP X,1
; CHECK-NEXT: JMP (ext)
define i16 @align(i16 %a) nounwind {
  %p = alloca i16, align 4
  store i16 %a, ptr %p
  %v = load i16, ptr %p
  %r = tail call i16 @ext(i16 %v)
  ret i16 %r
}

; The fifth word is a stack argument, so this cannot be a jump.
; CHECK-LABEL: stack:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: STK Y,3
; CHECK-NEXT: DCR S,1
; CHECK-NEXT: CLR A,5
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: CLR A,1
; CHECK-NEXT: CLR B,2
; CHECK-NEXT: CLR Y,3
; CHECK-NEXT: CLR Z,4
; CHECK-NEXT: JSR (take5)
; CHECK-NEXT: INR S,1
; CHECK-NEXT: POP Y,3
; CHECK-NEXT: RSR
define i16 @stack() nounwind {
  %r = tail call i16 @take5(i16 1, i16 2, i16 3, i16 4, i16 5)
  ret i16 %r
}

; The address is in a register. A POP in front of a jump would replace it.
; CHECK-LABEL: ind:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: DCR S,1
; CHECK-NEXT: STR B,(S),0
; CHECK-NEXT: XAB
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: JSR (B)
; CHECK-NEXT: INR S,1
; CHECK-NEXT: RSR
define i16 @ind(ptr addrspace(1) %f, i16 %a) nounwind {
  %r = tail call i16 %f(i16 %a)
  ret i16 %r
}
