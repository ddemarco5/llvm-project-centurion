; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s

; Post-increment and pre-decrement loads and stores. The stride is the access
; size, so the add disappears into LDA_I / LDA_D and the byte and B/X twins.
; A different stride, a post-decrement, and a pre-increment stay a separate add.

@g = global ptr null

; CHECK-LABEL: wpost:
; CHECK: {{LDA_I|LDB_I|LDX_I}}
; CHECK-NOT: INR
; CHECK: RSR
define i16 @wpost(ptr %p) {
  %v = load i16, ptr %p
  %n = getelementptr i16, ptr %p, i16 1
  store ptr %n, ptr @g
  ret i16 %v
}

; CHECK-LABEL: bpost:
; CHECK: {{LDAB_I|LDBB_I}}
; CHECK-NOT: INA
; CHECK-NOT: INR
; CHECK: RSR
define i8 @bpost(ptr %p) {
  %v = load i8, ptr %p
  %n = getelementptr i8, ptr %p, i16 1
  store ptr %n, ptr @g
  ret i8 %v
}

; CHECK-LABEL: wpre:
; CHECK: {{LDA_D|LDB_D|LDX_D}}
; CHECK-NOT: DCR
; CHECK: RSR
define i16 @wpre(ptr %p) {
  %n = getelementptr i16, ptr %p, i16 -1
  %v = load i16, ptr %n
  store ptr %n, ptr @g
  ret i16 %v
}

; CHECK-LABEL: bpre:
; CHECK: {{LDAB_D|LDBB_D}}
; CHECK-NOT: DCR
; CHECK: RSR
define i8 @bpre(ptr %p) {
  %n = getelementptr i8, ptr %p, i16 -1
  %v = load i8, ptr %n
  store ptr %n, ptr @g
  ret i8 %v
}

; CHECK-LABEL: wstore:
; CHECK: {{STA_I|STB_I|STX_I}}
; CHECK-NOT: INR
; CHECK: RSR
define void @wstore(ptr %p, i16 %v) {
  store i16 %v, ptr %p
  %n = getelementptr i16, ptr %p, i16 1
  store ptr %n, ptr @g
  ret void
}

; CHECK-LABEL: bstore:
; CHECK: {{STAB_I|STBB_I}}
; CHECK-NOT: INR
; CHECK: RSR
define void @bstore(ptr %p, i8 %v) {
  store i8 %v, ptr %p
  %n = getelementptr i8, ptr %p, i16 1
  store ptr %n, ptr @g
  ret void
}

; CHECK-LABEL: wprestore:
; CHECK: {{STA_D|STB_D|STX_D}}
; CHECK-NOT: DCR
; CHECK: RSR
define void @wprestore(ptr %p, i16 %v) {
  %n = getelementptr i16, ptr %p, i16 -1
  store i16 %v, ptr %n
  store ptr %n, ptr @g
  ret void
}

; CHECK-LABEL: bprestore:
; CHECK: {{STAB_D|STBB_D}}
; CHECK-NOT: DCR
; CHECK: RSR
define void @bprestore(ptr %p, i8 %v) {
  %n = getelementptr i8, ptr %p, i16 -1
  store i8 %v, ptr %n
  store ptr %n, ptr @g
  ret void
}

; The stored word is the old pointer. The writeback is a different register.
; CHECK-LABEL: wstoreold:
; CHECK: {{STA_I|STB_I|STX_I}}
; CHECK: RSR
define ptr @wstoreold(ptr %p) {
  store ptr %p, ptr %p
  %n = getelementptr i16, ptr %p, i16 1
  ret ptr %n
}

; Volatile stays one access; the increment is still the writeback.
; CHECK-LABEL: wpostvol:
; CHECK: {{LDA_I|LDB_I|LDX_I}}
; CHECK-NOT: INR
; CHECK: RSR
define i16 @wpostvol(ptr %p) {
  %v = load volatile i16, ptr %p
  %n = getelementptr i16, ptr %p, i16 1
  store ptr %n, ptr @g
  ret i16 %v
}

; Three elements is not one step. The add stays.
; CHECK-LABEL: wstep3:
; CHECK-NOT: LDA_I
; CHECK-NOT: LDB_I
; CHECK-NOT: LDX_I
; CHECK: INR
; CHECK: RSR
define i16 @wstep3(ptr %p) {
  %v = load i16, ptr %p
  %n = getelementptr i16, ptr %p, i16 3
  store ptr %n, ptr @g
  ret i16 %v
}

; CHECK-LABEL: bstep3:
; CHECK-NOT: LDAB_I
; CHECK-NOT: LDBB_I
; CHECK: INR
; CHECK: RSR
define i8 @bstep3(ptr %p) {
  %v = load i8, ptr %p
  %n = getelementptr i8, ptr %p, i16 3
  store ptr %n, ptr @g
  ret i8 %v
}

; *p-- is a post-decrement. There is no such mode.
; CHECK-LABEL: wpostdec:
; CHECK-NOT: LDA_I
; CHECK-NOT: LDB_I
; CHECK-NOT: LDX_I
; CHECK-NOT: LDA_D
; CHECK-NOT: LDB_D
; CHECK-NOT: LDX_D
; CHECK: {{DCR|ADD}}
; CHECK: RSR
define i16 @wpostdec(ptr %p) {
  %v = load i16, ptr %p
  %n = getelementptr i16, ptr %p, i16 -1
  store ptr %n, ptr @g
  ret i16 %v
}

; *++p is a pre-increment. There is no such mode.
; CHECK-LABEL: wpreinc:
; CHECK-NOT: LDA_I
; CHECK-NOT: LDB_I
; CHECK-NOT: LDX_I
; CHECK-NOT: LDA_D
; CHECK-NOT: LDB_D
; CHECK-NOT: LDX_D
; CHECK: {{INR|ADD}}
; CHECK: RSR
define i16 @wpreinc(ptr %p) {
  %n = getelementptr i16, ptr %p, i16 1
  %v = load i16, ptr %n
  store ptr %n, ptr @g
  ret i16 %v
}
