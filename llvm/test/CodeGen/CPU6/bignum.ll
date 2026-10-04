; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; Opcode 0x46 selection. The two length operands are length-1: 3 is a 4-byte
; (i32) operand and 7 an 8-byte (i64) one. Globals select the address/address
; form, pointer arguments the register/register form.

@src32 = global i32 1
@dst32 = global i32 2
@src64 = global i64 1
@dst64 = global i64 2

;===----------------------------------------------------------------------===;
; ZAD: Dest := Src
;===----------------------------------------------------------------------===;

; CHECK-LABEL: zad32:
; CHECK:       ZAD 3,3,(src32),(dst32)
; CHECK-NEXT:  RSR
define void @zad32() nounwind {
  %v = load i32, ptr @src32, align 1
  store i32 %v, ptr @dst32, align 1
  ret void
}

; CHECK-LABEL: zad64:
; CHECK:       ZAD 7,7,(src64),(dst64)
; CHECK-NEXT:  RSR
define void @zad64() nounwind {
  %v = load i64, ptr @src64, align 1
  store i64 %v, ptr @dst64, align 1
  ret void
}

; CHECK-LABEL: zad32_rr:
; CHECK:       ZAD 3,3,{{[A-Z]+}},{{[A-Z]+}}
; CHECK-NEXT:  RSR
define void @zad32_rr(ptr %s, ptr %d) nounwind {
  %v = load i32, ptr %s, align 1
  store i32 %v, ptr %d, align 1
  ret void
}

; Source and destination two bytes apart overlap. A byte-serial ZAD would not
; match load-then-store, so this stays as loads and stores.
; CHECK-LABEL: zad32_overlap:
; CHECK-NOT:   ZAD
; CHECK:       RSR
define void @zad32_overlap(ptr %p) nounwind {
  %q = getelementptr i8, ptr %p, i16 2
  %v = load i32, ptr %p, align 1
  store i32 %v, ptr %q, align 1
  ret void
}

;===----------------------------------------------------------------------===;
; BNA / BNS: Dest := Dest op Src
;===----------------------------------------------------------------------===;

; CHECK-LABEL: bna32:
; CHECK:       BNA 3,3,(src32),(dst32)
; CHECK-NEXT:  RSR
define void @bna32() nounwind {
  %a = load i32, ptr @dst32, align 1
  %b = load i32, ptr @src32, align 1
  %c = add i32 %a, %b
  store i32 %c, ptr @dst32, align 1
  ret void
}

; Addition commutes, so the destination may be either operand.
; CHECK-LABEL: bna32_commuted:
; CHECK:       BNA 3,3,(src32),(dst32)
; CHECK-NEXT:  RSR
define void @bna32_commuted() nounwind {
  %a = load i32, ptr @src32, align 1
  %b = load i32, ptr @dst32, align 1
  %c = add i32 %a, %b
  store i32 %c, ptr @dst32, align 1
  ret void
}

; CHECK-LABEL: bna64:
; CHECK:       BNA 7,7,(src64),(dst64)
; CHECK-NEXT:  RSR
define void @bna64() nounwind {
  %a = load i64, ptr @dst64, align 1
  %b = load i64, ptr @src64, align 1
  %c = add i64 %a, %b
  store i64 %c, ptr @dst64, align 1
  ret void
}

; CHECK-LABEL: bna32_rr:
; CHECK:       BNA 3,3,{{[A-Z]+}},{{[A-Z]+}}
; CHECK-NEXT:  RSR
define void @bna32_rr(ptr %s, ptr %d) nounwind {
  %a = load i32, ptr %d, align 1
  %b = load i32, ptr %s, align 1
  %c = add i32 %a, %b
  store i32 %c, ptr %d, align 1
  ret void
}

; CHECK-LABEL: bns32:
; CHECK:       BNS 3,3,(src32),(dst32)
; CHECK-NEXT:  RSR
define void @bns32() nounwind {
  %a = load i32, ptr @dst32, align 1
  %b = load i32, ptr @src32, align 1
  %c = sub i32 %a, %b
  store i32 %c, ptr @dst32, align 1
  ret void
}

; CHECK-LABEL: bns64:
; CHECK:       BNS 7,7,(src64),(dst64)
; CHECK-NEXT:  RSR
define void @bns64() nounwind {
  %a = load i64, ptr @dst64, align 1
  %b = load i64, ptr @src64, align 1
  %c = sub i64 %a, %b
  store i64 %c, ptr @dst64, align 1
  ret void
}

