# REQUIRES: cpu6

# RUN: llvm-mc -triple=cpu6 -filetype=obj %s -o %t.o
# RUN: ld.lld -m elf32cpu6 -T %S/../../ELF/cpu6.ld --image-base=0x100 -e _start -o %t.elf %t.o
# RUN: llvm-objdump -f %t.elf | FileCheck %s --check-prefix=ENTRY
# RUN: ld.lld -m elf32cpu6 -T %S/../../ELF/cpu6.ld --image-base=0x100 -e _start --oformat=binary -o %t.bin %t.o
# RUN: %python -c "print(open(r'%t.bin','rb').read().hex())" | FileCheck %s --check-prefix=BYTES

# Executable bytes come first, so _start is the base. buf is the .bss that
# follows the 4-byte .text, and the image includes those zero bytes.
# ENTRY: start address: 0x00000100
# BYTES: 9101040900000000

	.bss
	.globl buf
buf:
	.zero 4
	.text
	.globl _start
_start:
	LDA (buf)
	RSR
