//===-- CPU6Subtarget.cpp - CPU6 Subtarget Information -----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CPU6Subtarget.h"
#include "MCTargetDesc/CPU6MCTargetDesc.h"

#define DEBUG_TYPE "cpu6-subtarget"

#define GET_SUBTARGETINFO_TARGET_DESC
#define GET_SUBTARGETINFO_CTOR
#include "CPU6GenSubtargetInfo.inc"

using namespace llvm;

CPU6Subtarget &
CPU6Subtarget::initializeSubtargetDependencies(StringRef CPU, StringRef FS) {
  // llc -mtriple=cpu6 with no -mcpu leaves CPU empty. The only processor in
  // CPU6Devices.td is "CPU6", and that is what turns FeatureCPU6 on.
  StringRef CPUName = CPU;
  if (CPUName.empty())
    CPUName = "CPU6";
  ParseSubtargetFeatures(CPUName, /*TuneCPU=*/CPUName, FS);
  return *this;
}

CPU6Subtarget::CPU6Subtarget(const Triple &TT, StringRef CPU, StringRef FS,
                             const TargetMachine &TM)
    : CPU6GenSubtargetInfo(TT, CPU, /*TuneCPU=*/CPU, FS),
      InstrInfo(initializeSubtargetDependencies(CPU, FS)), FrameLowering(),
      TLInfo(TM, *this) {}

CPU6Subtarget::~CPU6Subtarget() = default;

const char *CPU6SelectionDAGInfo::getTargetNodeName(unsigned Opcode) const {
  // TODO(cpu6): names for the CPU6ISD opcodes, so -debug-only=isel can print
  // them. Until this switch has a case, custom nodes show up as
  // "<<Unknown Target Node #N>>".
  //
  switch (Opcode) {
  case CPU6ISD::RET_GLUE:
    return "CPU6ISD::RET_GLUE";
  case CPU6ISD::NOP:
    return "CPU6ISD::NOP";
  case CPU6ISD::CALL:
    return "CPU6ISD::CALL";
  case CPU6ISD::TC_RETURN:
    return "CPU6ISD::TC_RETURN";
  case CPU6ISD::CMP:
    return "CPU6ISD::CMP";
  case CPU6ISD::TST:
    return "CPU6ISD::TST";
  case CPU6ISD::BR_CC:
    return "CPU6ISD::BR_CC";
  case CPU6ISD::SELECT_CC:
    return "CPU6ISD::SELECT_CC";
  }
  return nullptr;
}
