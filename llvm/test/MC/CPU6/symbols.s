# RUN: llvm-mc %s -triple=cpu6 -show-encoding \
# RUN:     | FileCheck %s --check-prefix=ASM
# RUN: llvm-mc %s -filetype=obj -triple=cpu6 -o - \
# RUN:     | llvm-objdump -d -r - \
# RUN:     | FileCheck %s --check-prefix=OBJ

# A label in a branch or (PC)+b field is an 8-bit displacement from the
# next instruction. A label in a direct address or an address immediate is
# a 16-bit absolute relocation. Same-section branches are resolved in the
# object file; absolute addresses are left for a linker because the load
# address is not known here.

# ASM: BZ loop
# ASM: encoding: [0x14,A]
# ASM: fixup A - offset: 1, value: loop, kind: fixup_cpu6_pcrel_8
# ASM: BZ fwd
# ASM: encoding: [0x14,A]
# ASM: fixup A - offset: 1, value: fwd, kind: fixup_cpu6_pcrel_8
# ASM: JMP (abs)
# ASM: encoding: [0x71,A,A]
# ASM: fixup A - offset: 1, value: abs, kind: fixup_cpu6_abs_16
# ASM: JSR (abs)
# ASM: encoding: [0x79,A,A]
# ASM: fixup A - offset: 1, value: abs, kind: fixup_cpu6_abs_16
# ASM: LDA (abs)
# ASM: encoding: [0x91,A,A]
# ASM: fixup A - offset: 1, value: abs, kind: fixup_cpu6_abs_16
# ASM: XFR A,abs
# ASM: encoding: [0x55,0x10,A,A]
# ASM: fixup A - offset: 2, value: abs, kind: fixup_cpu6_abs_16
# ASM: ADD A,A,abs+2
# ASM: encoding: [0x50,0x10,A,A]
# ASM: fixup A - offset: 2, value: abs+2, kind: fixup_cpu6_abs_16
# ASM: JMP (PC),pct
# ASM: encoding: [0x73,A]
# ASM: fixup A - offset: 1, value: pct, kind: fixup_cpu6_pcrel_8
# ASM: LDA (PC),pct2
# ASM: encoding: [0x93,A]
# ASM: fixup A - offset: 1, value: pct2, kind: fixup_cpu6_pcrel_8
# ASM: BZ missing
# ASM: encoding: [0x14,A]
# ASM: fixup A - offset: 1, value: missing, kind: fixup_cpu6_pcrel_8
# ASM: JMP (missing)
# ASM: encoding: [0x71,A,A]
# ASM: fixup A - offset: 1, value: missing, kind: fixup_cpu6_abs_16
# ASM: XFR (abs),Z
# ASM: encoding: [0x55,0x89,A,A]
# ASM: fixup A - offset: 2, value: abs, kind: fixup_cpu6_abs_16
# ASM: STR Z,(abs)
# ASM: encoding: [0xd6,0x89,A,A]
# ASM: fixup A - offset: 2, value: abs, kind: fixup_cpu6_abs_16

# loop is the BZ itself, so the displacement is 1 - 3 = -2.
# fwd is the instruction after the following NOP: 6 - 5 = 1.
# pct is the next instruction, displacement 0. pct2 is one past the NOP.
# Local absolute symbols become a section relocation whose addend is the
# offset of the label (.text+0x21 is abs, .text+0x23 is abs+2).
# OBJ: BZ -2
# OBJ: BZ 1
# OBJ: R_CPU6_16 .text+0x21
# OBJ: R_CPU6_16 .text+0x23
# OBJ: JMP (PC),0
# OBJ: LDA (PC),1
# OBJ: R_CPU6_8_PCREL missing
# OBJ: R_CPU6_16 missing

	NOP
loop:
	BZ loop
	BZ fwd
	NOP
fwd:
	JMP (abs)
	JSR (abs)
	LDA (abs)
	XFR A, abs
	ADD A, A, abs+2
	JMP (PC), pct
pct:
	LDA (PC), pct2
	NOP
pct2:
	BZ missing
	JMP (missing)
abs:
	NOP
	XFR (abs), Z
	STR Z, (abs)
