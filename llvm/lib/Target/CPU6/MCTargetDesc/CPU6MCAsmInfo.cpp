// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains the declarations of the CPU6MCAsmInfo properties.
//
//===----------------------------------------------------------------------===//

#include "CPU6MCAsmInfo.h"
#include "llvm/TargetParser/Triple.h"
using namespace llvm;

void CPU6MCAsmInfo::anchor() {}

CPU6MCAsmInfo::CPU6MCAsmInfo(const Triple &TT, const MCTargetOptions &Options)
    : MCAsmInfoELF(Options) {
  (void)TT;
  // Integer data is big-endian, matching the data layout. The ELF container
  // stays little-endian; that is the AsmBackend endian ld.lld reads.
  IsLittleEndian = false;
  // Pointers and CSR slots are 16-bit words.
  CodePointerSize = 2;
  CalleeSaveStackSlotSize = 2;
  CommentString = "#";
  AlignmentIsInBytes = false;
  SupportsDebugInformation = true;
  // Freestanding target: no EH runtime. Must match
  // Triple::getDefaultExceptionHandling for cpu6.
  ExceptionsType = ExceptionHandling::None;
  // The directives have to be ones CPU6AsmParser reads back. .word is a
  // big-endian 16-bit word there, so a 32-bit value is .long, which the
  // generic parser emits in the target's (big-endian) byte order.
  Data16bitsDirective = "\t.word\t";
  Data32bitsDirective = "\t.long\t";
}
