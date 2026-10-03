; A word is stored high byte first. The low 8 bits of a loaded word sit at
; address+1. A shift of 8 reaches the byte at the address itself.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s

; The truncated word is stored as a byte, so the load narrows. The low
; byte is one past the word's address.
; CHECK-LABEL: lowbyte:
; CHECK: LDAB (A),1
; CHECK: STAB
; CHECK: RSR
define void @lowbyte(ptr %p, ptr %q) nounwind {
  %w = load i16, ptr %p
  %b = trunc i16 %w to i8
  store volatile i8 %b, ptr %q
  ret void
}

; CHECK-LABEL: highbyte:
; CHECK: LDAB (A),0
; CHECK: RSR
define i8 @highbyte(ptr %p) nounwind {
  %w = load i16, ptr %p
  %s = lshr i16 %w, 8
  %b = trunc i16 %s to i8
  ret i8 %b
}
