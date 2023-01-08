// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains the declaration of the CPU6MCAsmInfo class.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_CPU6_MCTARGETDESC_CPU6MCASMINFO_H
#define LLVM_LIB_TARGET_CPU6_MCTARGETDESC_CPU6MCASMINFO_H

#include "llvm/MC/MCAsmInfoELF.h"

namespace llvm {
class Triple;

class CPU6MCAsmInfo : public MCAsmInfoELF {
  void anchor() override;

public:
  explicit CPU6MCAsmInfo(const Triple &TargetTriple);

};

} // namespace llvm

#endif
