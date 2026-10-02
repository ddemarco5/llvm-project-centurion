; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s

; STR names the register being stored, so each sum is written from the
; register that computed it. %a stays in A for the return, and the only
; stack slot is the alloca.

; CHECK-LABEL: four:
; CHECK:      DCR S,1
; CHECK-NEXT: ADD A,C,1
; CHECK-NEXT: STR C,(S),0
; CHECK-NEXT: INR B,1
; CHECK-NEXT: STR B,(S),0
; CHECK-NEXT: ADD Y,B,3
; CHECK-NEXT: STR B,(S),0
; CHECK-NEXT: ADD Z,B,4
; CHECK-NEXT: STR B,(S),0
; CHECK-NEXT: INR S,1
; CHECK-NEXT: RSR
define i16 @four(i16 %a, i16 %b, i16 %c, i16 %d) {
  %slot = alloca i16
  %a1 = add i16 %a, 1
  store i16 %a1, ptr %slot
  %b1 = add i16 %b, 2
  store i16 %b1, ptr %slot
  %c1 = add i16 %c, 3
  store i16 %c1, ptr %slot
  %d1 = add i16 %d, 4
  store i16 %d1, ptr %slot
  ret i16 %a
}

; %a is stored twice and then loaded back. Both stores name A, so it does
; not have to be spilled first.

; CHECK-LABEL: two:
; CHECK:      DCR S,3
; CHECK-NEXT: STR A,(S),2
; CHECK-NEXT: STR A,(S),0
; CHECK-NEXT: XFR (S),A,2
; CHECK-NEXT: INR S,3
; CHECK-NEXT: RSR
define i16 @two(i16 %a) {
  %p = alloca i16
  %q = alloca i16
  store i16 %a, ptr %p
  store i16 %a, ptr %q
  %r = load i16, ptr %p
  ret i16 %r
}
