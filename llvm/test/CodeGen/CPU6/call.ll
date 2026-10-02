; Calls. webCenREE f_jsr (cen.ts) does stackw(X) and then sets X to the PC
; just past the JSR. RSR copies X into the PC and popw's the saved X, so the
; caller sees X and S unchanged. stackw writes the word big-endian and leaves
; S on its high byte, so a callee's incoming S points at that saved X.
; CC_CPU6 puts the first four words in A, B, Y, Z. The fifth is stored at the
; caller's S + 0, which is the callee's incoming S + 2.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s

declare void @side()
declare i16 @ext(i16)
declare i16 @take5(i16, i16, i16, i16, i16)
declare i16 @take6(i16, i16, i16, i16, i16, i16)
declare i8 @byteext(i8)

; CHECK-LABEL: go:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: JSR (side)
; CHECK-NEXT: RSR
define void @go() nounwind {
  call void @side()
  ret void
}

; The argument is already in A, which is where the callee wants it.
; CHECK-LABEL: add1:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: JSR (ext)
; CHECK-NEXT: RSR
define i16 @add1(i16 %a) nounwind {
  %r = call i16 @ext(i16 %a)
  ret i16 %r
}

; CHECK-LABEL: swap:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: XFR B,A
; CHECK-NEXT: JSR (ext)
; CHECK-NEXT: RSR
define i16 @swap(i16 %a, i16 %b) nounwind {
  %r = call i16 @ext(i16 %b)
  ret i16 %r
}

; No frame of our own, so incoming S + 2 is (S),2.
; CHECK-LABEL: fifth:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: LDA (S),2
; CHECK-NEXT: RSR
define i16 @fifth(i16 %a, i16 %b, i16 %c, i16 %d, i16 %e) nounwind {
  ret i16 %e
}

; The sixth word is one slot higher: incoming S + 4.
; CHECK-LABEL: sixth:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: LDA (S),4
; CHECK-NEXT: RSR
define i16 @sixth(i16 %a, i16 %b, i16 %c, i16 %d, i16 %e, i16 %f) nounwind {
  ret i16 %f
}

; Realigning saves X, so X holds incoming S minus those two bytes. The
; argument at incoming S + 2 is (X),4. The AND only moves S.
; CHECK-LABEL: fifth_align:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: STK X,1
; CHECK-NEXT: XFR S,X
; CHECK-NEXT: DCR S,1
; CHECK-NEXT: AND S,S,-4
; CHECK-NEXT: LDA (X),4
; CHECK-NEXT: STA (S),0
; CHECK-NEXT: LDA (S),0
; CHECK-NEXT: XFR X,S
; CHECK-NEXT: POP X,1
; CHECK-NEXT: RSR
define i16 @fifth_align(i16 %a, i16 %b, i16 %c, i16 %d, i16 %e) nounwind {
  %p = alloca i16, align 4
  store i16 %e, ptr %p
  %v = load i16, ptr %p
  ret i16 %v
}

; Y and Z are callee-saved, so writing the arguments there saves them first.
; DCR S,1 is the reserved 2-byte outgoing slot. The fifth word is (S),0,
; which JSR's push turns into the callee's (S),2.
; CHECK-LABEL: pass5:
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
define i16 @pass5() nounwind {
  %r = call i16 @take5(i16 1, i16 2, i16 3, i16 4, i16 5)
  ret i16 %r
}

; Two outgoing words. The fifth is still (S),0 and the sixth is (S),2.
; CHECK-LABEL: pass6:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: STK Y,3
; CHECK-NEXT: DCR S,3
; CHECK-NEXT: CLR A,6
; CHECK-NEXT: STR A,(S),2
; CHECK-NEXT: CLR A,5
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: CLR A,1
; CHECK-NEXT: CLR B,2
; CHECK-NEXT: CLR Y,3
; CHECK-NEXT: CLR Z,4
; CHECK-NEXT: JSR (take6)
; CHECK-NEXT: INR S,3
; CHECK-NEXT: POP Y,3
; CHECK-NEXT: RSR
define i16 @pass6() nounwind {
  %r = call i16 @take6(i16 1, i16 2, i16 3, i16 4, i16 5, i16 6)
  ret i16 %r
}

