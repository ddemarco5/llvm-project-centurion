# REQUIRES: cpu6

# RUN: llvm-mc -triple=cpu6 -filetype=obj %S/Inputs/cpu6-weak.s -o %t-weak.o
# RUN: llvm-mc -triple=cpu6 -filetype=obj %S/Inputs/cpu6-strong.s -o %t-strong.o
# RUN: ld.lld -m elf32cpu6 -T %S/../../ELF/cpu6.ld --image-base=0x100 -e side -o %t.elf %t-weak.o %t-strong.o
# RUN: llvm-objdump -f %t.elf | FileCheck %s --check-prefix=ENTRY
# RUN: ld.lld -m elf32cpu6 -T %S/../../ELF/cpu6.ld --image-base=0x100 -e side --oformat=binary -o %t.bin %t-weak.o %t-strong.o
# RUN: %python -c "print(open(r'%t.bin','rb').read().hex())" | FileCheck %s --check-prefix=BYTES

# The weak side occupies the first byte. The strong side is four bytes into
# the second .text, at 0x108, and the JSR uses that address.
# ENTRY: start address: 0x00000108
# BYTES: 09000000790108090109
