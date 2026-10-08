# REQUIRES: cpu6

# RUN: llvm-mc -triple=cpu6 -filetype=obj %S/Inputs/cpu6-undef.s -o %t-undef.o
# RUN: llvm-mc -triple=cpu6 -filetype=obj %S/Inputs/cpu6-dup-a.s -o %t-a.o
# RUN: llvm-mc -triple=cpu6 -filetype=obj %S/Inputs/cpu6-dup-b.s -o %t-b.o
# RUN: not ld.lld -m elf32cpu6 -T %S/../../ELF/cpu6.ld --image-base=0x100 -e caller -o %t.bin %t-undef.o 2>&1 | FileCheck %s --check-prefix=UNDEF
# RUN: not ld.lld -m elf32cpu6 -T %S/../../ELF/cpu6.ld --image-base=0x100 -e foo -o %t2.bin %t-a.o %t-b.o 2>&1 | FileCheck %s --check-prefix=DUP

# UNDEF: undefined symbol: missing
# DUP: duplicate symbol: foo
