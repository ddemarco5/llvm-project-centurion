/* CPU6 load image. File offset 0 of --oformat=binary is address 0x100.
   .bss and COMMON are placed in .data. That output section is PROGBITS, so
   the zero bytes are in the file: --oformat=binary skips SHT_NOBITS, and a
   reset does not clear RAM. */
OUTPUT_FORMAT(elf32-cpu6)
SECTIONS {
  . = 0x100;
  .text : { *(.text .text.*) }
  .rodata : { *(.rodata .rodata.*) }
  .data (TYPE=SHT_PROGBITS) : {
    *(.data .data.*)
    *(.bss .bss.*)
    *(COMMON)
  }
}
