; Variadic calls. CC_CPU6 still puts the first four words in A, B, Y, Z.
; LowerCall and LowerFormalArguments reserve an 8-byte home ahead of any
; stack argument, one word per register. The callee spills the registers the
; named arguments did not take. va_start points at the first of those homes,
; or at the next stack word once all four registers are named. JSR's push of
; X makes a caller's offset N the callee's incoming S + N + 2.
;
; A non-variadic fifth word stays at the caller's (S),0. call.ll covers that.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s

declare void @llvm.va_start(ptr)
declare void @llvm.va_end(ptr)

; One named word, in A. The first variadic word is B. Its home is the
; caller's offset 2, the callee's incoming S + 4. The va_list alloca is the
; only local, so DCR S,1 lowers S by 2 and that home is (S),6.
; CHECK-LABEL: first:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: DCR S,1
; CHECK-NEXT: STR Z,(S),10
; CHECK-NEXT: STR Y,(S),8
; CHECK-NEXT: STR B,(S),6
; CHECK-NEXT: ADD S,A,6
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: ADD A,B,2
; CHECK-NEXT: STR B,(S),0
; CHECK-NEXT: XFR (A),A,0
; CHECK-NEXT: INR S,1
; CHECK-NEXT: RSR
define i16 @first(i16 %n, ...) nounwind {
  %ap = alloca ptr, align 1
  call void @llvm.va_start(ptr %ap)
  %v = va_arg ptr %ap, i16
  call void @llvm.va_end(ptr %ap)
  ret i16 %v
}

; No named arguments. A's home is the caller's offset 0, incoming S + 2,
; which is (S),4 after the same 2-byte alloca.
; CHECK-LABEL: none:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: DCR S,1
; CHECK-NEXT: STR Z,(S),10
; CHECK-NEXT: STR Y,(S),8
; CHECK-NEXT: STR B,(S),6
; CHECK-NEXT: STR A,(S),4
; CHECK-NEXT: ADD S,A,4
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: ADD A,B,2
; CHECK-NEXT: STR B,(S),0
; CHECK-NEXT: XFR (A),A,0
; CHECK-NEXT: INR S,1
; CHECK-NEXT: RSR
define i16 @none(...) nounwind {
  %ap = alloca ptr, align 1
  call void @llvm.va_start(ptr %ap)
  %v = va_arg ptr %ap, i16
  call void @llvm.va_end(ptr %ap)
  ret i16 %v
}

; A, B, Y, and Z are all named, so nothing is spilled. The first variadic
; word is the caller's offset 8, incoming S + 10, (S),12 after DCR S,1.
; CHECK-LABEL: onstack:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: DCR S,1
; CHECK-NEXT: ADD S,A,12
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: ADD A,B,2
; CHECK-NEXT: STR B,(S),0
; CHECK-NEXT: XFR (A),A,0
; CHECK-NEXT: INR S,1
; CHECK-NEXT: RSR
define i16 @onstack(i16 %a, i16 %b, i16 %c, i16 %d, ...) nounwind {
  %ap = alloca ptr, align 1
  call void @llvm.va_start(ptr %ap)
  %v = va_arg ptr %ap, i16
  call void @llvm.va_end(ptr %ap)
  ret i16 %v
}

; An i32 is two words, high half first. It occupies B and Y. The va_list
; advances four bytes, and the low half is the word after the high half.
; CHECK-LABEL: wide:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: DCR S,1
; CHECK-NEXT: STR Z,(S),10
; CHECK-NEXT: STR Y,(S),8
; CHECK-NEXT: STR B,(S),6
; CHECK-NEXT: ADD S,A,6
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: ADD A,B,2
; CHECK-NEXT: STR B,(S),0
; CHECK-NEXT: XFR (A),A,0
; CHECK-NEXT: XFR (S),B,0
; CHECK-NEXT: ADD B,C,2
; CHECK-NEXT: STR C,(S),0
; CHECK-NEXT: XFR (B),B,0
; CHECK-NEXT: INR S,1
; CHECK-NEXT: RSR
define i32 @wide(i16 %tag, ...) nounwind {
  %ap = alloca ptr, align 1
  call void @llvm.va_start(ptr %ap)
  %v = va_arg ptr %ap, i32
  call void @llvm.va_end(ptr %ap)
  ret i32 %v
}

declare i16 @first_decl(i16, ...)
declare i16 @onstack_decl(i16, i16, i16, i16, ...)
declare i32 @wide_decl(i16, ...)

; Both variadic words fit in B and Y. The 8-byte home is still reserved:
; DCR S,7 lowers S by 8. Nothing is stored there; the callee spills.
; CHECK-LABEL: call_regs:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: STK Y,1
; CHECK-NEXT: DCR S,7
; CHECK-NEXT: CLR A,1
; CHECK-NEXT: CLR B,10
; CHECK-NEXT: XFR Y,20
; CHECK-NEXT: JSR (first_decl)
; CHECK-NEXT: INR S,7
; CHECK-NEXT: POP Y,1
; CHECK-NEXT: RSR
define i16 @call_regs() nounwind {
  %r = call i16 (i16, ...) @first_decl(i16 1, i16 10, i16 20)
  ret i16 %r
}

; Four named words fill the registers. The two variadic words are the
; caller's offsets 8 and 10, just above the 8-byte home. DCR S,11 is
; 12 bytes: the home plus those two words.
; CHECK-LABEL: call_stack:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: STK Y,3
; CHECK-NEXT: DCR S,11
; CHECK-NEXT: CLR A,7
; CHECK-NEXT: STR A,(S),10
; CHECK-NEXT: XFR A,50
; CHECK-NEXT: STR A,(S),8
; CHECK-NEXT: CLR A,1
; CHECK-NEXT: CLR B,2
; CHECK-NEXT: CLR Y,3
; CHECK-NEXT: CLR Z,4
; CHECK-NEXT: JSR (onstack_decl)
; CHECK-NEXT: INR S,11
; CHECK-NEXT: POP Y,3
; CHECK-NEXT: RSR
define i16 @call_stack() nounwind {
  %r = call i16 (i16, i16, i16, i16, ...) @onstack_decl(i16 1, i16 2, i16 3, i16 4, i16 50, i16 7)
  ret i16 %r
}

; 0x12345678 is the high word 0x1234 (4660) in B and the low word 0x5678
; (22136) in Y. No stack store: both halves are inside the home.
; CHECK-LABEL: call_wide:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: STK Y,1
; CHECK-NEXT: DCR S,7
; CHECK-NEXT: CLR A,1
; CHECK-NEXT: XFR B,4660
; CHECK-NEXT: XFR Y,22136
; CHECK-NEXT: JSR (wide_decl)
; CHECK-NEXT: INR S,7
; CHECK-NEXT: POP Y,1
; CHECK-NEXT: RSR
define i32 @call_wide() nounwind {
  %r = call i32 (i16, ...) @wide_decl(i16 1, i32 305419896)
  ret i32 %r
}
