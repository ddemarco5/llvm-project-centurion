# REQUIRES: cpu6

# RUN: llvm-mc -triple=cpu6 -filetype=obj %s -o %t.o
# RUN: ld.lld -m elf32cpu6 -T %S/../../ELF/cpu6.ld --image-base=0x100 -e side -o %t.elf %t.o
# RUN: llvm-objdump -f %t.elf | FileCheck %s --check-prefix=ENTRY
# RUN: ld.lld -m elf32cpu6 -T %S/../../ELF/cpu6.ld --image-base=0x100 -e side --oformat=binary -o %t.bin %t.o
# RUN: %python -c "print(open(r'%t.bin','rb').read().hex())" | FileCheck %s --check-prefix=BYTES

# side is the first byte. The JSR's address field is the big-endian load
# address of side.
# ENTRY: start address: 0x00000100
# BYTES: 0979010009

	.globl side
side:
	RSR
	.globl caller
caller:
	JSR (side)
	RSR
