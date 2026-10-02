; Address selection. An indexed word is `XFR (r),dst,disp` or
; `STR src,(r),disp`: the data register is named, and the displacement is a
; word. A symbol, or a symbol plus a constant, is the direct accumulator
; form (`LDA (g)`). A constant that does not fit in a byte displacement is
; added first when the access is a byte; a word displacement holds it. The
; address of a slot is S plus the slot's distance from S.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s

@g = global i16 0
@b = global i8 0

; The pointer arrives in A.
; CHECK-LABEL: thru:
; CHECK:       XFR (A),A,0
; CHECK-NEXT:  RSR
define i16 @thru(ptr %p) nounwind {
  %v = load i16, ptr %p
  ret i16 %v
}

; 4 fits in the displacement byte, so it folds into the load.
; CHECK-LABEL: disp:
; CHECK:       XFR (A),A,4
; CHECK-NEXT:  RSR
define i16 @disp(ptr %p) nounwind {
  %q = getelementptr i8, ptr %p, i16 4
  %v = load i16, ptr %q
  ret i16 %v
}

; 200 does not fit. Add it, then load through the register.
; CHECK-LABEL: far:
; CHECK:       ADD A,A,200
; CHECK-NEXT:  XFR (A),A,0
; CHECK-NEXT:  RSR
define i16 @far(ptr %p) nounwind {
  %q = getelementptr i8, ptr %p, i16 200
  %v = load i16, ptr %q
  ret i16 %v
}

; CHECK-LABEL: loadg:
; CHECK:       LDA (g)
; CHECK-NEXT:  RSR
define i16 @loadg() nounwind {
  %v = load i16, ptr @g
  ret i16 %v
}

; The +4 is the relocation addend, not a separate add.
; CHECK-LABEL: loadg4:
; CHECK:       LDA (g+4)
; CHECK-NEXT:  RSR
define i16 @loadg4() nounwind {
  %q = getelementptr i8, ptr @g, i16 4
  %v = load i16, ptr %q
  ret i16 %v
}

; CHECK-LABEL: storeg:
; CHECK:       STA (g)
; CHECK-NEXT:  RSR
define void @storeg(i16 %a) nounwind {
  store i16 %a, ptr @g
  ret void
}

; The array is 8 bytes. Element 1 is two bytes in, so the displacement is 2.
; CHECK-LABEL: elem:
; CHECK:       DCR S,7
; CHECK-NEXT:  STR A,(S),2
; CHECK-NEXT:  XFR (S),A,2
; CHECK-NEXT:  INR S,7
; CHECK-NEXT:  RSR
define i16 @elem(i16 %a) nounwind {
  %p = alloca [4 x i16], align 1
  %q = getelementptr [4 x i16], ptr %p, i16 0, i16 1
  store i16 %a, ptr %q
  %v = load i16, ptr %q
  ret i16 %v
}

; The slot sits at S after the prologue, so the address is S + 0.
; CHECK-LABEL: slot:
; CHECK:       DCR S,1
; CHECK-NEXT:  ADD S,A,0
; CHECK-NEXT:  INR S,1
; CHECK-NEXT:  RSR
define ptr @slot() nounwind {
  %p = alloca i16, align 1
  ret ptr %p
}

; The address of a symbol is a literal, not a load.
; CHECK-LABEL: sym:
; CHECK:       XFR A,g
; CHECK-NEXT:  RSR
define ptr @sym() nounwind {
  ret ptr @g
}

; CHECK-LABEL: bytep:
; CHECK:       LDAB (A),0
; CHECK:       RSR
define i8 @bytep(ptr %p) nounwind {
  %v = load i8, ptr %p
  ret i8 %v
}

; CHECK-LABEL: imm:
; CHECK:       LDA (256)
; CHECK-NEXT:  RSR
define i16 @imm() nounwind {
  %p = inttoptr i16 256 to ptr
  %v = load i16, ptr %p
  ret i16 %v
}

; The value arrived in B and the pointer in A. STR names both, so neither
; has to move.
; CHECK-LABEL: st:
; CHECK:       STR B,(A),0
; CHECK:       RSR
define void @st(ptr %p, i16 %v) nounwind {
  store i16 %v, ptr %p
  ret void
}

; CHECK-LABEL: loadb:
; CHECK:       LDAB (b)
; CHECK:       RSR
define i8 @loadb() nounwind {
  %v = load i8, ptr @b
  ret i8 %v
}

; A variable index is scaled and added. It is not a displacement.
; CHECK-LABEL: idx:
; CHECK:       SLA
; CHECK-NEXT:  ADD B,A
; CHECK-NEXT:  XFR (A),A,0
; CHECK:       RSR
define i16 @idx(ptr %p, i16 %i) nounwind {
  %q = getelementptr i16, ptr %p, i16 %i
  %v = load i16, ptr %q
  ret i16 %v
}

; The slot plus the element offset is one ADD.
; CHECK-LABEL: elemaddr:
; CHECK:       DCR S,7
; CHECK-NEXT:  ADD S,A,4
; CHECK-NEXT:  INR S,7
; CHECK-NEXT:  RSR
define ptr @elemaddr() nounwind {
  %p = alloca [4 x i16], align 1
  %q = getelementptr [4 x i16], ptr %p, i16 0, i16 2
  ret ptr %q
}

; %far is allocated first, so it sits above the 200-byte array, 200 bytes
; from S. STR and XFR take a word displacement, so 200 fits.
; CHECK-LABEL: farslot:
; CHECK:       ADD S,S,-202
; CHECK-NEXT:  STR A,(S),200
; CHECK-NEXT:  XFR (S),A,200
; CHECK-NEXT:  ADD S,S,202
; CHECK-NEXT:  RSR
define i16 @farslot(i16 %a) nounwind {
  %far = alloca i16, align 1
  %pad = alloca [200 x i8], align 1
  store i16 %a, ptr %far
  %v = load i16, ptr %far
  ret i16 %v
}

; The fifth argument is at the incoming S + 2: 202 bytes above S here.
; CHECK-LABEL: stackarg:
; CHECK:       ADD S,S,-200
; CHECK-NEXT:  XFR (S),A,202
; CHECK-NEXT:  ADD S,S,200
; CHECK-NEXT:  RSR
define i16 @stackarg(i16 %a, i16 %b, i16 %c, i16 %d, i16 %e) nounwind {
  %pad = alloca [200 x i8], align 1
  ret i16 %e
}

declare void @use(ptr)

; CHECK-LABEL: pass:
; CHECK:       ADD S,A,0
; CHECK-NEXT:  JSR (use)
; CHECK:       RSR
define void @pass() nounwind {
  %p = alloca i16, align 1
  call void @use(ptr %p)
  ret void
}
