//===-- CPU6AsmPrinter.h - CPU6 assembly printer passes ---------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The new pass manager splits the assembly printer into a begin/function/end
// trio. The printer object itself is created from the target registry
// (LLVMInitializeCPU6AsmPrinter) and stored in AsmPrinterAnalysis.

#ifndef LLVM_LIB_TARGET_CPU6_CPU6ASMPRINTER_H
#define LLVM_LIB_TARGET_CPU6_CPU6ASMPRINTER_H

#include "llvm/CodeGen/MachineFunctionAnalysisManager.h"
#include "llvm/IR/PassManager.h"

namespace llvm {

class CPU6AsmPrinterBeginPass
    : public RequiredPassInfoMixin<CPU6AsmPrinterBeginPass> {
public:
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &MAM);
};

class CPU6AsmPrinterPass : public RequiredPassInfoMixin<CPU6AsmPrinterPass> {
public:
  PreservedAnalyses run(MachineFunction &MF,
                        MachineFunctionAnalysisManager &MFAM);
};

class CPU6AsmPrinterEndPass
    : public RequiredPassInfoMixin<CPU6AsmPrinterEndPass> {
public:
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &MAM);
};

} // namespace llvm

#endif
