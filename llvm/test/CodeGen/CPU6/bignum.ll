; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; Opcode 0x46 selection. The two length operands are length-1: 3 is a 4-byte
; (i32) operand, 7 an 8-byte (i64) one, and 15 a 16-byte (i128) one. Two
; globals select the address/address form. A single-use frame slot or a
; register plus a nonzero signed byte selects the indexed form. A bare
; pointer, or an address used by more than one of these operations, stays a
; register.

@src32 = global i32 1
@dst32 = global i32 2
@src64 = global i64 1
@dst64 = global i64 2
@lit32 = global i32 0
@lit64 = global i64 0

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

; Dest is the subtrahend, so one BNS cannot run there. The minuend is copied
; into a slot, the subtract runs in the slot, and the slot is copied back.
; CHECK-LABEL: bns32_reversed:
; CHECK:       ZAD 3,3,
; CHECK:       BNS 3,3,
; CHECK:       ZAD 3,3,
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
; The quotient slot is used again by DRM, so it stays a register. Each global
; is used once, so it is the absolute side of the mixed form.
; CHECK:       ZAD 3,3,(a32),{{[B-Z]}}
; CHECK-NEXT:  XFR A,c32
; CHECK-NEXT:  DRM 3,3,(b32),{{[B-Z]}}
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

;===----------------------------------------------------------------------===;
; i128 is the same selectors with length 15. A destination that is neither
; operand, and is disjoint from both, is a copy of the left operand and then
; the operation. A multiply of two registers is M, not a call to __multi3.
;===----------------------------------------------------------------------===;

@src128 = global i128 1
@dst128 = global i128 2
@a128 = global i128 3
@b128 = global i128 4
@c128 = global i128 5

; CHECK-LABEL: zad128:
; CHECK:       ZAD 15,15,(src128),(dst128)
; CHECK-NEXT:  RSR
define void @zad128() nounwind {
  %v = load i128, ptr @src128, align 1
  store i128 %v, ptr @dst128, align 1
  ret void
}

; CHECK-LABEL: bna128:
; CHECK:       BNA 15,15,(src128),(dst128)
; CHECK-NEXT:  RSR
define void @bna128() nounwind {
  %a = load i128, ptr @dst128, align 1
  %b = load i128, ptr @src128, align 1
  %c = add i128 %a, %b
  store i128 %c, ptr @dst128, align 1
  ret void
}

; CHECK-LABEL: bns128:
; CHECK:       BNS 15,15,(src128),(dst128)
; CHECK-NEXT:  RSR
define void @bns128() nounwind {
  %a = load i128, ptr @dst128, align 1
  %b = load i128, ptr @src128, align 1
  %c = sub i128 %a, %b
  store i128 %c, ptr @dst128, align 1
  ret void
}

; CHECK-LABEL: zsu128:
; CHECK:       ZSU 15,15,(src128),(dst128)
; CHECK-NEXT:  RSR
define void @zsu128() nounwind {
  %a = load i128, ptr @src128, align 1
  %n = sub i128 0, %a
  store i128 %n, ptr @dst128, align 1
  ret void
}

; CHECK-LABEL: m128:
; CHECK:       M 15,15,(src128),(dst128)
; CHECK-NEXT:  RSR
define void @m128() nounwind {
  %a = load i128, ptr @dst128, align 1
  %b = load i128, ptr @src128, align 1
  %c = mul i128 %a, %b
  store i128 %c, ptr @dst128, align 1
  ret void
}

; CHECK-LABEL: d128:
; CHECK:       D 15,15,(src128),(dst128)
; CHECK-NEXT:  RSR
define void @d128() nounwind {
  %a = load i128, ptr @dst128, align 1
  %b = load i128, ptr @src128, align 1
  %c = sdiv i128 %a, %b
  store i128 %c, ptr @dst128, align 1
  ret void
}

; CHECK-LABEL: drm128:
; CHECK:       ZAD 15,15,(a128),{{[B-Z]}}
; CHECK-NEXT:  XFR A,c128
; CHECK-NEXT:  DRM 15,15,(b128),{{[B-Z]}}
define void @drm128() nounwind {
  %a = load i128, ptr @a128, align 1
  %b = load i128, ptr @b128, align 1
  %r = srem i128 %a, %b
  store i128 %r, ptr @c128, align 1
  ret void
}

