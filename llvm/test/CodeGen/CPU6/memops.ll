; Block copies and fills become MVF/FIL/MVFR. A variable length uses an
; MVFR chunk loop, or under optsize a post-increment byte loop. memmove
; that may overlap copies backward with LDAB_D/STAB_D. Dynamic alloca
; keeps X as the frame pointer.
;
; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck --check-prefix=NOLIB %s
;
; NOLIB-NOT: memcpy
; NOLIB-NOT: memmove
; NOLIB-NOT: memset

@ga = global [16 x i8] zeroinitializer
@gb = global [16 x i8] zeroinitializer

; CHECK-LABEL: cpy2:
; CHECK: MVF 1,B,A
; CHECK: RSR
define void @cpy2(ptr %d, ptr %s) nounwind {
  call void @llvm.memcpy.p0.p0.i16(ptr %d, ptr %s, i16 2, i1 false)
  ret void
}

; Two 256-byte chunks. The first count byte is 255, printed as -1.
; CHECK-LABEL: cpy300:
; CHECK: MVF -1,B,A
; CHECK: ADD A,A,256
; CHECK: ADD B,B,256
; CHECK: MVF 43,B,A
; CHECK: RSR
define void @cpy300(ptr %d, ptr %s) nounwind {
  call void @llvm.memcpy.p0.p0.i16(ptr %d, ptr %s, i16 300, i1 false)
  ret void
}

; Four inline MVF blocks is the constant-size cap.
; CHECK-LABEL: cpy1024:
; CHECK: MVF -1,B,A
; CHECK: MVF -1
; CHECK: MVF -1
; CHECK: MVF -1,B,A
; CHECK: RSR
define void @cpy1024(ptr %d, ptr %s) nounwind {
  call void @llvm.memcpy.p0.p0.i16(ptr %d, ptr %s, i16 1024, i1 false)
  ret void
}

; One byte past the cap uses the same MVFR loop as a variable length.
; CHECK-LABEL: cpy1025:
; CHECK: MVFR
; CHECK: RSR
define void @cpy1025(ptr %d, ptr %s) nounwind {
  call void @llvm.memcpy.p0.p0.i16(ptr %d, ptr %s, i16 1025, i1 false)
  ret void
}

; CHECK-LABEL: cpyglob:
; CHECK: MVF 15,B,A
; CHECK: RSR
define void @cpyglob() nounwind {
  call void @llvm.memcpy.p0.p0.i16(ptr @ga, ptr @gb, i16 16, i1 false)
  ret void
}

; CHECK-LABEL: cpyvar:
; CHECK: SUB {{.*}},256
; CHECK: MVFR
; CHECK: ADD {{.*}},256
; CHECK: MVFR
; CHECK: RSR
define void @cpyvar(ptr %d, ptr %s, i16 %n) nounwind {
  call void @llvm.memcpy.p0.p0.i16(ptr %d, ptr %s, i16 %n, i1 false)
  ret void
}

; CHECK-LABEL: cpyvar_os:
; CHECK: LDAB_I
; CHECK: STAB_I
; CHECK: DCR
; CHECK: BNZ
; CHECK-NOT: MVFR
; CHECK: RSR
define void @cpyvar_os(ptr %d, ptr %s, i16 %n) nounwind optsize {
  call void @llvm.memcpy.p0.p0.i16(ptr %d, ptr %s, i16 %n, i1 false)
  ret void
}

; CHECK-LABEL: set0:
; CHECK: FIL 9,0,A
; CHECK: RSR
define void @set0(ptr %d) nounwind {
  call void @llvm.memset.p0.i16(ptr %d, i8 0, i16 10, i1 false)
  ret void
}

; A non-constant byte is stored once and copied forward onto itself.
; CHECK-LABEL: setv:
; CHECK: STAB
; CHECK: MVF 8
; CHECK: RSR
define void @setv(ptr %d, i8 %v) nounwind {
  call void @llvm.memset.p0.i16(ptr %d, i8 %v, i16 10, i1 false)
  ret void
}

