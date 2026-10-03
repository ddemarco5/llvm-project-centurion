; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; Word add with a literal selects the three-address ADD src,dst,n. When the
; allocator gives the sum the source's register, the AsmPrinter emits
; INR/DCR r,|n|-1 for |n| <= 16, and INR A,0 / DCR A,0 as INA / DCA (see
; compress.mir).
; CHECK-LABEL: inc1:
; CHECK:      INA
; CHECK-NEXT: RSR
define i16 @inc1(i16 %a) {
  %v = add i16 %a, 1
  ret i16 %v
}

; CHECK-LABEL: inc16:
; CHECK:      INR A,15
; CHECK-NEXT: RSR
define i16 @inc16(i16 %a) {
  %v = add i16 %a, 16
  ret i16 %v
}

; CHECK-LABEL: add17:
; CHECK:      ADD A,A,17
; CHECK-NEXT: RSR
define i16 @add17(i16 %a) {
  %v = add i16 %a, 17
  ret i16 %v
}

; CHECK-LABEL: dec1:
; CHECK:      DCA
; CHECK-NEXT: RSR
define i16 @dec1(i16 %a) {
  %v = sub i16 %a, 1
  ret i16 %v
}

; The source and destination differ, so the four-byte form stays.
; CHECK-LABEL: dec5b:
; CHECK:      ADD B,A,-5
; CHECK-NEXT: RSR
define i16 @dec5b(i16 %a, i16 %b) {
  %v = sub i16 %b, 5
  ret i16 %v
}

; This used to be selected as an in-place INR. The coalescer then tied the
; sum to %d's register Z, and the allocator saved and restored the
; callee-saved Z around it. The three-address ADD avoids that.
; CHECK-LABEL: incz:
; CHECK:      ADD Z,A,2
; CHECK-NEXT: RSR
define i16 @incz(i16 %a, i16 %b, i16 %c, i16 %d) {
  %v = add i16 %d, 2
  ret i16 %v
}

; CLR r,n loads 0-15 in two bytes, and CLR A,0 is CLA. Larger values use XFR.
; CHECK-LABEL: c0:
; CHECK:      CLA
; CHECK-NEXT: RSR
define i16 @c0() {
  ret i16 0
}

; CHECK-LABEL: c9:
; CHECK:      CLR A,9
; CHECK-NEXT: RSR
define i16 @c9() {
  ret i16 9
}

; CHECK-LABEL: c16:
; CHECK:      XFR A,16
; CHECK-NEXT: RSR
define i16 @c16() {
  ret i16 16
}

; CHECK-LABEL: not:
; CHECK:      IVA
; CHECK-NEXT: RSR
define i16 @not(i16 %a) {
  %v = xor i16 %a, -1
  ret i16 %v
}

; SLR r,n shifts left by n + 1.
; CHECK-LABEL: shl4:
; CHECK:      SLR A,3
; CHECK-NEXT: RSR
define i16 @shl4(i16 %a) {
  %v = shl i16 %a, 4
  ret i16 %v
}

; SRR r,n is an arithmetic shift right by n + 1.
; CHECK-LABEL: ashr4:
; CHECK:      SRR A,3
; CHECK-NEXT: RSR
define i16 @ashr4(i16 %a) {
  %v = ashr i16 %a, 4
  ret i16 %v
}

; A shift of 1 encodes a count nibble of 0.
; CHECK-LABEL: ashr1:
; CHECK:      SRR A,0
; CHECK-NEXT: RSR
define i16 @ashr1(i16 %a) {
  %v = ashr i16 %a, 1
  ret i16 %v
}

; SRR sign-fills. The bits it filled are cleared, leaving a logical shift.
; CHECK-LABEL: lshr4:
; CHECK:      SRR A,3
; CHECK-NEXT: AND A,A,4095
; CHECK-NEXT: RSR
define i16 @lshr4(i16 %a) {
  %v = lshr i16 %a, 4
  ret i16 %v
}

