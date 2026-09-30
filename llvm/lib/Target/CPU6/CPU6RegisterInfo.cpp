//===-- CPU6RegisterInfo.cpp - CPU6 Register Information ---------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CPU6RegisterInfo.h"
#include "CPU6FrameLowering.h"
#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"

#define GET_REGINFO_TARGET_DESC
#include "CPU6GenRegisterInfo.inc"

using namespace llvm;

// The argument is the register TargetRegisterInfo treats as the return
// address. RSR does not read a dedicated link register; P is the program
// counter, which is the closest thing until a real return-address register
// exists.
CPU6RegisterInfo::CPU6RegisterInfo() : CPU6GenRegisterInfo(CPU6::rP) {}

const MCPhysReg *
CPU6RegisterInfo::getCalleeSavedRegs(const MachineFunction *) const {
  // Generated from `def CSR` in CPU6CallingConv.td. Empty until that list
  // names registers.
  return CSR_SaveList;
}

const uint32_t *
CPU6RegisterInfo::getCallPreservedMask(const MachineFunction &,
                                       CallingConv::ID) const {
  return CSR_RegMask;
}

BitVector CPU6RegisterInfo::getReservedRegs(const MachineFunction &MF) const {
  // TODO(cpu6): this is the first function llc calls for every function.
  //
  // A reserved register is never handed out by the register allocator. P is
  // the program counter. Reserving the 16-bit register does not reserve its
  // byte halves; set those too, or the allocator can hand out rPL and clobber
  // P. S is the usual stack pointer. Reserve it once you decide it is not
  // general-purpose, and do the same for its halves.
  //
  // BitVector Reserved(getNumRegs());
  // Reserved.set(CPU6::rP);
  // Reserved.set(CPU6::rPU);
  // Reserved.set(CPU6::rPL);
  // Reserved.set(CPU6::rS);
  // Reserved.set(CPU6::rSU);
  // Reserved.set(CPU6::rSL);
  // return Reserved;
  (void)MF;
  llvm_unreachable("TODO(cpu6): CPU6RegisterInfo::getReservedRegs");
}

bool CPU6RegisterInfo::eliminateFrameIndex(MachineBasicBlock::iterator MI,
                                           int SPAdj, unsigned FIOperandNum,
                                           RegScavenger *RS) const {
  // TODO(cpu6): not used by a leaf with no stack slots. When a spill or an
  // alloca produces a frame index, this rewrites that operand into a real
  // base register plus displacement (S, or a frame pointer).
  (void)MI;
  (void)SPAdj;
  (void)FIOperandNum;
  (void)RS;
  llvm_unreachable("TODO(cpu6): CPU6RegisterInfo::eliminateFrameIndex");
}

Register CPU6RegisterInfo::getFrameRegister(const MachineFunction &) const {
  // No frame pointer yet (hasFPImpl returns false). S is the stand-in so
  // anything that asks has a concrete register. Change this if the frame
  // pointer ends up in a different register.
  return CPU6::rS;
}
