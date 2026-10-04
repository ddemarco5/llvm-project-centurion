; RUN: llc -mtriple=cpu6 < %s | FileCheck --check-prefix=ASM %s
; RUN: llc -mtriple=cpu6 < %s \
; RUN:   | llvm-mc -triple=cpu6 -filetype=obj - \
; RUN:   | llvm-objdump -s -j .data - | FileCheck --check-prefix=OBJ %s

; Initialised data must print as directives CPU6AsmParser reads back, and
; assemble to big-endian bytes. .word is a 16-bit word there, so wider
; integers are .long and .quad.

@b = global i8 85
@h = global i16 4660
@w = global i32 287454020
@q = global i64 72623859790382856

; ASM:     .byte 85
; ASM:     .word 4660
; ASM:     .long 287454020
; ASM:     .quad 72623859790382856

; OBJ:     Contents of section .data:
; OBJ-NEXT: 0000 55123411 22334401 02030405 060708
