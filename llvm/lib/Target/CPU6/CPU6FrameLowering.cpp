//===-- CPU6FrameLowering.cpp - CPU6 Frame Information -----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CPU6FrameLowering.h"

using namespace llvm;

void CPU6FrameLowering::emitPrologue(MachineFunction &MF,
                                     MachineBasicBlock &MBB) const {
  // A function with no stack objects and no callee-saved registers has nothing
  // to do here. When one does, MBB is the entry block and the insertion point
  // is MBB.begin(): emit the saves and the stack adjustment in front of the
  // body. S is the likely stack pointer, once getReservedRegs reserves it and
  // TargetLowering::setStackPointerRegisterToSaveRestore is told.
  (void)MF;
  (void)MBB;
}

void CPU6FrameLowering::emitEpilogue(MachineFunction &MF,
                                     MachineBasicBlock &MBB) const {
  // Same as emitPrologue, inserted in front of the return instruction.
  (void)MF;
  (void)MBB;
}
