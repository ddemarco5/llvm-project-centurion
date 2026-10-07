; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; memcmp. Two and four bytes compared with zero stay a word compare and
; BNC 3,3. Eight bytes is BNC 7,7. Any other constant length up to 256 is
; one CPF (count-1). A run-time length is CPFR, count-1 in AL, and a zero
; length does not compare. The value of a compare is -1, 0, or 1.

declare i16 @memcmp(ptr, ptr, i16)

@ga = global [8 x i8] zeroinitializer
@gb = global [8 x i8] zeroinitializer

; CHECK-LABEL: eq2:
; CHECK-NOT: CPF
; CHECK: SUB
; CHECK: BZ
; CHECK: RSR
define i1 @eq2(ptr %a, ptr %b) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 2)
  %r = icmp eq i16 %c, 0
  ret i1 %r
}

; CHECK-LABEL: eq4:
; CHECK-NOT: CPF
; CHECK: BNC 3,3
; CHECK: BZ
; CHECK: RSR
define i1 @eq4(ptr %a, ptr %b) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 4)
  %r = icmp eq i16 %c, 0
  ret i1 %r
}

; CHECK-LABEL: eq8:
; CHECK-NOT: CPF
; CHECK-NOT: JSR
; CHECK: BNC 7,7
; CHECK: BZ
; CHECK: RSR
define i1 @eq8(ptr %a, ptr %b) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 8)
  %r = icmp eq i16 %c, 0
  ret i1 %r
}

; CHECK-LABEL: eq5:
; CHECK: CPF 4,
; CHECK: BZ
; CHECK-NOT: JSR
; CHECK: RSR
define i1 @eq5(ptr %a, ptr %b) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 5)
  %r = icmp eq i16 %c, 0
  ret i1 %r
}

; CHECK-LABEL: eq7:
; CHECK: CPF 6,
; CHECK: BZ
; CHECK: RSR
define i1 @eq7(ptr %a, ptr %b) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 7)
  %r = icmp eq i16 %c, 0
  ret i1 %r
}

; CHECK-LABEL: eq9:
; CHECK: CPF 8,
; CHECK: BZ
; CHECK: RSR
define i1 @eq9(ptr %a, ptr %b) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 9)
  %r = icmp eq i16 %c, 0
  ret i1 %r
}

; CHECK-LABEL: eq16:
; CHECK: CPF 15,
; CHECK: BZ
; CHECK-NOT: JSR
; CHECK: RSR
define i1 @eq16(ptr %a, ptr %b) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 16)
  %r = icmp eq i16 %c, 0
  ret i1 %r
}

; CHECK-LABEL: eqglob:
; CHECK: CPF 4,(gb),(ga)
; CHECK: RSR
define i1 @eqglob() nounwind {
  %c = call i16 @memcmp(ptr @ga, ptr @gb, i16 5)
  %r = icmp eq i16 %c, 0
  ret i1 %r
}

; The displaced pointer is the destination of the compare.
; CHECK-LABEL: eqidx:
; CHECK: CPF 4,{{[A-Z]}},({{[A-Z]}}),4
; CHECK: RSR
define i1 @eqidx(ptr %a, ptr %b) nounwind {
  %p = getelementptr i8, ptr %a, i16 4
  %c = call i16 @memcmp(ptr %p, ptr %b, i16 5)
  %r = icmp eq i16 %c, 0
  ret i1 %r
}

; One slot folds. The other is a register: a CPF has a single index.
; CHECK-LABEL: eqlocal:
; CHECK: CPF 4,(S),0,{{[A-Z]}}
; CHECK: RSR
define i1 @eqlocal() nounwind {
  %a = alloca [5 x i8]
  %b = alloca [5 x i8]
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 5)
  %r = icmp eq i16 %c, 0
  ret i1 %r
}

; CHECK-LABEL: diff2:
; CHECK: SUB
; CHECK: BNL
; CHECK: CLR A,1
; CHECK: CLA
; CHECK: XFR A,65535
; CHECK-NOT: JSR
; CHECK: RSR
define i16 @diff2(ptr %a, ptr %b) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 2)
  ret i16 %c
}

; CHECK-LABEL: diff4:
; CHECK-NOT: CPF
; CHECK: BNC 3,3
; CHECK: BNL
; CHECK: CLR A,1
; CHECK: CLA
; CHECK: XFR A,65535
; CHECK-NOT: JSR
; CHECK: RSR
define i16 @diff4(ptr %a, ptr %b) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 4)
  ret i16 %c
}

; Minus, not Link: CPF's less-than flag is Minus.
; CHECK-LABEL: diff5:
; CHECK: CPF 4,
; CHECK: BM
; CHECK: CLR A,1
; CHECK: CLA
; CHECK: XFR A,65535
; CHECK-NOT: JSR
; CHECK: RSR
define i16 @diff5(ptr %a, ptr %b) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 5)
  ret i16 %c
}

; CHECK-LABEL: diff8:
; CHECK: BNC 7,7
; CHECK: BNL
; CHECK: XFR A,65535
; CHECK-NOT: JSR
; CHECK: RSR
define i16 @diff8(ptr %a, ptr %b) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 8)
  ret i16 %c
}

; A zero count returns 0 before any compare.
; CHECK-LABEL: eqvar:
; CHECK: BZ
; CHECK: CPFR
; CHECK: ADD {{[A-Z]}},{{[A-Z]}},-1
; CHECK: CPFR
; CHECK-NOT: JSR
; CHECK: RSR
define i1 @eqvar(ptr %a, ptr %b, i16 %n) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 %n)
  %r = icmp eq i16 %c, 0
  ret i1 %r
}

; CHECK-LABEL: eqvar_os:
; CHECK: LDAB_I
; CHECK: LDBB_I
; CHECK: SUBB
; CHECK: BNZ
; CHECK-NOT: CPFR
; CHECK: RSR
define i1 @eqvar_os(ptr %a, ptr %b, i16 %n) nounwind optsize {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 %n)
  %r = icmp eq i16 %c, 0
  ret i1 %r
}

; CHECK-LABEL: diffvar:
; CHECK: CPFR
; CHECK: ADD {{[A-Z]}},{{[A-Z]}},-1
; CHECK: CPFR
; CHECK: XFR A,65535
; CHECK: CLR A,1
; CHECK-NOT: JSR
; CHECK: RSR
define i16 @diffvar(ptr %a, ptr %b, i16 %n) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 %n)
  ret i16 %c
}

; CHECK-LABEL: zero:
; CHECK-NOT: CPF
; CHECK: CLA
; CHECK: RSR
define i16 @zero(ptr %a, ptr %b) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 0)
  ret i16 %c
}

; Past 256 bytes the compare is the same loop, not one CPF.
; CHECK-LABEL: eq300:
; CHECK: CPFR
; CHECK-NOT: {{CPF }}
; CHECK: RSR
define i1 @eq300(ptr %a, ptr %b) nounwind {
  %c = call i16 @memcmp(ptr %a, ptr %b, i16 300)
  %r = icmp eq i16 %c, 0
  ret i1 %r
}
