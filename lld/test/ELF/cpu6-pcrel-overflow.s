# REQUIRES: cpu6

# RUN: llvm-mc -triple=cpu6 -filetype=obj %s -o %t.o
# RUN: not ld.lld -m elf32cpu6 -T %S/../../ELF/cpu6.ld --image-base=0x100 -e f -o %t.elf %t.o 2>&1 | FileCheck %s

# The branch displacement is S + A - (P + 1). 200 does not fit in a signed
# 8-bit field.
# CHECK: relocation R_CPU6_8_PCREL out of range

	.section .text, "ax", @progbits
	.globl f
f:
	BZ distant
	.section .text.far, "ax", @progbits
	.space 200
	.globl distant
distant:
	RSR
