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

TODO
