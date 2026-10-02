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
#include "llvm/CodeGen/LiveIntervals.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/TargetInstrInfo.h"
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
  // Fault, Link, Minus, Value. Branches read them and arithmetic writes
  // them. They are not general-purpose.
  Reserved.set(CPU6::rF);
  Reserved.set(CPU6::rL);
  Reserved.set(CPU6::rM);
  Reserved.set(CPU6::rV);
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
  // Every frame access is (frame index, displacement), the frame index in the
  // base operand. The default getFrameIndexReference returns the object
  // offset plus the frame size: the distance from S once the prologue has
  // reserved the frame. An incoming stack argument in a realigned function
  // is addressed from X instead. Debug info asks the same hook.
  (void)RS;
  assert(SPAdj == 0 && "mid-function S adjustment is not handled");
  MachineFunction &MF = *MI->getParent()->getParent();
  MachineOperand &Disp = MI->getOperand(FIOperandNum + 1);
  Register FrameReg;
  int64_t Offset = MF.getSubtarget()
                       .getFrameLowering()
                       ->getFrameIndexReference(
                           MF, MI->getOperand(FIOperandNum).getIndex(), FrameReg)
                       .getFixed() +
                   Disp.getImm();

  // XFR, STR, and ADD take a word. The others take a signed byte. A word
  // LDA/STA out of that range is the XFR/STR indexed form instead: same
  // operands and flags, one byte longer, any register.
  unsigned Opc = MI->getOpcode();
  bool WordDisp =
      Opc == CPU6::XFRidx || Opc == CPU6::STRidx || Opc == CPU6::ADDimm;
  if (!WordDisp && !isInt<8>(Offset)) {
    const TargetInstrInfo &TII = *MF.getSubtarget().getInstrInfo();
    if (Opc == CPU6::LDAfi)
      MI->setDesc(TII.get(CPU6::XFRidx));
    else if (Opc == CPU6::STAfi)
      MI->setDesc(TII.get(CPU6::STRidx));
    else
      report_fatal_error("CPU6 byte frame access is out of displacement range");
  }
  if (!isInt<16>(Offset))
    report_fatal_error("CPU6 frame offset does not fit in the displacement");
  MI->getOperand(FIOperandNum).ChangeToRegister(FrameReg, /*isDef=*/false);
  Disp.setImm(Offset);
  return false;
}

bool CPU6RegisterInfo::shouldCoalesce(MachineInstr *MI,
                                      const TargetRegisterClass *,
                                      unsigned SubReg,
                                      const TargetRegisterClass *,
                                      unsigned DstSubReg,
                                      const TargetRegisterClass *NewRC,
                                      LiveIntervals &LIS) const {
  if (NewRC->getNumRegs() != 1)
    return true;
  // Folding `%b:accb = COPY %w.sub_lo` into %w would make the whole word
  // Acc, because only A has AL as its low byte. Two such words live at once
  // cannot both be A, and the allocator gives up. Keep the byte copy instead.
  if (SubReg || DstSubReg)
    return false;
  // Nor pin a value to the one register where that register is already live
  // as itself, e.g. an incoming argument in A that is copied out after the
  // value is defined. Splitting cannot help: every piece stays in the
  // one-register class. Left as a copy, the allocator just hints A.
  MCRegister Only = *NewRC->begin();
  for (const MachineOperand &MO : {MI->getOperand(0), MI->getOperand(1)}) {
    if (!MO.getReg().isVirtual())
      continue;
    const LiveInterval &LI = LIS.getInterval(MO.getReg());
    for (MCRegUnit Unit : regunits(Only))
      if (LIS.getRegUnit(Unit).overlaps(LI))
        return false;
  }
  return true;
}

Register CPU6RegisterInfo::getFrameRegister(const MachineFunction &) const {
  // Every slot is addressed from S, including in a realigned function: there
  // X only remembers S for the epilogue, and the distance from X to a slot
  // depends on how far the prologue rounded S down.
  return CPU6::rS;
}