; CHECK-LABEL: eq128:
; CHECK:       BNC 15,15,(dst128),(src128)
; CHECK-NEXT:  BZ
define i1 @eq128() nounwind {
  %a = load i128, ptr @src128, align 1
  %b = load i128, ptr @dst128, align 1
  %c = icmp eq i128 %a, %b
  ret i1 %c
}

; CHECK-LABEL: ult128:
; CHECK:       BNC 15,15,(dst128),(src128)
; CHECK-NEXT:  BNL
define i1 @ult128() nounwind {
  %a = load i128, ptr @src128, align 1
  %b = load i128, ptr @dst128, align 1
  %c = icmp ult i128 %a, %b
  ret i1 %c
}

; Signed order stays a word compare.
; CHECK-LABEL: slt128:
; CHECK-NOT:   BNC
; CHECK:       RSR
define i1 @slt128() nounwind {
  %a = load i128, ptr @src128, align 1
  %b = load i128, ptr @dst128, align 1
  %c = icmp slt i128 %a, %b
  ret i1 %c
}

; The store is neither operand, and the three pointers cannot alias.
; CHECK-LABEL: m32_disjoint:
; CHECK:       ZAD 3,3,A,Y
; CHECK-NEXT:  M 3,3,B,Y
; CHECK-NEXT:  RSR
define void @m32_disjoint(ptr noalias %p, ptr noalias %q, ptr noalias %r) nounwind {
  %a = load i32, ptr %p, align 1
  %b = load i32, ptr %q, align 1
  %c = mul i32 %a, %b
  store i32 %c, ptr %r, align 1
  ret void
}

; CHECK-LABEL: m128_disjoint:
; CHECK:       ZAD 15,15,A,Y
; CHECK-NEXT:  M 15,15,B,Y
; CHECK-NEXT:  RSR
define void @m128_disjoint(ptr noalias %p, ptr noalias %q, ptr noalias %r) nounwind {
  %a = load i128, ptr %p, align 1
  %b = load i128, ptr %q, align 1
  %c = mul i128 %a, %b
  store i128 %c, ptr %r, align 1
  ret void
}

; CHECK-LABEL: mul128_rr:
; CHECK-NOT:   JSR
; CHECK:       M 15,15,
; CHECK:       RSR
define void @mul128_rr(i128 %a, i128 %b, ptr %p) nounwind {
  %r = mul i128 %a, %b
  store i128 %r, ptr %p, align 1
  ret void
}

; Eight words of carry is a slot add, not the word chain.
; CHECK-LABEL: add128_rr:
; CHECK-NOT:   JSR
; CHECK:       BNA 15,15,
; CHECK:       RSR
define void @add128_rr(i128 %a, i128 %b, ptr %p) nounwind {
  %r = add i128 %a, %b
  store i128 %r, ptr %p, align 1
  ret void
}

;===----------------------------------------------------------------------===;
; Indexed and mixed operands. A one-shot local folds. An address reused by
; several operations does not: the adds stay, and each operation is RR.
;===----------------------------------------------------------------------===;

; CHECK-LABEL: local_add32:
; CHECK-NOT:   STK
; CHECK:       BNA 3,3,(S),0,(S),4
; CHECK-NEXT:  INR S,7
; CHECK-NEXT:  RSR
define void @local_add32() nounwind {
  %d = alloca i32, align 1
  %s = alloca i32, align 1
  %a = load i32, ptr %d, align 1
  %b = load i32, ptr %s, align 1
  %c = add i32 %a, %b
  store i32 %c, ptr %d, align 1
  ret void
}

; CHECK-LABEL: local_add64:
; CHECK:       BNA 7,7,(S),0,(S),8
; CHECK-NEXT:  INR S,15
; CHECK-NEXT:  RSR
define void @local_add64() nounwind {
  %d = alloca i64, align 1
  %s = alloca i64, align 1
  %a = load i64, ptr %d, align 1
  %b = load i64, ptr %s, align 1
  %c = add i64 %a, %b
  store i64 %c, ptr %d, align 1
  ret void
}

; CHECK-LABEL: local_add128:
; CHECK:       BNA 15,15,(S),0,(S),16
; CHECK-NEXT:  ADD S,S,32
; CHECK-NEXT:  RSR
define void @local_add128() nounwind {
  %d = alloca i128, align 1
  %s = alloca i128, align 1
  %a = load i128, ptr %d, align 1
  %b = load i128, ptr %s, align 1
  %c = add i128 %a, %b
  store i128 %c, ptr %d, align 1
  ret void
}

