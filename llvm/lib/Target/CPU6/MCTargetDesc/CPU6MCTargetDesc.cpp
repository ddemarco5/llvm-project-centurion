// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// This file provides CPU6-specific target descriptions.
///
//===----------------------------------------------------------------------===//

#include "CPU6MCTargetDesc.h"
#include "CPU6MCAsmInfo.h"
#include "TargetInfo/CPU6TargetInfo.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/ErrorHandling.h"

#define GET_INSTRINFO_MC_DESC
#include "CPU6GenInstrInfo.inc"

#define GET_REGINFO_MC_DESC
#include "CPU6GenRegisterInfo.inc"

#define GET_SUBTARGETINFO_MC_DESC
#include "CPU6GenSubtargetInfo.inc"

using namespace llvm;

static MCInstrInfo *createCPU6MCInstrInfo() {
  MCInstrInfo *X = new MCInstrInfo();
  InitCPU6MCInstrInfo(X);
  return X;
}

static MCRegisterInfo *createCPU6MCRegisterInfo(const Triple &TT) {
  MCRegisterInfo *X = new MCRegisterInfo();
  InitCPU6MCRegisterInfo(X, CPU6::A);
  return X;
}

static MCSubtargetInfo *createCPU6MCSubtargetInfo(const Triple &TT, StringRef CPU, StringRef FS) {
  return createCPU6MCSubtargetInfoImpl(TT, CPU, CPU, FS);
}

static MCAsmInfo *createCPU6MCAsmInfo(const MCRegisterInfo &MRI,
                                       const Triple &TT,
                                       const MCTargetOptions &Options) {
  return new CPU6MCAsmInfo(TT);
}


extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeCPU6TargetMC() {
    for (Target *T : {&getTheCPU6Target()}) { // Can put more targets here in the future if needed
        TargetRegistry::RegisterMCAsmInfo(*T, createCPU6MCAsmInfo);
        TargetRegistry::RegisterMCInstrInfo(*T, createCPU6MCInstrInfo);
        TargetRegistry::RegisterMCRegInfo(*T, createCPU6MCRegisterInfo);
        TargetRegistry::RegisterMCSubtargetInfo(*T, createCPU6MCSubtargetInfo);
        TargetRegistry::RegisterMCAsmBackend(*T, createCPU6AsmBackend);
        TargetRegistry::RegisterMCCodeEmitter(*T, createCPU6MCCodeEmitter);
    }
}