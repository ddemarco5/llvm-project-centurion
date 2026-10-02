//===-- CPU6FixupKinds.h - CPU6 Specific Fixup Entries ----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_CPU6_MCTARGETDESC_CPU6FIXUPKINDS_H
#define LLVM_LIB_TARGET_CPU6_MCTARGETDESC_CPU6FIXUPKINDS_H

#include "llvm/MC/MCFixup.h"

namespace llvm {
namespace CPU6 {

// Keep this in the same order as CPU6AsmBackend::getFixupKindInfo.
enum Fixups {
  // Signed 8-bit displacement, relative to the next instruction. Used by
  // the branch class (BZ and the rest) and by (PC)+b / ((PC)+b).
  fixup_cpu6_pcrel_8 = FirstTargetFixupKind,
  // Big-endian absolute 16-bit address or immediate. Used by direct JMP and
  // JSR, LDA/STA direct and literal, and the trailing imm16 of XFR/ADD.
  fixup_cpu6_abs_16,

  LastTargetFixupKind,
  NumTargetFixupKinds = LastTargetFixupKind - FirstTargetFixupKind
};

} // namespace CPU6
} // namespace llvm

#endif
