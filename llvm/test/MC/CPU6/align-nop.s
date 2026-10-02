# RUN: llvm-mc %s -triple=cpu6 -filetype=obj -o - | llvm-objdump -d - | FileCheck %s

# .text is executable, so .align pads with NOP (opcode 0x01) rather than
# zeroes. AlignmentIsInBytes is false, so .align 2 means a 4-byte boundary.
# RSR is one byte, so the three bytes in between are NOPs.

# CHECK:      0: 09           	RSR
# CHECK-NEXT: 1: 01           	NOP
# CHECK-NEXT: 2: 01           	NOP
# CHECK-NEXT: 3: 01           	NOP
# CHECK-NEXT: 4: 09           	RSR

	.text
	RSR
	.align 2
	RSR
