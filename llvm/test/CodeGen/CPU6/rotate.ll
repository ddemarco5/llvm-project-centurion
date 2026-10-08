; rotl and rotr are not RLR/RRR: those rotate through Link. A constant
; count is the two shifts ored together. A count of 8 is the byte
; exchange, the same sequence as bswap. A register count plants the
; wrapping bit in Link and then rotates through it.
;
; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; CHECK-LABEL: rotl1:
; CHECK:      SLR
; CHECK:      SRR
; CHECK:      AND
; CHECK:      ORI
; CHECK-NOT:  RLR
; CHECK-NOT:  RRR
; CHECK:      RSR
define i16 @rotl1(i16 %x) nounwind {
  %r = call i16 @llvm.fshl.i16(i16 %x, i16 %x, i16 1)
  ret i16 %r
}

; CHECK-LABEL: rotr1:
; CHECK-DAG:  SLR
; CHECK-DAG:  SRR
; CHECK-DAG:  AND
; CHECK:      ORI
; CHECK-NOT:  RLR
; CHECK-NOT:  RRR
; CHECK:      RSR
define i16 @rotr1(i16 %x) nounwind {
  %r = call i16 @llvm.fshr.i16(i16 %x, i16 %x, i16 1)
  ret i16 %r
}

; CHECK-LABEL: rotl8:
; CHECK:      XFRB
; CHECK-NOT:  SLR
; CHECK-NOT:  RLR
; CHECK:      RSR
define i16 @rotl8(i16 %x) nounwind {
  %r = call i16 @llvm.fshl.i16(i16 %x, i16 %x, i16 8)
  ret i16 %r
}

; CHECK-LABEL: rotr8:
; CHECK:      XFRB
; CHECK-NOT:  SLR
; CHECK-NOT:  RRR
; CHECK:      RSR
define i16 @rotr8(i16 %x) nounwind {
  %r = call i16 @llvm.fshr.i16(i16 %x, i16 %x, i16 8)
  ret i16 %r
}

; SLR plants the high bit in Link. RLR wraps it into the low bit.
; CHECK-LABEL: rotl_var:
; CHECK:      BZ
; CHECK:      SLR
; CHECK:      RLR
; CHECK:      BNZ
; CHECK:      RSR
define i16 @rotl_var(i16 %x, i16 %n) nounwind {
  %r = call i16 @llvm.fshl.i16(i16 %x, i16 %x, i16 %n)
  ret i16 %r
}

; CHECK-LABEL: rotr_var:
; CHECK:      BZ
; CHECK:      SRR
; CHECK:      RRR
; CHECK:      BNZ
; CHECK:      RSR
define i16 @rotr_var(i16 %x, i16 %n) nounwind {
  %r = call i16 @llvm.fshr.i16(i16 %x, i16 %x, i16 %n)
  ret i16 %r
}

; CHECK-LABEL: rotlb1:
; CHECK-DAG:  {{SLAB|SLRB}}
; CHECK-DAG:  {{SRAB|SRRB}}
; CHECK-DAG:  AND
; CHECK:      ORIB
; CHECK:      RSR
define i8 @rotlb1(i8 %x) nounwind {
  %r = call i8 @llvm.fshl.i8(i8 %x, i8 %x, i8 1)
  ret i8 %r
}

declare i16 @llvm.fshl.i16(i16, i16, i16)
declare i16 @llvm.fshr.i16(i16, i16, i16)
declare i8 @llvm.fshl.i8(i8, i8, i8)
