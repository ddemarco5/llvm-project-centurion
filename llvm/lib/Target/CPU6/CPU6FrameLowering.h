//===-- CPU6FrameLowering.h - Define frame lowering for CPU6 ----*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Inserts the prologue and epilogue. A leaf that never takes a stack slot
// needs neither, so the first tests leave these empty.

#ifndef LLVM_LIB_TARGET_CPU6_CPU6FRAMELOWERING_H
#define LLVM_LIB_TARGET_CPU6_CPU6FRAMELOWERING_H

#include "llvm/CodeGen/TargetFrameLowering.h"

namespace llvm {

class CPU6FrameLowering : public TargetFrameLowering {
public:
  // Data layout a:8 means the ABI alignment is one byte. Stack grows down
  // toward lower addresses; nothing in the first tests depends on that yet.
  CPU6FrameLowering()
      : TargetFrameLowering(StackGrowsDown, Align(1), /*LocalAreaOffset=*/0) {}

  void emitPrologue(MachineFunction &MF, MachineBasicBlock &MBB) const override;
  void emitEpilogue(MachineFunction &MF, MachineBasicBlock &MBB) const override;

protected:
  bool hasFPImpl(const MachineFunction &MF) const override { return false; }
};

} // namespace llvm

#endif
