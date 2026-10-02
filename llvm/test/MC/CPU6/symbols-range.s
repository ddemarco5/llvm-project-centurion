# RUN: not llvm-mc -triple=cpu6 -filetype=obj %s 2>&1 | FileCheck %s

# The displacement is from the next instruction. 200 bytes past that does
# not fit in a signed 8-bit field, and there is no long form to relax to.
	BZ far
	.space 200
far:
	NOP

# CHECK: 8-bit PC-relative displacement out of range
