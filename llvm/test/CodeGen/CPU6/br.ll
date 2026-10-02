; RUN: llc -mtriple=cpu6 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s --check-prefix=O0

; Every condition is one compare and one branch. SUB a,b sets the flags of
; a - b: BZ/BNZ test equality and BL/BNL (Link, no borrow) unsigned >=.
; Signed compares flip both sign bits first. A sign or zero test is XFR r,r.

declare void @f()

; CHECK-LABEL: eq:
; CHECK:      SUB A,B
; CHECK-NEXT: BNZ .LBB0_2
define void @eq(i16 %a, i16 %b) {
  %c = icmp eq i16 %a, %b
  br i1 %c, label %t, label %e
t:
  call void @f()
  br label %e
e:
  ret void
}

; CHECK-LABEL: ult:
; CHECK:      SUB A,B
; CHECK-NEXT: BL .LBB1_2
define void @ult(i16 %a, i16 %b) {
  %c = icmp ult i16 %a, %b
  br i1 %c, label %t, label %e
t:
  call void @f()
  br label %e
e:
  ret void
}

; a > b is b < a.
; CHECK-LABEL: ugt:
; CHECK:      SUB B,A
; CHECK-NEXT: BL .LBB2_2
define void @ugt(i16 %a, i16 %b) {
  %c = icmp ugt i16 %a, %b
  br i1 %c, label %t, label %e
t:
  call void @f()
  br label %e
e:
  ret void
}

; a < 100 is 99 >= a, the SUB literal form (imm - r).
; CHECK-LABEL: ult_imm:
; CHECK:      SUB A,A,99
; CHECK-NEXT: BNL .LBB3_2
define void @ult_imm(i16 %a) {
  %c = icmp ult i16 %a, 100
  br i1 %c, label %t, label %e
t:
  call void @f()
  br label %e
e:
  ret void
}

; CHECK-LABEL: slt:
; CHECK:      ORE B,B,-32768
; CHECK-NEXT: ORE A,A,-32768
; CHECK-NEXT: SUB A,B
; CHECK-NEXT: BL .LBB4_2
define void @slt(i16 %a, i16 %b) {
  %c = icmp slt i16 %a, %b
  br i1 %c, label %t, label %e
t:
  call void @f()
  br label %e
e:
  ret void
}

; CHECK-LABEL: neg:
; CHECK:      XFR A,A
; CHECK-NEXT: BM .LBB5_2
define void @neg(i16 %a) {
  %c = icmp slt i16 %a, 0
  br i1 %c, label %t, label %e
t:
  call void @f()
  br label %e
e:
  ret void
}

; CHECK-LABEL: pos:
; CHECK:      XFR A,A
; CHECK-NEXT: BLE .LBB6_2
define void @pos(i16 %a) {
  %c = icmp sgt i16 %a, 0
  br i1 %c, label %t, label %e
t:
  call void @f()
  br label %e
e:
  ret void
}

; CHECK-LABEL: byte:
; CHECK:      SUBB AL,BL
; CHECK-NEXT: BNL .LBB7_2
define void @byte(i8 %a, i8 %b) {
  %c = icmp uge i8 %a, %b
  br i1 %c, label %t, label %e
t:
  call void @f()
  br label %e
e:
  ret void
}

; a > 7 is a >= 8, which keeps the constant in the register SUBB overwrites.
; CHECK-LABEL: byte_imm:
; CHECK:      CLRB BL,8
; CHECK-NEXT: SUBB AL,BL
; CHECK-NEXT: BNL .LBB8_2
define void @byte_imm(i8 %a) {
  %c = icmp ugt i8 %a, 7
  br i1 %c, label %t, label %e
t:
  call void @f()
  br label %e
e:
  ret void
}

; A select is a branch over the false value's copy.
; CHECK-LABEL: sel:
; CHECK:      SUB A,B
; CHECK-NEXT: BNL .LBB9_2
; CHECK-NEXT: .LBB9_1:
; CHECK-NEXT: XFR Z,Y
; CHECK-NEXT: .LBB9_2:
; CHECK-NEXT: XFR Y,A
define i16 @sel(i16 %a, i16 %b, i16 %x, i16 %y) {
  %c = icmp ult i16 %a, %b
  %r = select i1 %c, i16 %x, i16 %y
  ret i16 %r
}

; The PHI's CLR goes in front of the compare, not between it and the branch.
; CHECK-LABEL: setcc:
; CHECK:      XFR A,C
; CHECK-NEXT: CLR A,1
; CHECK-NEXT: SUB C,B
; CHECK-NEXT: BZ .LBB10_2
; CHECK-NEXT: .LBB10_1:
; CHECK-NEXT: CLA
; O0-LABEL: setcc:
; O0:         STR C,(S),2
; O0-NEXT:    SUB A,B
; O0-NEXT:    BZ .LBB10_2
define i16 @setcc(i16 %a, i16 %b) {
  %c = icmp eq i16 %a, %b
  %r = zext i1 %c to i16
  ret i16 %r
}

; CHECK-LABEL: selb:
; CHECK:      XFRB AL,AL
; CHECK-NEXT: BZ .LBB11_2
; CHECK-NEXT: .LBB11_1:
; CHECK-NEXT: XFRB YL,BL
define i8 @selb(i8 %a, i8 %x, i8 %y) {
  %c = icmp eq i8 %a, 0
  %r = select i1 %c, i8 %x, i8 %y
  ret i8 %r
}

; The copy SUB's overwritten operand needs comes before the compare.
; CHECK-LABEL: loop:
; CHECK:      .LBB12_1:
; CHECK:      XFR B,X
; CHECK-NEXT: SUB C,X
; CHECK-NEXT: BNZ .LBB12_1
define i16 @loop(i16 %n) {
entry:
  br label %l
l:
  %i = phi i16 [ 0, %entry ], [ %i1, %l ]
  %s = phi i16 [ 0, %entry ], [ %s1, %l ]
  %s1 = add i16 %s, %i
  %i1 = add i16 %i, 1
  %c = icmp ne i16 %i1, %n
  br i1 %c, label %l, label %x
x:
  ret i16 %s1
}

; No jump tables: 1 <= a <= 3 is one range check.
; CHECK-LABEL: sw:
; CHECK:      DCA
; CHECK-NEXT: SUB A,A,2
; CHECK-NEXT: BNL .LBB13_2
define void @sw(i16 %a) {
  switch i16 %a, label %d [
    i16 1, label %t
    i16 2, label %t
    i16 3, label %t
    i16 4, label %e
  ]
t:
  call void @f()
  br label %e
d:
  br label %e
e:
  ret void
}

; Both successors need a jump.
; CHECK-LABEL: two:
; CHECK:      SUB B,A
; CHECK-NEXT: BNL .LBB14_2
; O0-LABEL: two:
; O0:         BNL .LBB14_2
; O0-NEXT:    JMP (PC),.LBB14_1
define i16 @two(i16 %a, i16 %b) {
  %c = icmp sle i16 %a, %b
  br i1 %c, label %t, label %e
t:
  call void @f()
  ret i16 1
e:
  call void @f()
  call void @f()
  ret i16 2
}

; CHECK-LABEL: ind:
; CHECK:      JMP (A)
define void @ind(ptr addrspace(1) %p) {
  indirectbr ptr addrspace(1) %p, [label %a, label %b]
a:
  call void @f()
  ret void
b:
  ret void
}

; CHECK-LABEL: baddr:
; CHECK:      XFR A,.Ltmp0
define ptr addrspace(1) @baddr() {
  br label %l
l:
  ret ptr addrspace(1) blockaddress(@baddr, %l)
}
