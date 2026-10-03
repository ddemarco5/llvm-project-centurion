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
  // Integer data is big-endian, matching the data layout. The ELF container
  // stays little-endian; that is the AsmBackend endian llvm-cpu6-ld reads.
  IsLittleEndian = false;
  CodePointerSize = CalleeSaveStackSlotSize = TT.isArch64Bit() ? 8 : 4;
  CommentString = "#";
  AlignmentIsInBytes = false;
  SupportsDebugInformation = true;
  ExceptionsType = ExceptionHandling::DwarfCFI;
  Data16bitsDirective = "\t.half\t";
  Data32bitsDirective = "\t.word\t";
}