; CHECK-LABEL: locals_chain:
; CHECK:       ADD S,[[DST:[A-Z]+]],4
; CHECK:       ADD S,[[SRC:[A-Z]+]],0
; CHECK:       BNA 3,3,[[SRC]],[[DST]]
; CHECK:       BNS 3,3,[[SRC]],[[DST]]
; CHECK:       BNC 3,3,[[SRC]],[[DST]]
define i1 @locals_chain() nounwind {
  %d = alloca i32, align 1
  %s = alloca i32, align 1
  %a = load i32, ptr %d, align 1
  %b = load i32, ptr %s, align 1
  %sum = add i32 %a, %b
  store i32 %sum, ptr %d, align 1
  %a2 = load i32, ptr %d, align 1
  %b2 = load i32, ptr %s, align 1
  %diff = sub i32 %a2, %b2
  store i32 %diff, ptr %d, align 1
  %a3 = load i32, ptr %d, align 1
  %b3 = load i32, ptr %s, align 1
  %c = icmp eq i32 %a3, %b3
  ret i1 %c
}

; The limb at offset 0 is the pointer itself. Indexed with a displacement of
; 0 is larger than RR, so that limb stays two registers. The other two are
; single-use and fold. Nothing is saved just to hold an address.
; CHECK-LABEL: limbs:
; CHECK-NOT:   STK
; CHECK:       BNA 3,3,B,A
; CHECK-NEXT:  BNA 3,3,(B),4,(A),4
; CHECK-NEXT:  BNA 3,3,(B),8,(A),8
; CHECK-NEXT:  RSR
define void @limbs(ptr %a, ptr %b) nounwind {
  %a0 = load i32, ptr %a, align 1
  %b0 = load i32, ptr %b, align 1
  %s0 = add i32 %a0, %b0
  store i32 %s0, ptr %a, align 1
  %a4 = getelementptr i8, ptr %a, i16 4
  %b4 = getelementptr i8, ptr %b, i16 4
  %a1 = load i32, ptr %a4, align 1
  %b1 = load i32, ptr %b4, align 1
  %s1 = add i32 %a1, %b1
  store i32 %s1, ptr %a4, align 1
  %a8 = getelementptr i8, ptr %a, i16 8
  %b8 = getelementptr i8, ptr %b, i16 8
  %a2 = load i32, ptr %a8, align 1
  %b2 = load i32, ptr %b8, align 1
  %s2 = add i32 %a2, %b2
  store i32 %s2, ptr %a8, align 1
  ret void
}

; CHECK-LABEL: two_ptrs:
; CHECK:       BNA 3,3,{{[A-Z]+}},{{[A-Z]+}}
; CHECK-NEXT:  RSR
define void @two_ptrs(ptr %p, ptr %q) nounwind {
  %a = load i32, ptr %q, align 1
  %b = load i32, ptr %p, align 1
  %c = add i32 %a, %b
  store i32 %c, ptr %q, align 1
  ret void
}

; CHECK-LABEL: global_ptr:
; CHECK:       BNA 3,3,(src32),A
; CHECK-NEXT:  RSR
define void @global_ptr(ptr %p) nounwind {
  %a = load i32, ptr @src32, align 1
  %b = load i32, ptr %p, align 1
  %c = add i32 %b, %a
  store i32 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: ptr_global:
; CHECK:       BNA 3,3,A,(dst32)
; CHECK-NEXT:  RSR
define void @ptr_global(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %b = load i32, ptr @dst32, align 1
  %c = add i32 %b, %a
  store i32 %c, ptr @dst32, align 1
  ret void
}

; 200 does not fit in the indexed byte. The adds stay, and the operation is RR.
; CHECK-LABEL: disp200:
; CHECK:       ADD {{[A-Z]+}},{{[A-Z]+}},200
; CHECK:       ADD {{[A-Z]+}},{{[A-Z]+}},200
; CHECK-NOT:   ),
; CHECK:       BNA 3,3,{{[A-Z]+}},{{[A-Z]+}}
; CHECK-NEXT:  RSR
define void @disp200(ptr %p, ptr %q) nounwind {
  %pp = getelementptr i8, ptr %p, i16 200
  %qq = getelementptr i8, ptr %q, i16 200
  %a = load i32, ptr %qq, align 1
  %b = load i32, ptr %pp, align 1
  %c = add i32 %a, %b
  store i32 %c, ptr %qq, align 1
  ret void
}

