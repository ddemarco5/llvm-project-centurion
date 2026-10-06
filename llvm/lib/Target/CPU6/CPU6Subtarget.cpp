//===-- CPU6Subtarget.cpp - CPU6 Subtarget Information -----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CPU6Subtarget.h"
#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "llvm/CodeGen/LibcallLoweringInfo.h"

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

// There is no runtime library. Naming memcpy, memmove, and memset keeps
// PreISelIntrinsicLowering from rewriting them as IR loops, so they reach
// CPU6SelectionDAGInfo, which always expands them inline. No call to these
// symbols is ever emitted.
void CPU6Subtarget::initLibcallLoweringInfo(LibcallLoweringInfo &Info) const {
  Info.setLibcallImpl(RTLIB::MEMCPY, RTLIB::impl_memcpy);
  Info.setLibcallImpl(RTLIB::MEMMOVE, RTLIB::impl_memmove);
  Info.setLibcallImpl(RTLIB::MEMSET, RTLIB::impl_memset);
}

const char *CPU6SelectionDAGInfo::getTargetNodeName(unsigned Opcode) const {
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
  case CPU6ISD::STEP_CC:
    return "CPU6ISD::STEP_CC";
  case CPU6ISD::BN_MOV:
    return "CPU6ISD::BN_MOV";
  case CPU6ISD::BN_ADD:
    return "CPU6ISD::BN_ADD";
  case CPU6ISD::BN_SUB:
    return "CPU6ISD::BN_SUB";
  case CPU6ISD::BN_NEG:
    return "CPU6ISD::BN_NEG";
  case CPU6ISD::BN_MUL:
    return "CPU6ISD::BN_MUL";
  case CPU6ISD::BN_DIV:
    return "CPU6ISD::BN_DIV";
  case CPU6ISD::BN_DRM:
    return "CPU6ISD::BN_DRM";
  case CPU6ISD::BN_CMP:
    return "CPU6ISD::BN_CMP";
  case CPU6ISD::BLK_COPY:
    return "CPU6ISD::BLK_COPY";
  case CPU6ISD::BLK_FILL:
    return "CPU6ISD::BLK_FILL";
  case CPU6ISD::MEMCPY_LOOP:
    return "CPU6ISD::MEMCPY_LOOP";
  case CPU6ISD::MEMMOVE_LOOP:
    return "CPU6ISD::MEMMOVE_LOOP";
  case CPU6ISD::MEMSET_LOOP:
    return "CPU6ISD::MEMSET_LOOP";
  }
  return nullptr;
}
