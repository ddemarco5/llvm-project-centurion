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

// memcpy, memmove, and memset are part of the CPU6 runtime libcall set.
// Naming them here keeps PreISelIntrinsicLowering from rewriting them as IR
// loops, so they reach CPU6SelectionDAGInfo, which expands them inline. No
// call to these three symbols is emitted. Soft-float operations use the
// other calls in that set.
//
// Wide shifts and signed multiply, divide, and remainder are lowered to
// WSHIFT or 0x46. A libcall for those would be the routine the legalizer is
// building, or a call whose i64 result the old legalizer could not return.
// Unsigned divide has no 0x46 opcode (D is signed), so UDIV_I64 and UREM_I64
// stay libcalls. A double conversion to i64 is not a bignum operation.
void CPU6Subtarget::initLibcallLoweringInfo(LibcallLoweringInfo &Info) const {
  Info.setLibcallImpl(RTLIB::MEMCPY, RTLIB::impl_memcpy);
  Info.setLibcallImpl(RTLIB::MEMMOVE, RTLIB::impl_memmove);
  Info.setLibcallImpl(RTLIB::MEMSET, RTLIB::impl_memset);

  for (RTLIB::Libcall LC :
       {RTLIB::SHL_I64, RTLIB::SRL_I64, RTLIB::SRA_I64, RTLIB::MUL_I64,
        RTLIB::SDIV_I32, RTLIB::SREM_I32, RTLIB::SDIV_I64, RTLIB::SREM_I64,
        RTLIB::MUL_I128, RTLIB::SDIV_I128, RTLIB::SREM_I128, RTLIB::NEG_I64,
        RTLIB::MULO_I64, RTLIB::FPTOSINT_F32_I64, RTLIB::FPTOSINT_F64_I64,
        RTLIB::FPTOUINT_F32_I64, RTLIB::FPTOUINT_F64_I64})
    Info.setLibcallImpl(LC, RTLIB::Unsupported);
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
  case CPU6ISD::WSHIFT:
    return "CPU6ISD::WSHIFT";
  }
  return nullptr;
}
