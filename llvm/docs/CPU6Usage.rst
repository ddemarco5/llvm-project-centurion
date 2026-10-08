==============================
User Guide for the CPU6 Target
==============================

.. warning::
   The CPU6 backend is experimental. It is not built unless it is named in
   ``LLVM_EXPERIMENTAL_TARGETS_TO_BUILD``. It is not part of the default
   target list.

.. contents::
   :local:

Introduction
============

CPU6 is the Centurion minicomputer. Words are
16 bits, memory is byte-addressable, and integer data is big-endian. There
is no floating-point unit and no lock-free atomic instruction.

To build the backend, add ``CPU6`` to the ``LLVM_EXPERIMENTAL_TARGETS_TO_BUILD``
CMake option. See :doc:`CMake` for the rest of the LLVM build.

Target triple
=============

The architecture name is ``cpu6``. A freestanding triple is
``cpu6-unknown-none``. The object format is ELF. Pointers are 16 bits.
There is no 32-bit or 64-bit variant, and there is no little-endian
variant.

The data layout is byte-aligned for every type::

  E-P1-p:16:8-i8:8-i16:8-i32:8-i64:8-i128:8-f32:8-f64:8-n8-a:8

``int`` is 16 bits. ``long`` is 32 bits. ``long long`` is 64 bits.

Calling convention
==================

The first four argument words go in ``A``, ``B``, ``Y``, and ``Z``, in
that order. An ``i8`` uses one word. An ``i32`` uses two. Further words
go on the stack. A scalar return uses the same registers: ``i16`` in
``A``, ``i32`` in ``A:B``, and ``i64`` in ``A``, ``B``, ``Y``, ``Z``.
``S`` is the stack pointer.

The only processor name is ``CPU6``. ``-mcpu=`` may be omitted; ``cpu6``
and ``CPU6`` are the same processor.

Atomics
=======

``MaxAtomicInlineWidth`` and the backend's maximum atomic size are both
0. C ``_Atomic`` is not lock-free. Clang and ``AtomicExpand`` lower
atomic operations to ``__atomic_*`` libcalls (``__atomic_load_1``,
``__atomic_store_1``, ``__atomic_fetch_add_1``,
``__atomic_compare_exchange_1``, and the other sizes). The program must
provide those symbols. The backend does not inline them. ``DI`` and
``EI`` mask interrupts; they are not used as atomics.

Floating point and exceptions
=============================

There is no FPU. ``float`` and ``double`` are softened to integer
libcalls (``__addsf3``, ``__adddf3``, and the rest of the compiler-rt
soft-float set). The exception model is none: a C++ ``try`` is not
lowered to an EH runtime.

Linking
=======

``ld.lld`` links the relocatable ELF objects. The container is 32-bit
little-endian (``EM_CPU6``, 259). Address fields and ``.word`` / ``.long``
values are big-endian. ``-m elf32cpu6`` selects that target.
``OUTPUT_FORMAT(elf32-cpu6)`` does the same from a script. The default
image base is ``0x100``. Addresses below that are the register file.

The file to copy into memory is a raw image, not Intel HEX. Its first
byte is address ``0x100``. ``--oformat=binary`` skips a ``SHT_NOBITS``
section, and a reset does not clear RAM, so ``.bss`` and ``COMMON`` have
to be zeros in the file. ``lld/ELF/cpu6.ld`` places the image at
``0x100`` and folds those sections into a ``PROGBITS`` ``.data``:

.. code-block:: text

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

``(TYPE=SHT_PROGBITS)`` keeps the zeros when the program has no
initialized ``.data``. Input sections are concatenated in command-line
order, so the first object is the first byte of the image. ``-e`` names
the entry symbol stored in ``e_entry``.

An ELF::

   ld.lld -m elf32cpu6 -T cpu6.ld --image-base=0x100 -e main -o prog.elf prog.o

The raw image::

   ld.lld -m elf32cpu6 -T cpu6.ld --image-base=0x100 -e main --oformat=binary -o prog.bin prog.o

``llvm-objcopy -O ihex`` can turn the ELF into Intel HEX if a loader wants
address records. ``ld.lld`` does not write HEX.