; The top bit is the one SRR filled. Masking it is the whole correction.
; CHECK-LABEL: lshr1:
; CHECK:      SRR A,0
; CHECK-NEXT: AND A,A,32767
; CHECK-NEXT: RSR
define i16 @lshr1(i16 %a) {
  %v = lshr i16 %a, 1
  ret i16 %v
}

; An i32 shift by a constant splits into i16 shifts. The low half's top bit
; reaches the high half through a logical shift of 15.
; CHECK-LABEL: shl32:
; CHECK-DAG: SLR
; CHECK-DAG: SRR
; CHECK-DAG: AND
; CHECK:     RSR
define i32 @shl32(i32 %a) {
  %v = shl i32 %a, 1
  ret i32 %v
}

; The count nibble is an immediate, so a register count is a one-bit loop.
; A zero count branches past it. SLA is SLR A,0 and DCA is DCR A,0.
; CHECK-LABEL: shl_var:
; CHECK:      BZ
; CHECK:      {{SLA|SLR}}
; CHECK:      {{DCA|DCR}}
; CHECK:      BNZ
; CHECK:      RSR
define i16 @shl_var(i16 %a, i16 %n) {
  %v = shl i16 %a, %n
  ret i16 %v
}

; CHECK-LABEL: ashr_var:
; CHECK:      BZ
; CHECK:      {{SRA|SRR}}
; CHECK:      {{DCA|DCR}}
; CHECK:      BNZ
; CHECK:      RSR
define i16 @ashr_var(i16 %a, i16 %n) {
  %v = ashr i16 %a, %n
  ret i16 %v
}

; Each step is a rotate through a cleared Link, which shifts in a zero.
; A longer rotate would bring that bit back, so the count here is 0.
; CHECK-LABEL: lshr_var:
; CHECK:      BZ
; CHECK:      RL
; CHECK:      RRR
; CHECK:      {{DCA|DCR}}
; CHECK:      BNZ
; CHECK:      RSR
define i16 @lshr_var(i16 %a, i16 %n) {
  %v = lshr i16 %a, %n
  ret i16 %v
}

; Register/register ALU is two-address: OP src,dst is dst = dst op src.
; ADD, AND, ORI and ORE are commutable, so the result is built in A.
; CHECK-LABEL: addrr:
; CHECK:      ADD B,A
; CHECK-NEXT: RSR
define i16 @addrr(i16 %a, i16 %b) {
  %v = add i16 %a, %b
  ret i16 %v
}

; CHECK-LABEL: andrr:
; CHECK:      AND B,A
; CHECK-NEXT: RSR
define i16 @andrr(i16 %a, i16 %b) {
  %v = and i16 %a, %b
  ret i16 %v
}

; CHECK-LABEL: orrr:
; CHECK:      ORI B,A
; CHECK-NEXT: RSR
define i16 @orrr(i16 %a, i16 %b) {
  %v = or i16 %a, %b
  ret i16 %v
}

; CHECK-LABEL: xorrr:
; CHECK:      ORE B,A
; CHECK-NEXT: RSR
define i16 @xorrr(i16 %a, i16 %b) {
  %v = xor i16 %a, %b
  ret i16 %v
}

; SUB src,dst is dst = src - dst and is not commutable. b - a fits A
; directly. a - b lands in B (SUB A,B is SAB) and is copied back.
; CHECK-LABEL: subrr2:
; CHECK:      SUB B,A
; CHECK-NEXT: RSR
define i16 @subrr2(i16 %a, i16 %b) {
  %v = sub i16 %b, %a
  ret i16 %v
}

; CHECK-LABEL: subrr:
; CHECK:      SAB
; CHECK-NEXT: XFR B,A
; CHECK-NEXT: RSR
define i16 @subrr(i16 %a, i16 %b) {
  %v = sub i16 %a, %b
  ret i16 %v
}

; %a is still live after the add, so the sum gets its own register.
; CHECK-LABEL: keep:
; CHECK:      ADD A,B,3
; CHECK-NEXT: ORE B,A
; CHECK-NEXT: RSR
define i16 @keep(i16 %a) {
  %b = add i16 %a, 3
  %c = xor i16 %b, %a
  ret i16 %c
}