; CHECK-LABEL: bns32_rr:
; CHECK:       BNS 3,3,{{[A-Z]+}},{{[A-Z]+}}
; CHECK-NEXT:  RSR
define void @bns32_rr(ptr %s, ptr %d) nounwind {
  %a = load i32, ptr %d, align 1
  %b = load i32, ptr %s, align 1
  %c = sub i32 %a, %b
  store i32 %c, ptr %d, align 1
  ret void
}

; Src - Dest would need a reversed subtract, which BNS does not do.
; CHECK-LABEL: bns32_reversed:
; CHECK-NOT:   BNS
; CHECK:       RSR
define void @bns32_reversed() nounwind {
  %a = load i32, ptr @src32, align 1
  %b = load i32, ptr @dst32, align 1
  %c = sub i32 %a, %b
  store i32 %c, ptr @dst32, align 1
  ret void
}

; A store between the loads could change what they read.
; CHECK-LABEL: bna32_store_between:
; CHECK-NOT:   BNA
; CHECK:       RSR
define void @bna32_store_between(ptr %p) nounwind {
  %a = load i32, ptr @src32, align 1
  store i32 7, ptr %p, align 1
  %b = load i32, ptr @dst32, align 1
  %c = add i32 %b, %a
  store i32 %c, ptr @dst32, align 1
  ret void
}

;===----------------------------------------------------------------------===;
; BNC: flags of Dest - Src. == and != read V, unsigned order reads Link
; (set means no borrow). Dest is the left operand of >= and <, and the right
; operand of > and <=.
;===----------------------------------------------------------------------===;

; CHECK-LABEL: eq32:
; CHECK:       BNC 3,3,(dst32),(src32)
; CHECK-NEXT:  BZ
define i1 @eq32() nounwind {
  %a = load i32, ptr @src32, align 1
  %b = load i32, ptr @dst32, align 1
  %c = icmp eq i32 %a, %b
  ret i1 %c
}

; CHECK-LABEL: ne32:
; CHECK:       BNC 3,3,(dst32),(src32)
; CHECK-NEXT:  BNZ
define i1 @ne32() nounwind {
  %a = load i32, ptr @src32, align 1
  %b = load i32, ptr @dst32, align 1
  %c = icmp ne i32 %a, %b
  ret i1 %c
}

; CHECK-LABEL: uge32:
; CHECK:       BNC 3,3,(dst32),(src32)
; CHECK-NEXT:  BL
define i1 @uge32() nounwind {
  %a = load i32, ptr @src32, align 1
  %b = load i32, ptr @dst32, align 1
  %c = icmp uge i32 %a, %b
  ret i1 %c
}

; CHECK-LABEL: ult32:
; CHECK:       BNC 3,3,(dst32),(src32)
; CHECK-NEXT:  BNL
define i1 @ult32() nounwind {
  %a = load i32, ptr @src32, align 1
  %b = load i32, ptr @dst32, align 1
  %c = icmp ult i32 %a, %b
  ret i1 %c
}

; a <= b is b >= a, so the operands swap.
; CHECK-LABEL: ule32:
; CHECK:       BNC 3,3,(src32),(dst32)
; CHECK-NEXT:  BL
define i1 @ule32() nounwind {
  %a = load i32, ptr @src32, align 1
  %b = load i32, ptr @dst32, align 1
  %c = icmp ule i32 %a, %b
  ret i1 %c
}

; CHECK-LABEL: ugt32:
; CHECK:       BNC 3,3,(src32),(dst32)
; CHECK-NEXT:  BNL
define i1 @ugt32() nounwind {
  %a = load i32, ptr @src32, align 1
  %b = load i32, ptr @dst32, align 1
  %c = icmp ugt i32 %a, %b
  ret i1 %c
}

; CHECK-LABEL: eq64:
; CHECK:       BNC 7,7,(dst64),(src64)
; CHECK-NEXT:  BZ
define i1 @eq64() nounwind {
  %a = load i64, ptr @src64, align 1
  %b = load i64, ptr @dst64, align 1
  %c = icmp eq i64 %a, %b
  ret i1 %c
}

; CHECK-LABEL: eq32_rr:
; CHECK:       BNC 3,3,{{[A-Z]+}},{{[A-Z]+}}
; CHECK-NEXT:  BZ
define i1 @eq32_rr(ptr %p, ptr %q) nounwind {
  %a = load i32, ptr %p, align 1
  %b = load i32, ptr %q, align 1
  %c = icmp eq i32 %a, %b
  ret i1 %c
}

; BNC has no signed form.
; CHECK-LABEL: slt32:
; CHECK-NOT:   BNC
; CHECK:       RSR
define i1 @slt32() nounwind {
  %a = load i32, ptr @src32, align 1
  %b = load i32, ptr @dst32, align 1
  %c = icmp slt i32 %a, %b
  ret i1 %c
}

