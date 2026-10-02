//===-- CPU6TargetMachine.cpp - Define TargetMachine for CPU6 ----*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// TargetMachine is the object llc asks for a pass pipeline. The pipeline
// itself lives in CPU6CodeGenPassBuilder.cpp. This file also keeps the legacy
// pass-manager hook, which installs the same instruction selector.

#include "CPU6TargetMachine.h"
#include "CPU6.h"
#include "TargetInfo/CPU6TargetInfo.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/CodeGen/TargetLoweringObjectFileImpl.h"
#include "llvm/CodeGen/TargetPassConfig.h"
#include "llvm/MC/TargetRegistry.h"

using namespace llvm;

static StringRef computeDataLayout(const Triple &TT) {
  // e: little-endian. P1: one address space. p:16:8: 16-bit pointers, 8-bit
  // aligned. n8: the data layout's "native" width hint. Legality for codegen
  // comes from the register classes in CPU6TargetLowering, not from n8: GPR
  // makes i16 the legal integer type.
  (void)TT;
  return "e-P1-p:16:8-i8:8-i16:8-i32:8-i64:8-f32:8-f64:8-n8-a:8";
}

static Reloc::Model getEffectiveRelocModel(std::optional<Reloc::Model> RM) {
  return RM.value_or(Reloc::Static);
}

CPU6TargetMachine::CPU6TargetMachine(const Target &T, const Triple &TT,
                                     StringRef CPU, StringRef FS,
                                     const TargetOptions &Options,
                                     std::optional<Reloc::Model> RM,
                                     std::optional<CodeModel::Model> CM,
                                     CodeGenOptLevel OL, bool JIT)
    : CodeGenTargetMachineImpl(T, computeDataLayout(TT), TT, CPU, FS, Options,
                               getEffectiveRelocModel(RM),
                               getEffectiveCodeModel(CM, CodeModel::Small), OL),
      TLOF(std::make_unique<TargetLoweringObjectFileELF>()),
      Subtarget(TT, CPU, FS, *this) {
  (void)JIT;
  initAsmInfo();
}

namespace {

class CPU6PassConfig : public TargetPassConfig {
public:
  CPU6PassConfig(CPU6TargetMachine &TM, PassManagerBase &PM)
      : TargetPassConfig(TM, PM) {}

  CPU6TargetMachine &getCPU6TargetMachine() const {
    return getTM<CPU6TargetMachine>();
  }

  bool addInstSelector() override;
  void addPreEmitPass() override { addPass(&BranchRelaxationPassID); }
};

} // namespace

TargetPassConfig *CPU6TargetMachine::createPassConfig(PassManagerBase &PM) {
  return new CPU6PassConfig(*this, PM);
}

bool CPU6PassConfig::addInstSelector() {
  addPass(createCPU6ISelDag(getCPU6TargetMachine(), getOptLevel()));
  return false;
}

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeCPU6Target() {
  RegisterTargetMachine<CPU6TargetMachine> X(getTheCPU6Target());
  PassRegistry &PR = *PassRegistry::getPassRegistry();
  initializeCPU6DAGToDAGISelLegacyPass(PR);
}
