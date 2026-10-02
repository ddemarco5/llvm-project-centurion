; RUN: llc -mtriple=cpu6 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s --check-prefix=O0
; RUN: llc -mtriple=cpu6 -filetype=obj < %s | llvm-objdump -dr - | FileCheck %s --check-prefix=OBJ

; Fifty 3-byte JSRs put the target out of an 8-bit displacement. Branch
; relaxation inverts the test to skip a JMP (addr), which reaches anywhere.

declare void @f()

; O0-LABEL: far:
; O0:      XFR A,A
; O0-NEXT: BZ .LBB0_1
; O0-NEXT: .LBB0_3:
; O0-NEXT: JMP (.LBB0_2)
define void @far(i16 %a) {
  %c = icmp eq i16 %a, 0
  br i1 %c, label %t, label %e
t:
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  br label %e
e:
  ret void
}

; CHECK-LABEL: back:
; CHECK:      SUB Y,A
; CHECK-NEXT: BL .LBB1_2
; CHECK-NEXT: .LBB1_3:
; CHECK:      JMP (.LBB1_1)
; OBJ-LABEL: <back>:
; OBJ:      10 03 BL 3
; OBJ-NEXT: 71 00 00 JMP (0)
; OBJ-NEXT: R_CPU6_16 .text+0xa1
define void @back(i16 %n) {
entry:
  br label %l
l:
  %i = phi i16 [ 0, %entry ], [ %i1, %l ]
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  call void @f()
  %i1 = add i16 %i, 1
  %c = icmp ult i16 %i1, %n
  br i1 %c, label %l, label %x
x:
  ret void
}