;===----------------------------------------------------------------------===;
; ZSU: Dest := -Src. M: Dest := Dest * Src. D: Dest := Dest / Src (signed).
; DRM: the quotient goes to Dest and the remainder to the address in A.
; All were run on the machine with 4 and 8 bytes and negative values, with the
; source and destination at one address too, so these fold whether or not the
; two are the same. DRM puts the remainder after the quotient, but writing both
; to one address gave +1 for -22 % 7, so DRM always sends the quotient to a
; temporary. The remainder over the divisor was right for every sign.
;===----------------------------------------------------------------------===;

@a32 = global i32 3
@b32 = global i32 4
@c32 = global i32 5
@a64 = global i64 6

; CHECK-LABEL: zsu32:
; CHECK:       ZSU 3,3,(src32),(dst32)
; CHECK-NEXT:  RSR
define void @zsu32() nounwind {
  %a = load i32, ptr @src32, align 1
  %n = sub i32 0, %a
  store i32 %n, ptr @dst32, align 1
  ret void
}

; CHECK-LABEL: m32:
; CHECK:       M 3,3,(src32),(dst32)
; CHECK-NEXT:  RSR
define void @m32() nounwind {
  %a = load i32, ptr @dst32, align 1
  %b = load i32, ptr @src32, align 1
  %c = mul i32 %a, %b
  store i32 %c, ptr @dst32, align 1
  ret void
}

; Multiplication commutes, so the destination may be either operand.
; CHECK-LABEL: m32_commuted:
; CHECK:       M 3,3,(src32),(dst32)
; CHECK-NEXT:  RSR
define void @m32_commuted() nounwind {
  %a = load i32, ptr @src32, align 1
  %b = load i32, ptr @dst32, align 1
  %c = mul i32 %a, %b
  store i32 %c, ptr @dst32, align 1
  ret void
}

; CHECK-LABEL: d32:
; CHECK:       D 3,3,(src32),(dst32)
; CHECK-NEXT:  RSR
define void @d32() nounwind {
  %a = load i32, ptr @dst32, align 1
  %b = load i32, ptr @src32, align 1
  %c = sdiv i32 %a, %b
  store i32 %c, ptr @dst32, align 1
  ret void
}

; The remainder lands where A points, so A is set last, after the dividend
; has been copied to the temporary that takes the quotient.
; CHECK-LABEL: drm32:
; CHECK:       ZAD 3,3,{{[A-Z]+}},{{[A-Z]+}}
; CHECK-NEXT:  XFR A,c32
; CHECK-NEXT:  DRM 3,3,{{[B-Z]}},{{[B-Z]}}
define void @drm32() nounwind {
  %a = load i32, ptr @a32, align 1
  %b = load i32, ptr @b32, align 1
  %r = srem i32 %a, %b
  store i32 %r, ptr @c32, align 1
  ret void
}

; The same address, and pointers that may be equal at run time, were run for M.
; CHECK-LABEL: m32_self:
; CHECK:       M 3,3,(dst32),(dst32)
; CHECK-NEXT:  RSR
define void @m32_self() nounwind {
  %a = load i32, ptr @dst32, align 1
  %c = mul i32 %a, %a
  store i32 %c, ptr @dst32, align 1
  ret void
}

; CHECK-LABEL: m32_rr:
; CHECK:       M 3,3,{{[A-Z]+}},{{[A-Z]+}}
define void @m32_rr(ptr %p, ptr %q) nounwind {
  %a = load i32, ptr %p, align 1
  %b = load i32, ptr %q, align 1
  %c = mul i32 %a, %b
  store i32 %c, ptr %p, align 1
  ret void
}

; A dividend that is also the destination keeps its quotient in a temporary,
; and then the remainder goes to the destination.
; CHECK-LABEL: drm32_in_place:
; CHECK:       ZAD 3,3,
; CHECK:       DRM 3,3,
; CHECK-NEXT:  INR S,3
; CHECK-NEXT:  RSR
define void @drm32_in_place() nounwind {
  %a = load i32, ptr @dst32, align 1
  %b = load i32, ptr @src32, align 1
  %r = srem i32 %a, %b
  store i32 %r, ptr @dst32, align 1
  ret void
}

; 8-byte operands.
; CHECK-LABEL: zsu64:
; CHECK:       ZSU 7,7,(src64),(dst64)
; CHECK-NEXT:  RSR
define void @zsu64() nounwind {
  %a = load i64, ptr @src64, align 1
  %n = sub i64 0, %a
  store i64 %n, ptr @dst64, align 1
  ret void
}

