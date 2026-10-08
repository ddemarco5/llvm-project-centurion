# REQUIRES: cpu6

# RUN: llvm-mc -triple=cpu6 -filetype=obj %s -o %t.o
# RUN: ld.lld -m elf32cpu6 -T %S/../../ELF/cpu6.ld --image-base=0x100 -e f --oformat=binary -o %t.bin %t.o
# RUN: %python -c "print(open(r'%t.bin','rb').read().hex())" | FileCheck %s

# .long is R_CPU6_32, stored big-endian. g is the byte after the 4-byte field.
# CHECK: 00000104ab

	.section .text, "ax", @progbits
	.globl f
f:
	.long g
	.section .data, "aw", @progbits
	.globl g
g:
	.byte 0xAB