; CHECK-LABEL: setvar:
; CHECK: STAB
; CHECK: MVFR
; CHECK: RSR
define void @setvar(ptr %d, i8 %v, i16 %n) nounwind {
  call void @llvm.memset.p0.i16(ptr %d, i8 %v, i16 %n, i1 false)
  ret void
}

; Destination is below the source, so a forward MVF is enough.
; CHECK-LABEL: movdown:
; CHECK: MVF 19
; CHECK-NOT: LDAB_D
; CHECK: RSR
define void @movdown(ptr %p) nounwind {
  %s = getelementptr i8, ptr %p, i16 4
  call void @llvm.memmove.p0.p0.i16(ptr %p, ptr %s, i16 20, i1 false)
  ret void
}

; Distinct objects cannot overlap.
; CHECK-LABEL: movglob:
; CHECK: MVF 15,B,A
; CHECK: RSR
define void @movglob() nounwind {
  call void @llvm.memmove.p0.p0.i16(ptr @ga, ptr @gb, i16 16, i1 false)
  ret void
}

; Destination is above the source. The inserter keeps a backward byte loop.
; CHECK-LABEL: movup:
; CHECK: LDAB_D
; CHECK: STAB_D
; CHECK: RSR
define void @movup(ptr %p) nounwind {
  %d = getelementptr i8, ptr %p, i16 4
  call void @llvm.memmove.p0.p0.i16(ptr %d, ptr %p, i16 20, i1 false)
  ret void
}

; Unknown overlap: compare the pointers, then backward or the MVFR loop.
; CHECK-LABEL: movvar:
; CHECK: SUB
; CHECK: BL
; CHECK: LDAB_D
; CHECK: STAB_D
; CHECK: MVFR
; CHECK: RSR
define void @movvar(ptr %d, ptr %s, i16 %n) nounwind {
  call void @llvm.memmove.p0.p0.i16(ptr %d, ptr %s, i16 %n, i1 false)
  ret void
}

; CHECK-LABEL: movvar_os:
; CHECK: LDAB_D
; CHECK: STAB_D
; CHECK: LDAB_I
; CHECK: STAB_I
; CHECK-NOT: MVFR
; CHECK: RSR
define void @movvar_os(ptr %d, ptr %s, i16 %n) nounwind optsize {
  call void @llvm.memmove.p0.p0.i16(ptr %d, ptr %s, i16 %n, i1 false)
  ret void
}

declare void @use(ptr)

; CHECK-LABEL: dyn:
; CHECK: STK X
; CHECK: XFR S,X
; CHECK: SUB S,A
; CHECK: XAS
; CHECK: JSR (use)
; CHECK: XFR X,S
; CHECK: POP X
; CHECK: RSR
define void @dyn(i16 %n) nounwind {
  %p = alloca i8, i16 %n
  call void @use(ptr %p)
  ret void
}

; A fixed slot lives at a negative offset from X while S holds the alloca.
; CHECK-LABEL: dynlocal:
; CHECK: XFR S,X
; CHECK: STR B,(X),-2
; CHECK: SUB S,A
; CHECK: XAS
; CHECK: JSR (use)
; CHECK: XFR (X),A,-2
; CHECK: XFR X,S
; CHECK: RSR
define i16 @dynlocal(i16 %n, i16 %a) nounwind {
  %l = alloca i16
  store i16 %a, ptr %l
  %p = alloca i8, i16 %n
  call void @use(ptr %p)
  %v = load i16, ptr %l
  ret i16 %v
}

; CHECK-LABEL: dynsave:
; CHECK: XFR S,X
; CHECK: XFR S,Y
; CHECK: SUB S,A
; CHECK: AND A,A,-4
; CHECK: XAS
; CHECK: JSR (use)
; CHECK: XFR Y,S
; CHECK: XFR X,S
; CHECK: RSR
define void @dynsave(i16 %n) nounwind {
  %sp = call ptr @llvm.stacksave.p0()
  %p = alloca i8, i16 %n, align 4
  call void @use(ptr %p)
  call void @llvm.stackrestore.p0(ptr %sp)
  ret void
}
