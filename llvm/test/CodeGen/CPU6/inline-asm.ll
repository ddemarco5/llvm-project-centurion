; Extended asm. "r" is a GPR the allocator picks, "{A}" is that register,
; "i" is the immediate, and "m" is the address SelectAddr / SelectAbsAddr
; already match. The object-file run parses the text the printer emitted.
;
; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=cpu6 -O2 -filetype=obj -o %t.o < %s

; CHECK-LABEL: copy:
; CHECK: XFR {{[ABCXYZ]}},{{[ABCXYZ]}}
define i16 @copy(i16 %x) {
  %y = call i16 asm "XFR $1,$0", "=r,r"(i16 %x)
  ret i16 %y
}

; CHECK-LABEL: addimm:
; CHECK: ADD {{[ABCXYZ]}},{{[ABCXYZ]}},5
define i16 @addimm(i16 %x) {
  %y = call i16 asm "ADD $1,$0,$2", "=r,r,i"(i16 %x, i16 5)
  ret i16 %y
}

; CHECK-LABEL: in_a:
; CHECK: INR A,0
define i16 @in_a(i16 %x) {
  %y = call i16 asm "INR $0,0", "={A},0"(i16 %x)
  ret i16 %y
}

; CHECK-LABEL: copyb:
; CHECK: XFRB {{[ABXYZ][UL]}},{{[ABXYZ][UL]}}
define i8 @copyb(i8 %x) {
  %y = call i8 asm "XFRB $1,$0", "=r,r"(i8 %x)
  ret i8 %y
}

@g = global i16 7

; CHECK-LABEL: loadg:
; CHECK: LDA (g)
define i16 @loadg() {
  %y = call i16 asm "LDA $1", "={A},*m"(ptr elementtype(i16) @g)
  ret i16 %y
}

; CHECK-LABEL: loadlocal:
; CHECK: LDA ({{[SX]}})
define i16 @loadlocal(i16 %x) {
  %slot = alloca i16, align 1
  store i16 %x, ptr %slot
  %y = call i16 asm "LDA $1", "={A},*m"(ptr elementtype(i16) %slot)
  ret i16 %y
}

; CHECK-LABEL: storeg:
; CHECK: STA (g)
define void @storeg(i16 %v) {
  call void asm sideeffect "STA $0", "*m,{A}"(ptr elementtype(i16) @g, i16 %v)
  ret void
}