; CHECK-LABEL: m64:
; CHECK:       M 7,7,(src64),(dst64)
; CHECK-NEXT:  RSR
define void @m64() nounwind {
  %a = load i64, ptr @dst64, align 1
  %b = load i64, ptr @src64, align 1
  %c = mul i64 %a, %b
  store i64 %c, ptr @dst64, align 1
  ret void
}

; CHECK-LABEL: d64:
; CHECK:       D 7,7,(src64),(dst64)
; CHECK-NEXT:  RSR
define void @d64() nounwind {
  %a = load i64, ptr @dst64, align 1
  %b = load i64, ptr @src64, align 1
  %c = sdiv i64 %a, %b
  store i64 %c, ptr @dst64, align 1
  ret void
}

; CHECK-LABEL: drm64:
; CHECK:       ZAD 7,7,
; CHECK:       DRM 7,7,
define void @drm64() nounwind {
  %a = load i64, ptr @src64, align 1
  %b = load i64, ptr @dst64, align 1
  %r = srem i64 %a, %b
  store i64 %r, ptr @a64, align 1
  ret void
}

; CHECK-LABEL: m64_self:
; CHECK:       M 7,7,(dst64),(dst64)
; CHECK-NEXT:  RSR
define void @m64_self() nounwind {
  %a = load i64, ptr @dst64, align 1
  %c = mul i64 %a, %a
  store i64 %c, ptr @dst64, align 1
  ret void
}

; CHECK-LABEL: m64_rr:
; CHECK:       M 7,7,{{[A-Z]+}},{{[A-Z]+}}
define void @m64_rr(ptr %p, ptr %q) nounwind {
  %a = load i64, ptr %p, align 1
  %b = load i64, ptr %q, align 1
  %c = mul i64 %a, %b
  store i64 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: zsu32_in_place:
; CHECK:       ZSU 3,3,(dst32),(dst32)
; CHECK-NEXT:  RSR
define void @zsu32_in_place() nounwind {
  %a = load i32, ptr @dst32, align 1
  %n = sub i32 0, %a
  store i32 %n, ptr @dst32, align 1
  ret void
}

; CHECK-LABEL: zsu32_rr:
; CHECK:       ZSU 3,3,{{[A-Z]+}},{{[A-Z]+}}
define void @zsu32_rr(ptr %d, ptr %s) nounwind {
  %a = load i32, ptr %s, align 1
  %n = sub i32 0, %a
  store i32 %n, ptr %d, align 1
  ret void
}

; CHECK-LABEL: d32_rr:
; CHECK:       D 3,3,{{[A-Z]+}},{{[A-Z]+}}
define void @d32_rr(ptr %p, ptr %q) nounwind {
  %a = load i32, ptr %p, align 1
  %b = load i32, ptr %q, align 1
  %c = sdiv i32 %a, %b
  store i32 %c, ptr %p, align 1
  ret void
}

; The remainder may go over the divisor, for any pair of pointers.
; CHECK-LABEL: drm32_rr:
; CHECK:       ZAD 3,3,
; CHECK:       DRM 3,3,
define void @drm32_rr(ptr %r, ptr %a, ptr %b) nounwind {
  %x = load i32, ptr %a, align 1
  %y = load i32, ptr %b, align 1
  %z = srem i32 %x, %y
  store i32 %z, ptr %r, align 1
  ret void
}

; CHECK-LABEL: drm32_over_divisor:
; CHECK:       ZAD 3,3,
; CHECK:       DRM 3,3,
define void @drm32_over_divisor() nounwind {
  %a = load i32, ptr @dst32, align 1
  %b = load i32, ptr @src32, align 1
  %r = srem i32 %a, %b
  store i32 %r, ptr @src32, align 1
  ret void
}

; CHECK-LABEL: drm64_rr:
; CHECK:       ZAD 7,7,
; CHECK:       DRM 7,7,
define void @drm64_rr(ptr %r, ptr %a, ptr %b) nounwind {
  %x = load i64, ptr %a, align 1
  %y = load i64, ptr %b, align 1
  %z = srem i64 %x, %y
  store i64 %z, ptr %r, align 1
  ret void
}

; A negate whose result overlaps its source by two bytes stays as loads and
; stores.
; CHECK-LABEL: zsu32_overlap:
; CHECK-NOT:   ZSU
; CHECK:       RSR
define void @zsu32_overlap(ptr %p) nounwind {
  %q = getelementptr i8, ptr %p, i16 2
  %a = load i32, ptr %p, align 1
  %n = sub i32 0, %a
  store i32 %n, ptr %q, align 1
  ret void
}
