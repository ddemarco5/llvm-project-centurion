; The assembler text does not print condition flags. They show up as implicit
; operands on the machine instruction. A compare that a branch reads keeps
; those defs live; the arithmetic below does not feed a branch, so they are
; dead.
;
; ADD, AND, XOR and a shift replace Fault, Link, Minus and Value. NOT and a
; load or store write Minus and Value and leave the other two. A copy is
; XFR, which is the same Minus/Value update.
;
; RUN: llc -mtriple=cpu6 -O0 -stop-after=finalize-isel -verify-machineinstrs < %s \
; RUN:   | FileCheck %s --check-prefix=ISEL
; RUN: llc -mtriple=cpu6 -O0 -stop-after=postrapseudos -verify-machineinstrs < %s \
; RUN:   | FileCheck %s --check-prefix=POST

; ISEL-LABEL: name: add_imm
; ISEL: ADDimm {{%[0-9]+}}, 3, implicit-def dead $rf, implicit-def dead $rl, implicit-def dead $rm, implicit-def dead $rv
define i16 @add_imm(i16 %a) nounwind {
  %v = add i16 %a, 3
  ret i16 %v
}

; ISEL-LABEL: name: and_imm
; ISEL: ANDimm {{%[0-9]+}}, 7, implicit-def dead $rf, implicit-def dead $rl, implicit-def dead $rm, implicit-def dead $rv
define i16 @and_imm(i16 %a) nounwind {
  %v = and i16 %a, 7
  ret i16 %v
}

; ISEL-LABEL: name: do_xor
; ISEL: ORE {{%[0-9]+}}, {{%[0-9]+}}, implicit-def dead $rf, implicit-def dead $rl, implicit-def dead $rm, implicit-def dead $rv
define i16 @do_xor(i16 %a, i16 %b) nounwind {
  %v = xor i16 %a, %b
  ret i16 %v
}

; NOT is IVR. The line ends at Value: Fault and Link are not written.
; ISEL-LABEL: name: do_not
; ISEL: IVR {{%[0-9]+}}, 0, implicit-def dead $rm, implicit-def dead $rv{{$}}
define i16 @do_not(i16 %a) nounwind {
  %v = xor i16 %a, -1
  ret i16 %v
}

; ISEL-LABEL: name: do_shl
; ISEL: SLR {{%[0-9]+}}, 0, implicit-def dead $rf, implicit-def dead $rl, implicit-def dead $rm, implicit-def dead $rv
define i16 @do_shl(i16 %a) nounwind {
  %v = shl i16 %a, 1
  ret i16 %v
}

; Arithmetic shift right is SRR, and it writes the same four flags.
; ISEL-LABEL: name: do_ashr
; ISEL: SRR {{%[0-9]+}}, 0, implicit-def dead $rf, implicit-def dead $rl, implicit-def dead $rm, implicit-def dead $rv
define i16 @do_ashr(i16 %a) nounwind {
  %v = ashr i16 %a, 1
  ret i16 %v
}

; 7 fits in CLR's nibble, and CLR writes all four flags. The store and the
; reload write Minus and Value only. The frame index is the base and the
; extra displacement is 0; the prologue inserter adds the slot offset to it.
; ISEL-LABEL: name: load_slot
; ISEL: CLR 7, implicit-def dead $rf, implicit-def dead $rl, implicit-def dead $rm, implicit-def dead $rv
; ISEL: STRidx killed {{%[0-9]+}}, %stack.0.p, 0, implicit-def dead $rm, implicit-def dead $rv ::
; ISEL: XFRidx %stack.0.p, 0, implicit-def dead $rm, implicit-def dead $rv ::
define i16 @load_slot() nounwind {
  %p = alloca i16, align 1
  store i16 7, ptr %p, align 1
  %v = load i16, ptr %p, align 1
  ret i16 %v
}

; %b arrives in B and the result leaves in A, so this is XFR. Same two bits
; as NOT. postrapseudos is where the physreg copy becomes XFR.
; POST-LABEL: name: just_copy
; POST: $ra = XFR killed $rb, implicit-def $rm, implicit-def $rv{{$}}
define i16 @just_copy(i16 %a, i16 %b) nounwind {
  ret i16 %b
}
