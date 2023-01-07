// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file declares the Sparc specific subclass of TargetMachine.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_CPU6_CPU6TARGETMACHINE_H
#define LLVM_LIB_TARGET_CPU6_CPU6TARGETMACHINE_H

#include "llvm/CodeGen/SelectionDAGTargetInfo.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/Target/TargetMachine.h"

namespace llvm {

/// A start at an implementation of the CPU used in the centurion microcomputer
class CPU6TargetMachine : public LLVMTargetMachine {
  std::unique_ptr<TargetLoweringObjectFile> TLOF;
public:
  CPU6TargetMachine(const Target &T, const Triple &TT, StringRef CPU,
                  StringRef FS, const TargetOptions &Options,
                  Optional<Reloc::Model> RM, Optional<CodeModel::Model> CM,
                  CodeGenOpt::Level OL, bool JIT);

    TargetPassConfig *createPassConfig(PassManagerBase &PM) override;

    TargetLoweringObjectFile *getObjFileLowering() const override {
      return TLOF.get();
    }

};

} // end namespace llvm

#endif // LLVM_LIB_TARGET_CPU6_CPU6TARGETMACHINE_H