; The byte array has to stay nearest S: a byte displacement has no fallback.
; The i32 slots are past the signed byte, so each becomes ADD plus a register.
; CHECK-LABEL: byte_window:
; CHECK:       STAB (S),0
; CHECK:       ADD S,[[BW_S:[A-Z]+]],200
; CHECK:       ADD S,[[BW_D:[A-Z]+]],204
; CHECK:       BNA 3,3,[[BW_S]],[[BW_D]]
define void @byte_window() nounwind {
  %buf = alloca [200 x i8], align 1
  %d = alloca i32, align 1
  %s = alloca i32, align 1
  store volatile i8 1, ptr %buf, align 1
  %a = load i32, ptr %d, align 1
  %b = load i32, ptr %s, align 1
  %c = add i32 %a, %b
  store i32 %c, ptr %d, align 1
  ret void
}

; A word object can sit anywhere. It is placed further from S than the bignum
; slots, so those slots stay inside the signed byte and fold.
; CHECK-LABEL: far_word:
; CHECK:       BNA 3,3,(S),0,(S),4
define void @far_word() nounwind {
  %big = alloca [200 x i16], align 1
  %d = alloca i32, align 1
  %s = alloca i32, align 1
  store i16 1, ptr %big, align 1
  %a = load i32, ptr %d, align 1
  %b = load i32, ptr %s, align 1
  %c = add i32 %a, %b
  store i32 %c, ptr %d, align 1
  ret void
}

;===----------------------------------------------------------------------===;
; Literal source. CenREE sign-extends the inline byte and adds it at the low
; byte, so the constant has to fit in -128..127. 255 is -1, not 255. i16 is
; already one word. A constant outside the byte stays the carry chain.
;===----------------------------------------------------------------------===;

