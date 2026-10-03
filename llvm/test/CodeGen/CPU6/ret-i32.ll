; An i32 return is two i16 parts. The data layout is big-endian, so the
; high half is in A and the low half is in B. RetCC_CPU6 assigns i16 results
; to A, then B.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s

; 0x00010002: high half 1, low half 2. CLR r,n writes n.
; CHECK-LABEL: imm:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: CLR A,1
; CHECK-NEXT: CLR B,2
; CHECK-NEXT: RSR
define i32 @imm() nounwind {
  ret i32 65538
}

; %lo arrives in A and %hi in B. The result wants those halves exchanged.
; CHECK-LABEL: parts:
; CHECK-NEXT: # %bb.0:
; CHECK-NEXT: DCR S,1
; CHECK-NEXT: STR B,(S),0
; CHECK-NEXT: XAB
; CHECK-NEXT: XFR (S),A,0
; CHECK-NEXT: INR S,1
; CHECK-NEXT: RSR
define i32 @parts(i16 %lo, i16 %hi) nounwind {
  %a = zext i16 %lo to i32
  %b = zext i16 %hi to i32
  %s = shl i32 %b, 16
  %r = or i32 %a, %s
  ret i32 %r
}
