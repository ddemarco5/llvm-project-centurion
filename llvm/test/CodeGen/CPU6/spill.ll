; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s

; Every store goes through A, and %a is still needed for the return. The
; allocator spills %a with STR, rebuilds each sum in A, and reloads %a with
; XFR. The spill slot is at S+0 and the alloca at S+2.

; CHECK-LABEL: four:
; CHECK:      DCR S,3
; CHECK-NEXT: STR A,(S),0 {{.*}}Spill
; CHECK-NEXT: INA
; CHECK-NEXT: STA (S),2
; CHECK-NEXT: ADD B,A,2
; CHECK-NEXT: STA (S),2
; CHECK-NEXT: ADD Y,A,3
; CHECK-NEXT: STA (S),2
; CHECK-NEXT: ADD Z,A,4
; CHECK-NEXT: STA (S),2
; CHECK-NEXT: XFR (S),A,0 {{.*}}Reload
; CHECK-NEXT: INR S,3
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

; %a has two uses. The -O0 fast allocator spills it on entry and reloads it
; into A for the second store.

; CHECK-LABEL: two:
; CHECK:      DCR S,5
; CHECK-NEXT: STR A,(S),0 {{.*}}Spill
; CHECK-NEXT: STA (S),4
; CHECK-NEXT: XFR (S),A,0 {{.*}}Reload
; CHECK-NEXT: STA (S),2
; CHECK-NEXT: LDA (S),4
; CHECK-NEXT: INR S,5
; CHECK-NEXT: RSR
define i16 @two(i16 %a) {
  %p = alloca i16
  %q = alloca i16
  store i16 %a, ptr %p
  store i16 %a, ptr %q
  %r = load i16, ptr %p
  ret i16 %r
}
