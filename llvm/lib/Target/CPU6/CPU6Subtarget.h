//===-- CPU6Subtarget.h - Define Subtarget for the CPU6 ---------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The subtarget is the bag of objects the rest of codegen asks for: instruction
// info, register info, frame lowering, and DAG lowering. One CPU6 device is
// enough, so one subtarget is shared by every function.

#ifndef LLVM_LIB_TARGET_CPU6_CPU6SUBTARGET_H
#define LLVM_LIB_TARGET_CPU6_CPU6SUBTARGET_H

#include "CPU6FrameLowering.h"
#include "CPU6ISelLowering.h"
#include "CPU6InstrInfo.h"
#include "llvm/CodeGen/SelectionDAGTargetInfo.h"
#include "llvm/CodeGen/TargetSubtargetInfo.h"

#define GET_SUBTARGETINFO_HEADER
#include "CPU6GenSubtargetInfo.inc"

namespace llvm {

class CPU6Subtarget : public CPU6GenSubtargetInfo {
public:
  CPU6Subtarget(const Triple &TT, StringRef CPU, StringRef FS,
                const TargetMachine &TM);
  ~CPU6Subtarget() override;

  CPU6Subtarget &initializeSubtargetDependencies(StringRef CPU, StringRef FS);

  // Defined by TableGen from the Feature* records in CPU6Devices.td.
  void ParseSubtargetFeatures(StringRef CPU, StringRef TuneCPU, StringRef FS);

  const CPU6InstrInfo *getInstrInfo() const override { return &InstrInfo; }
  const CPU6RegisterInfo *getRegisterInfo() const override {
    return &InstrInfo.getRegisterInfo();
  }
  const CPU6FrameLowering *getFrameLowering() const override {
    return &FrameLowering;
  }
  const CPU6TargetLowering *getTargetLowering() const override {
    return &TLInfo;
  }
  const SelectionDAGTargetInfo *getSelectionDAGInfo() const override {
    return &TSInfo;
  }

private:
  // Field name is fixed by FeatureCPU6 in CPU6Devices.td.
  bool m_isCPU6 = false;

  CPU6InstrInfo InstrInfo;
  CPU6FrameLowering FrameLowering;
  CPU6TargetLowering TLInfo;
  CPU6SelectionDAGInfo TSInfo;
};

} // namespace llvm

#endif
