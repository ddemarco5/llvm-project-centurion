// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file provides CPU6 specific target descriptions.
//
//===----------------------------------------------------------------------===//


#ifndef LLVM_LIB_TARGET_CPU6_MCTARGETDESC_CPU6MCTARGETDESC_H
#define LLVM_LIB_TARGET_CPU6_MCTARGETDESC_CPU6MCTARGETDESC_H

#include "llvm/Config/config.h"
#include "llvm/MC/MCTargetOptions.h"
#include "llvm/Support/DataTypes.h"
#include <memory>

namespace llvm {
class MCAsmBackend;
class MCCodeEmitter;
class MCContext;
class MCInstrInfo;
class MCObjectTargetWriter;
class MCRegisterInfo;
class MCSubtargetInfo;
class Target;

MCCodeEmitter *createCPU6MCCodeEmitter(const MCInstrInfo &MCII,
                                       MCContext &Ctx);

MCAsmBackend *createCPU6AsmBackend(const Target &T, const MCSubtargetInfo &STI,
                                   const MCRegisterInfo &MRI,
                                   const MCTargetOptions &Options);

std::unique_ptr<MCObjectTargetWriter> createCPU6ELFObjectWriter(uint8_t OSABI,
                                                                 bool Is64Bit);
}

// Defines symbolic names for CPU6 registers.
#define GET_REGINFO_ENUM
#include "CPU6GenRegisterInfo.inc"

// Defines symbolic names for CPU6 instructions.
#define GET_INSTRINFO_ENUM
#include "CPU6GenInstrInfo.inc"

#endif