; Indirect. JSR (B) is opcode 0x7D, M' = 0: the register is the address and
; is not modified. The integer argument moves to A first.
; CHECK-LABEL: indir:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: DCR S,1
; CHECK-NEXT: STR B,(S),0
; CHECK-NEXT: XAB
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: JSR (B)
; CHECK-NEXT: INR S,1
; CHECK-NEXT: RSR
define i16 @indir(ptr addrspace(1) %f, i16 %a) nounwind {
  %r = call i16 %f(i16 %a)
  ret i16 %r
}

; A numeric address uses the same direct JSR as a symbol: 79 plus the
; big-endian word. 4660 is 0x1234.
; CHECK-LABEL: immcall:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: JSR (4660)
; CHECK-NEXT: RSR
define i16 @immcall() nounwind {
  %r = call addrspace(1) i16 inttoptr (i16 4660 to ptr addrspace(1))()
  ret i16 %r
}

; A byte travels in A, promoted, and comes back in A.
; CHECK-LABEL: bytecall:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: JSR (byteext)
; CHECK-NEXT: RSR
define i8 @bytecall(i8 %a) nounwind {
  %r = call i8 @byteext(i8 %a)
  ret i8 %r
}

; The incoming fifth word is at incoming S + 2. This frame is 4 bytes (the
; outgoing word and a spill of A), so that address is (S),6. The outgoing
; copy is (S),0, which the callee of take5 reads as its own (S),2.
; CHECK-LABEL: forward:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: DCR S,3
; CHECK-NEXT: STR A,(S),2
; CHECK-NEXT: LDA (S),6
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,2
; CHECK-NEXT: JSR (take5)
; CHECK-NEXT: INR S,3
; CHECK-NEXT: RSR
define i16 @forward(i16 %a, i16 %b, i16 %c, i16 %d, i16 %e) nounwind {
  %r = call i16 @take5(i16 %a, i16 %b, i16 %c, i16 %d, i16 %e)
  ret i16 %r
}

; Both calls share one reserved outgoing word. S moves in the prologue and
; the epilogue, and the second JSR stores the first call's result at (S),0.
; CHECK-LABEL: twice:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: STK Y,3
; CHECK-NEXT: DCR S,9
; CHECK-NEXT: CLR A,5
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: CLR A,1
; CHECK-NEXT: STR A,(S),8
; CHECK-NEXT: CLR B,2
; CHECK-NEXT: STR B,(S),6
; CHECK-NEXT: CLR Y,3
; CHECK-NEXT: STR Y,(S),4
; CHECK-NEXT: CLR Z,4
; CHECK-NEXT: STR Z,(S),2
; CHECK-NEXT: JSR (take5)
; CHECK-NEXT: XFR (S),Z,2
; CHECK-NEXT: XFR (S),Y,4
; CHECK-NEXT: XFR (S),B,6
; CHECK-NEXT: XFR A,C
; CHECK-NEXT: XFR (S),A,8
; CHECK-NEXT: STR C,(S),0
; CHECK-NEXT: JSR (take5)
; CHECK-NEXT: INR S,9
; CHECK-NEXT: POP Y,3
; CHECK-NEXT: RSR
define i16 @twice() nounwind {
  %a = call i16 @take5(i16 1, i16 2, i16 3, i16 4, i16 5)
  %b = call i16 @take5(i16 1, i16 2, i16 3, i16 4, i16 %a)
  ret i16 %b
}

; Realigning and calling. X is copied after STK, so the incoming fifth word
; is (X),4. The outgoing fifth word is still (S),0, below the aligned local
; at (S),8. JSR pushes that X and RSR pops it, so the epilogue's XFR X,S
; still restores the pre-call frame.
; CHECK-LABEL: realign_caller:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: STK X,1
; CHECK-NEXT: XFR S,X
; CHECK-NEXT: DCR S,9
; CHECK-NEXT: AND S,S,-4
; CHECK-NEXT: STR A,(S),6
; CHECK-NEXT: LDA (X),4
; CHECK-NEXT: STR A,(S),4
; CHECK-NEXT: CLR A,1
; CHECK-NEXT: STA (S),8
; CHECK-NEXT: XFR (S),A,4
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,6
; CHECK-NEXT: JSR (take5)
; CHECK-NEXT: XFR X,S
; CHECK-NEXT: POP X,1
; CHECK-NEXT: RSR
define i16 @realign_caller(i16 %a, i16 %b, i16 %c, i16 %d, i16 %e) nounwind {
  %p = alloca i16, align 4
  store i16 1, ptr %p
  %r = call i16 @take5(i16 %a, i16 %b, i16 %c, i16 %d, i16 %e)
  ret i16 %r
}
