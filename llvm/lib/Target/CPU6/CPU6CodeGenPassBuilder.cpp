//===-- CPU6CodeGenPassBuilder.cpp - CPU6 code gen pipeline ------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// llc compiles through TargetMachine::buildCodeGenPipeline. The base builder
// runs IR legalization, register allocation, and prologue insertion. This
// file adds the two target passes those steps call into: instruction
// selection, and the assembly printer.

#include "CPU6.h"
#include "CPU6AsmPrinter.h"
#include "CPU6TargetMachine.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/Passes/CodeGenPassBuilder.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Target/CGPassBuilderOption.h"

using namespace llvm;

namespace {

class CPU6CodeGenPassBuilder
    : public CodeGenPassBuilder<CPU6CodeGenPassBuilder, CPU6TargetMachine> {
public:
  explicit CPU6CodeGenPassBuilder(CPU6TargetMachine &TM,
                                  const CGPassBuilderOption &Opts,
                                  PassInstrumentationCallbacks *PIC)
      : CodeGenPassBuilder(TM, Opts, PIC) {}

  Error addInstSelector(PassManagerWrapper &PMW) const;
  void addAsmPrinterBegin(PassManagerWrapper &PMW) const;
  void addAsmPrinter(PassManagerWrapper &PMW) const;
  void addAsmPrinterEnd(PassManagerWrapper &PMW) const;
};

Error CPU6CodeGenPassBuilder::addInstSelector(PassManagerWrapper &PMW) const {
  addMachineFunctionPass(CPU6ISelDAGToDAGPass(TM, getOptLevel()), PMW);
  return Error::success();
}

void CPU6CodeGenPassBuilder::addAsmPrinterBegin(PassManagerWrapper &PMW) const {
  addModulePass(CPU6AsmPrinterBeginPass(), PMW, /*Force=*/true);
}

void CPU6CodeGenPassBuilder::addAsmPrinter(PassManagerWrapper &PMW) const {
  addMachineFunctionPass(CPU6AsmPrinterPass(), PMW);
}

void CPU6CodeGenPassBuilder::addAsmPrinterEnd(PassManagerWrapper &PMW) const {
  addModulePass(CPU6AsmPrinterEndPass(), PMW, /*Force=*/true);
}

} // namespace

void CPU6TargetMachine::registerPassBuilderCallbacks(PassBuilder &PB) {
#define GET_PASS_REGISTRY "CPU6PassRegistry.def"
#include "llvm/Passes/TargetPassRegistry.inc"
}

Error CPU6TargetMachine::buildCodeGenPipeline(
    ModulePassManager &MPM, ModuleAnalysisManager &MAM, raw_pwrite_stream &Out,
    raw_pwrite_stream *DwoOut, CodeGenFileType FileType,
    const CGPassBuilderOption &Opt, MCContext &Ctx,
    PassInstrumentationCallbacks *PIC) {
  CPU6CodeGenPassBuilder CGPB(*this, Opt, PIC);
  return CGPB.buildPipeline(MPM, MAM, Out, DwoOut, FileType, Ctx);
}
