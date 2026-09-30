//===-- CPU6FrameLowering.h - Define frame lowering for CPU6 ----*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Inserts the prologue and epilogue. STK and POP move S across the
// callee-saved registers. These two functions move S across the locals.

#ifndef LLVM_LIB_TARGET_CPU6_CPU6FRAMELOWERING_H
#define LLVM_LIB_TARGET_CPU6_CPU6FRAMELOWERING_H

#include "llvm/CodeGen/TargetFrameLowering.h"

namespace llvm {

class CPU6FrameLowering : public TargetFrameLowering {
public:
  // Data layout a:8 means the ABI alignment is one byte. The stack grows
  // down, so slot offsets are negative and the prologue lowers S.
  // S itself has no alignment guarantee. A function with a slot aligned
  // above one byte realigns S in the prologue, with X as the frame pointer.
  CPU6FrameLowering()
      : TargetFrameLowering(StackGrowsDown, Align(1), /*LocalAreaOffset=*/0) {}

  void emitPrologue(MachineFunction &MF, MachineBasicBlock &MBB) const override;
  void emitEpilogue(MachineFunction &MF, MachineBasicBlock &MBB) const override;

  void determineCalleeSaves(MachineFunction &MF, BitVector &SavedRegs,
                            RegScavenger *RS = nullptr) const override;

  // One STK per contiguous stretch of X, Y, Z, instead of a store per register.
  bool spillCalleeSavedRegisters(MachineBasicBlock &MBB,
                                 MachineBasicBlock::iterator MI,
                                 ArrayRef<CalleeSavedInfo> CSI,
                                 const TargetRegisterInfo *TRI) const override;

  bool restoreCalleeSavedRegisters(
      MachineBasicBlock &MBB, MachineBasicBlock::iterator MI,
      MutableArrayRef<CalleeSavedInfo> CSI,
      const TargetRegisterInfo *TRI) const override;

protected:
  bool hasFPImpl(const MachineFunction &MF) const override;
};

} // namespace llvm

#endif