; CHECK-LABEL: lit_add32_1:
; CHECK:       BNA 3,1,A
; CHECK-NEXT:  RSR
define void @lit_add32_1(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = add i32 %a, 1
  store i32 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: lit_add32_5:
; CHECK:       BNA 3,5,A
; CHECK-NEXT:  RSR
define void @lit_add32_5(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = add i32 %a, 5
  store i32 %c, ptr %p, align 1
  ret void
}

; The constant may be the left operand. Addition commutes.
; CHECK-LABEL: lit_add32_5_commuted:
; CHECK:       BNA 3,5,A
; CHECK-NEXT:  RSR
define void @lit_add32_5_commuted(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = add i32 5, %a
  store i32 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: lit_sub32_5:
; CHECK:       BNS 3,5,A
; CHECK-NEXT:  RSR
define void @lit_sub32_5(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = sub i32 %a, 5
  store i32 %c, ptr %p, align 1
  ret void
}

; -1 and -128 are the sign-extended bytes 0xFF and 0x80. -5 subtracts as
; that byte, which adds 5.
; CHECK-LABEL: lit_add32_m1:
; CHECK:       BNA 3,-1,A
; CHECK-NEXT:  RSR
define void @lit_add32_m1(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = add i32 %a, -1
  store i32 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: lit_add32_m128:
; CHECK:       BNA 3,-128,A
; CHECK-NEXT:  RSR
define void @lit_add32_m128(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = add i32 %a, -128
  store i32 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: lit_sub32_m5:
; CHECK:       BNS 3,-5,A
; CHECK-NEXT:  RSR
define void @lit_sub32_m5(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = sub i32 %a, -5
  store i32 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: lit_add64_1:
; CHECK:       BNA 7,1,A
; CHECK-NEXT:  RSR
define void @lit_add64_1(ptr %p) nounwind {
  %a = load i64, ptr %p, align 1
  %c = add i64 %a, 1
  store i64 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: lit_add64_5:
; CHECK:       BNA 7,5,A
; CHECK-NEXT:  RSR
define void @lit_add64_5(ptr %p) nounwind {
  %a = load i64, ptr %p, align 1
  %c = add i64 %a, 5
  store i64 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: lit_sub64_5:
; CHECK:       BNS 7,5,A
; CHECK-NEXT:  RSR
define void @lit_sub64_5(ptr %p) nounwind {
  %a = load i64, ptr %p, align 1
  %c = sub i64 %a, 5
  store i64 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: lit_g32_5:
; CHECK:       BNA 3,5,(lit32)
; CHECK-NEXT:  RSR
define void @lit_g32_5() nounwind {
  %a = load i32, ptr @lit32, align 1
  %c = add i32 %a, 5
  store i32 %c, ptr @lit32, align 1
  ret void
}

; CHECK-LABEL: lit_g64_5:
; CHECK:       BNA 7,5,(lit64)
; CHECK-NEXT:  RSR
define void @lit_g64_5() nounwind {
  %a = load i64, ptr @lit64, align 1
  %c = add i64 %a, 5
  store i64 %c, ptr @lit64, align 1
  ret void
}

; CHECK-LABEL: lit_idx32:
; CHECK:       BNA 3,5,(A),4
; CHECK-NEXT:  RSR
define void @lit_idx32(ptr %p) nounwind {
  %q = getelementptr i8, ptr %p, i16 4
  %a = load i32, ptr %q, align 1
  %c = add i32 %a, 5
  store i32 %c, ptr %q, align 1
  ret void
}

; CHECK-LABEL: lit_local32:
; CHECK:       DCR S,3
; CHECK-NEXT:  BNA 3,5,(S),0
; CHECK-NEXT:  INR S,3
; CHECK-NEXT:  RSR
define void @lit_local32() nounwind {
  %p = alloca i32, align 1
  %a = load i32, ptr %p, align 1
  %c = add i32 %a, 5
  store i32 %c, ptr %p, align 1
  ret void
}

; The byte object sits nearest S. The i32 is 200 bytes further, past a signed
; byte, so the indexed literal widens to the 16-bit displacement.
; CHECK-LABEL: lit_far32:
; CHECK:       BNA 3,5,(S),(200)
; CHECK:       RSR
define void @lit_far32() nounwind {
  %big = alloca [200 x i8], align 1
  %p = alloca i32, align 1
  store i8 1, ptr %big, align 1
  %a = load i32, ptr %p, align 1
  %c = add i32 %a, 5
  store i32 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: lit_far_sub:
; CHECK:       BNS 3,5,(S),(200)
; CHECK:       RSR
define void @lit_far_sub() nounwind {
  %big = alloca [200 x i8], align 1
  %p = alloca i32, align 1
  store i8 1, ptr %big, align 1
  %a = load i32, ptr %p, align 1
  %c = sub i32 %a, 5
  store i32 %c, ptr %p, align 1
  ret void
}

; The value 5 is not materialized. The flag select moves 0 and 1.
; CHECK-LABEL: lit_eq32:
; CHECK:       BNC 3,5,{{[A-Z]}}
; CHECK:       BZ
; CHECK-NOT:   XFR {{[A-Z]}},5
; CHECK:       RSR
define i1 @lit_eq32(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = icmp eq i32 %a, 5
  ret i1 %c
}

; CHECK-LABEL: lit_ne32:
; CHECK:       BNC 3,5,{{[A-Z]}}
; CHECK:       BNZ
; CHECK:       RSR
define i1 @lit_ne32(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = icmp ne i32 %a, 5
  ret i1 %c
}

; CHECK-LABEL: lit_ult32:
; CHECK:       BNC 3,5,{{[A-Z]}}
; CHECK:       BNL
; CHECK:       RSR
define i1 @lit_ult32(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = icmp ult i32 %a, 5
  ret i1 %c
}

; icmp uge X, 5 is canonicalized to icmp ugt X, 4. That is BNC of 5: Link set
; means Dest >= 5.
; CHECK-LABEL: lit_uge32:
; CHECK:       BNC 3,5,{{[A-Z]}}
; CHECK:       BL
; CHECK:       RSR
define i1 @lit_uge32(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = icmp uge i32 %a, 5
  ret i1 %c
}

; CHECK-LABEL: lit_eq64:
; CHECK:       BNC 7,5,{{[A-Z]}}
; CHECK:       BZ
; CHECK:       RSR
define i1 @lit_eq64(ptr %p) nounwind {
  %a = load i64, ptr %p, align 1
  %c = icmp eq i64 %a, 5
  ret i1 %c
}

; CHECK-LABEL: lit_ult64:
; CHECK:       BNC 7,5,{{[A-Z]}}
; CHECK:       BNL
; CHECK:       RSR
define i1 @lit_ult64(ptr %p) nounwind {
  %a = load i64, ptr %p, align 1
  %c = icmp ult i64 %a, 5
  ret i1 %c
}

; -1 compares equal through the sign-extended byte. 255 does not: that byte
; is -1, so an unsigned 255 stays the word compare.
; CHECK-LABEL: lit_eq32_m1:
; CHECK:       BNC 3,-1,{{[A-Z]}}
; CHECK:       BZ
; CHECK:       RSR
define i1 @lit_eq32_m1(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = icmp eq i32 %a, -1
  ret i1 %c
}

; The compare's frame slot is past a signed byte, so BNC widens too.
; CHECK-LABEL: lit_far_eq:
; CHECK:       BNC 3,5,(S),(
; CHECK:       RSR
define i1 @lit_far_eq() nounwind {
  %big = alloca [200 x i8], align 1
  %p = alloca i32, align 1
  store i8 1, ptr %big, align 1
  %a = load i32, ptr %p, align 1
  %c = icmp eq i32 %a, 5
  ret i1 %c
}

; Stored somewhere else. The literal form only updates its destination.
; CHECK-LABEL: lit_not_inplace:
; CHECK-NOT:   BNA
; CHECK:       RSR
define void @lit_not_inplace(ptr %p, ptr %q) nounwind {
  %a = load i32, ptr %p, align 1
  %c = add i32 %a, 5
  store i32 %c, ptr %q, align 1
  ret void
}

; 300 and 255 do not fit in a signed byte. 255 would add -1.
; CHECK-LABEL: lit_add32_300:
; CHECK:       ADD X,C,300
; CHECK:       SUB C,X
; CHECK:       BL
; CHECK:       INR B,0
; CHECK:       RSR
define void @lit_add32_300(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = add i32 %a, 300
  store i32 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: lit_add32_255:
; CHECK:       ADD X,C,255
; CHECK-NOT:   BNA
; CHECK:       RSR
define void @lit_add32_255(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = add i32 %a, 255
  store i32 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: lit_add32_m256:
; CHECK:       ADD X,C,-256
; CHECK:       DCR B,0
; CHECK-NOT:   BNA
; CHECK:       RSR
define void @lit_add32_m256(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = add i32 %a, -256
  store i32 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: lit_add16_5:
; CHECK:       XFR (A),B,0
; CHECK-NEXT:  INR B,4
; CHECK-NEXT:  STR B,(A),0
; CHECK-NEXT:  RSR
define void @lit_add16_5(ptr %p) nounwind {
  %a = load i16, ptr %p, align 1
  %c = add i16 %a, 5
  store i16 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: lit_add16_1:
; CHECK:       XFR (A),B,0
; CHECK-NEXT:  INR B,0
; CHECK-NEXT:  STR B,(A),0
; CHECK-NEXT:  RSR
define void @lit_add16_1(ptr %p) nounwind {
  %a = load i16, ptr %p, align 1
  %c = add i16 %a, 1
  store i16 %c, ptr %p, align 1
  ret void
}

; CHECK-LABEL: lit_eq32_300:
; CHECK:       ORE A,C,300
; CHECK-NOT:   BNC
; CHECK:       RSR
define i1 @lit_eq32_300(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = icmp eq i32 %a, 300
  ret i1 %c
}

; CHECK-LABEL: lit_ult32_200:
; CHECK:       SUB X,X,199
; CHECK-NOT:   BNC
; CHECK:       RSR
define i1 @lit_ult32_200(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = icmp ult i32 %a, 200
  ret i1 %c
}

; ugt 127 would be uge 128, and that byte is -128. Both stay the word compare.
; CHECK-LABEL: lit_ugt127:
; CHECK-NOT:   BNC
; CHECK:       SUB
; CHECK:       RSR
define i1 @lit_ugt127(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = icmp ugt i32 %a, 127
  ret i1 %c
}

; CHECK-LABEL: lit_ule127:
; CHECK-NOT:   BNC
; CHECK:       SUB
; CHECK:       RSR
define i1 @lit_ule127(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = icmp ule i32 %a, 127
  ret i1 %c
}

; Signed order does not read the flags the same way.
; CHECK-LABEL: lit_slt32:
; CHECK-NOT:   BNC
; CHECK:       SUB
; CHECK:       RSR
define i1 @lit_slt32(ptr %p) nounwind {
  %a = load i32, ptr %p, align 1
  %c = icmp slt i32 %a, 5
  ret i1 %c
}
