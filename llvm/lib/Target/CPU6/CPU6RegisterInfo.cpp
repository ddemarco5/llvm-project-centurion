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
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/MathExtras.h"

#define GET_REGINFO_TARGET_DESC
#include "CPU6GenRegisterInfo.inc"

using namespace llvm;

// The argument is the register TargetRegisterInfo treats as the return
// address. JSR pushes the caller's X, then puts the return address in X.
// RSR copies X into the program counter, then pops the caller's X back.
CPU6RegisterInfo::CPU6RegisterInfo() : CPU6GenRegisterInfo(CPU6::rX) {}

const MCPhysReg *
CPU6RegisterInfo::getCalleeSavedRegs(const MachineFunction *) const {
  // Generated from `def CSR` in CPU6CallingConv.td (X, Y, Z).
  return CSR_SaveList;
}

const uint32_t *
CPU6RegisterInfo::getCallPreservedMask(const MachineFunction &,
                                       CallingConv::ID) const {
  return CSR_RegMask;
}

BitVector CPU6RegisterInfo::getReservedRegs(const MachineFunction &MF) const {
  // this is the first function llc calls for every function.
  //
  // A reserved register is never handed out by the register allocator. P is
  // the program counter. Reserving the 16-bit register does not reserve its
  // byte halves; set those too, or the allocator can hand out rPL and clobber
  // P. S is the usual stack pointer. Reserve it once you decide it is not
  // general-purpose, and do the same for its halves.

  BitVector Reserved(getNumRegs());
  Reserved.set(CPU6::rP);
  Reserved.set(CPU6::rPU);
  Reserved.set(CPU6::rPL);
  Reserved.set(CPU6::rS);
  Reserved.set(CPU6::rSU);
  Reserved.set(CPU6::rSL);
  // X holds the frame pointer in a function that realigns S.
  if (MF.getSubtarget().getFrameLowering()->hasFP(MF)) {
    Reserved.set(CPU6::rX);
    Reserved.set(CPU6::rXU);
    Reserved.set(CPU6::rXL);
  }
  return Reserved;
}

bool CPU6RegisterInfo::eliminateFrameIndex(MachineBasicBlock::iterator MI,
                                           int SPAdj, unsigned FIOperandNum,
                                           RegScavenger *RS) const {
  // Every frame-slot access already names S as the base. This replaces the
  // frame index in the displacement. The default getFrameIndexReference
  // returns the object offset plus the frame size: the distance from S once
  // the prologue has reserved the frame. Debug info asks the same hook.
  (void)RS;
  assert(SPAdj == 0 && "mid-function S adjustment is not handled");
  MachineFunction &MF = *MI->getParent()->getParent();
  int FrameIndex = MI->getOperand(FIOperandNum).getIndex();
  Register FrameReg;
  int64_t Offset = MF.getSubtarget()
                       .getFrameLowering()
                       ->getFrameIndexReference(MF, FrameIndex, FrameReg)
                       .getFixed();
  assert(FrameReg == CPU6::rS && "frame slots are addressed from S");
  // LDAfi/STAfi carry a displacement byte. The STR/XFR spill forms carry
  // a word.
  bool WideDisp =
      MI->getOpcode() == CPU6::STRidx || MI->getOpcode() == CPU6::XFRidx;
  if (WideDisp ? !isInt<16>(Offset) : !isInt<8>(Offset))
    report_fatal_error("CPU6 frame offset does not fit in the displacement");
  MI->getOperand(FIOperandNum).ChangeToImmediate(Offset);
  return false;
}

Register CPU6RegisterInfo::getFrameRegister(const MachineFunction &) const {
  // Every slot is addressed from S, including in a realigned function: there
  // X only remembers S for the epilogue, and the distance from X to a slot
  // depends on how far the prologue rounded S down.
  return CPU6::rS;
}
