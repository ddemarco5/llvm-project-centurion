//===--- CPU6.cpp - Implement CPU6 target feature support -------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements CPU6 TargetInfo objects.
//
//===----------------------------------------------------------------------===//

#include "CPU6.h"
#include "clang/Basic/MacroBuilder.h"

using namespace clang;
using namespace clang::targets;

ArrayRef<const char *> CPU6TargetInfo::getGCCRegNames() const {
  // Assembly names, matching the names TableGen gives the register file.
  static const char *const GCCRegNames[] = {
      "A",  "B",  "X",  "Y",  "Z",  "S",  "C",  "P",  "AU", "AL", "BU", "BL",
      "XU", "XL", "YU", "YL", "ZU", "ZL", "SU", "SL", "CU", "CL", "PU", "PL"};
  return llvm::ArrayRef(GCCRegNames);
}

void CPU6TargetInfo::getTargetDefines(const LangOptions &,
                                      MacroBuilder &Builder) const {
  Builder.defineMacro("CPU6");
  Builder.defineMacro("__CPU6__");
}
