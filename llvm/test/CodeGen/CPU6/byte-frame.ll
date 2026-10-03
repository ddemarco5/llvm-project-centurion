; LDAB and STAB take a signed byte displacement from S. A byte object created
; before a tall word object would otherwise sit more than 127 bytes from the
; final S. Byte objects are allocated last, so the byte slot is at that S and
; the word object is reached with STR and XFR, which take a 16-bit
; displacement.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s

; CHECK-LABEL: byte_near:
; CHECK:       ADD S,S,-161
; CHECK:       STAB (S),0
; CHECK:       LDAB (S),0
; CHECK:       ADD S,S,161
define i8 @byte_near(i8 %c) nounwind {
  %b = alloca i8, align 1
  %words = alloca [80 x i16], align 1
  store i8 %c, ptr %b
  %v = load i8, ptr %b
  store i16 0, ptr %words
  ret i8 %v
}

; An 11-byte array under the same word frame. At -O0 the argument byte is
; spilled across the two stores, and that spill is a byte object too, so it
; is the slot nearest S. The array starts at displacement 1; index 10 is 11.
; CHECK-LABEL: palette:
; CHECK:       ADD S,S,-172
; CHECK:       STAB (S),0
; CHECK:       STAB (S),1
; CHECK:       STAB (S),11
; CHECK:       STR A,(S),12
; CHECK:       ADD S,S,172
define void @palette(i8 %c) nounwind {
  %p = alloca [11 x i8], align 1
  %words = alloca [80 x i16], align 1
  %e0 = getelementptr [11 x i8], ptr %p, i16 0, i16 0
  %e10 = getelementptr [11 x i8], ptr %p, i16 0, i16 10
  store i8 %c, ptr %e0
  store i8 %c, ptr %e10
  store i16 0, ptr %words
  ret void
}
