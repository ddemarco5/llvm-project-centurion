# REQUIRES: cpu6

# RUN: llvm-mc -triple=cpu6 -filetype=obj %s -o %t.o
# RUN: not ld.lld -m elf32cpu6 -T %S/../../ELF/cpu6.ld --image-base=0x100 -e f --defsym=far=0x10000 -o %t.elf %t.o 2>&1 | FileCheck %s

# A 16-bit absolute field cannot hold 0x10000.
# CHECK: relocation R_CPU6_16 out of range
# CHECK: 65536

	.globl f
f:
	JSR (far)
