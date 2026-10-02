	.globl caller
caller:
	JSR (side)
	RSR
	.globl side
side:
	NOP
	RSR
