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
; CHECK: MVF 15,(gb),(ga)
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
; CHECK: MVF 15,(gb),(ga)
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

@gz = global [32 x i8] zeroinitializer
@ga1k = global [1024 x i8] zeroinitializer
@gb1k = global [1024 x i8] zeroinitializer

; A global fill is one absolute FIL. No address register.
; CHECK-LABEL: setglob:
; CHECK: FIL 31,0,(gz)
; CHECK: RSR
define void @setglob() nounwind {
  call void @llvm.memset.p0.i16(ptr @gz, i8 0, i16 32, i1 false)
  ret void
}

; Each 256-byte chunk names the global plus its offset. No running ADD.
; CHECK-LABEL: cpyglob1k:
; CHECK: MVF -1,(gb1k),(ga1k)
; CHECK-NOT: ADD
; CHECK: MVF -1,(gb1k+256),(ga1k+256)
; CHECK-NOT: ADD
; CHECK: MVF -1,(gb1k+512),(ga1k+512)
; CHECK-NOT: ADD
; CHECK: MVF -1,(gb1k+768),(ga1k+768)
; CHECK-NOT: ADD
; CHECK: RSR
define void @cpyglob1k() nounwind {
  call void @llvm.memcpy.p0.p0.i16(ptr @ga1k, ptr @gb1k, i16 1024, i1 false)
  ret void
}

; Both addresses are a register plus a signed byte.
; CHECK-LABEL: cpyfield:
; CHECK: MVF 15,(B),8,(A),4
; CHECK: RSR
define void @cpyfield(ptr %p, ptr %q) nounwind {
  %pd = getelementptr i8, ptr %p, i16 4
  %qd = getelementptr i8, ptr %q, i16 8
  call void @llvm.memcpy.p0.p0.i16(ptr %pd, ptr %qd, i16 16, i1 false)
  ret void
}

; One side is already the pointer register.
; CHECK-LABEL: cpyfield1:
; CHECK: MVF 15,B,(A),4
; CHECK: RSR
define void @cpyfield1(ptr %p, ptr %q) nounwind {
  %pd = getelementptr i8, ptr %p, i16 4
  call void @llvm.memcpy.p0.p0.i16(ptr %pd, ptr %q, i16 16, i1 false)
  ret void
}

; A local fill uses S and a displacement.
; CHECK-LABEL: setlocal:
; CHECK: FIL 31,0,(S),0
; CHECK: RSR
define void @setlocal() nounwind {
  %buf = alloca [32 x i8]
  call void @llvm.memset.p0.i16(ptr %buf, i8 0, i16 32, i1 false)
  ret void
}

; bulk sits between S and the filled buffer, so the displacement is 161 and
; the 8-bit form is widened. The byte store of the slot stays in range.
; CHECK-LABEL: setfar:
; CHECK: FIL 31,9,(S),(161)
; CHECK: STAB (S),0
; CHECK: RSR
define void @setfar() nounwind {
  %buf = alloca [32 x i8]
  %bulk = alloca [160 x i8]
  %slot = alloca i8
  call void @llvm.memset.p0.i16(ptr %buf, i8 9, i16 32, i1 false)
  store i8 1, ptr %slot
  store i16 2, ptr %bulk
  ret void
}

; A variable-sized object addresses the fixed slot from X.
; CHECK-LABEL: setdyn:
; CHECK: FIL 31,0,(X),-32
; CHECK: RSR
define void @setdyn(i16 %n) nounwind {
  %buf = alloca [32 x i8]
  %p = alloca i8, i16 %n
  call void @llvm.memset.p0.i16(ptr %buf, i8 0, i16 32, i1 false)
  call void @use(ptr %p)
  ret void
}
