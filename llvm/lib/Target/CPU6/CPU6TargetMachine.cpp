// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines the CPU6 specific subclass of TargetMachine.
//
//===----------------------------------------------------------------------===//

#include "CPU6TargetMachine.h"

#include "llvm/ADT/STLExtras.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/CodeGen/TargetLoweringObjectFileImpl.h"
#include "llvm/CodeGen/TargetPassConfig.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/Support/FormattedStream.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Target/TargetOptions.h"

#include "TargetInfo/CPU6TargetInfo.h"

using namespace llvm;

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeCPU6Target() {
  RegisterTargetMachine<CPU6TargetMachine> X(getTheCPU6Target());
}

// This only returns one data layout for now, but let's leave it in a function
// in case we ever need to select from multiple
static StringRef computeDataLayout(const Triple &TT) {
    return "e-P1-p:16:8-i8:8-i16:8-i32:8-i64:8-f32:8-f64:8-n8-a:8";
}

static Reloc::Model getEffectiveRelocModel(const Triple &TT, Optional<Reloc::Model> RM) {
  return RM.value_or(Reloc::Static);
}


CPU6TargetMachine::CPU6TargetMachine(const Target &T, const Triple &TT,
                                     StringRef CPU, StringRef FS,
                                     const TargetOptions &Options,
                                     Optional<Reloc::Model> RM,
                                     Optional<CodeModel::Model> CM,
                                     CodeGenOpt::Level OL, bool JIT)
  : LLVMTargetMachine(T, computeDataLayout(TT), TT, CPU, FS, Options,
                      getEffectiveRelocModel(TT, RM),
                      getEffectiveCodeModel(CM, CodeModel::Small), OL), // TODO: learn what codemodel is
    TLOF(std::make_unique<TargetLoweringObjectFileELF>()) {
  initAsmInfo();
}

TargetPassConfig *CPU6TargetMachine::createPassConfig(PassManagerBase &PM) {
  return new TargetPassConfig(*this, PM);
}