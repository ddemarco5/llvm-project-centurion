# REQUIRES: cpu6

# RUN: llvm-mc -triple=cpu6 -filetype=obj %S/Inputs/cpu6-caller.s -o %t-caller.o
# RUN: llvm-mc -triple=cpu6 -filetype=obj %S/Inputs/cpu6-side.s -o %t-side.o
# RUN: ld.lld -m elf32cpu6 -T %S/../../ELF/cpu6.ld --image-base=0x100 -e caller --oformat=binary -o %t.bin %t-caller.o %t-side.o
# RUN: %python -c "print(open(r'%t.bin','rb').read().hex())" | FileCheck %s

# caller.o is 4 bytes and .text is aligned to 4, so side starts at 0x104.
# CHECK: 7901040909
