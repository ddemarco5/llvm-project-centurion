# REQUIRES: cpu6

# RUN: llvm-mc -triple=cpu6 -filetype=obj %s -o %t.o
# RUN: ld.lld -m elf32cpu6 -T %S/../../ELF/cpu6.ld --image-base=0x100 -e f --oformat=binary -o %t.bin %t.o
# RUN: %python -c "print(open(r'%t.bin','rb').read().hex())" | FileCheck %s

# The assembler resolves a branch to a label in the same section. The
# displacement byte is already 1, and there is no relocation to apply.
# CHECK: 14010909

	.globl f
f:
	BZ next
	RSR
next:
	RSR
