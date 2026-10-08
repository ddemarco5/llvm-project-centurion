; No atomic instruction is legal. AtomicExpand rewrites each one as a
; sized __atomic_* libcall. The runtime has to provide the symbol.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s

; CHECK-LABEL: load_store:
; CHECK: JSR (__atomic_load_1)
; CHECK: JSR (__atomic_store_1)
define void @load_store(ptr %a) nounwind {
  %v = load atomic i8, ptr %a monotonic, align 1
  store atomic i8 %v, ptr %a monotonic, align 1
  ret void
}

; CHECK-LABEL: fetch_add:
; CHECK: JSR (__atomic_fetch_add_1)
define i8 @fetch_add(ptr %a, i8 %v) nounwind {
  %r = atomicrmw add ptr %a, i8 %v monotonic, align 1
  ret i8 %r
}

; CHECK-LABEL: cmpxchg:
; CHECK: JSR (__atomic_compare_exchange_1)
define i8 @cmpxchg(ptr %a, i8 %cmp, i8 %new) nounwind {
  %r = cmpxchg ptr %a, i8 %cmp, i8 %new monotonic monotonic, align 1
  %v = extractvalue { i8, i1 } %r, 0
  ret i8 %v
}
