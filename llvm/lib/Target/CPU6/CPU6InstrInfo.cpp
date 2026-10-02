//===-- CPU6InstrInfo.cpp - CPU6 Instruction Information ---------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CPU6InstrInfo.h"
#include "CPU6Subtarget.h"
#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineMemOperand.h"
#include "llvm/Support/ErrorHandling.h"

#define GET_INSTRINFO_CTOR_DTOR
#include "CPU6GenInstrInfo.inc"

using namespace llvm;

CPU6InstrInfo::CPU6InstrInfo(const CPU6Subtarget &STI)
    : CPU6GenInstrInfo(STI, RI), RI() {}

void CPU6InstrInfo::copyPhysReg(MachineBasicBlock &MBB,
                                MachineBasicBlock::iterator MI,
                                const DebugLoc &DL, Register DestReg,
                                Register SrcReg, bool KillSrc,
                                bool RenamableDest, bool RenamableSrc) const {
  // the register allocator inserts plain COPY instructions. After
  // allocation those copies have to become real CPU6 instructions, or the
  // asm printer will see a COPY opcode it cannot encode.
  //
  // Word move is XFR. Its TableGen operands are (outs dest), (ins src), and
  // the text is "XFR src,dest". BuildMI's destination argument is the out
  // operand; addReg appends the source:
  
  if (CPU6::GPRRegClass.contains(DestReg, SrcReg)) {
    BuildMI(MBB, MI, DL, get(CPU6::XFR), DestReg)
        .addReg(SrcReg, getKillRegState(KillSrc));
    return;
  }

}

void CPU6InstrInfo::storeRegToStackSlot(MachineBasicBlock &MBB,
                                        MachineBasicBlock::iterator MI,
                                        Register SrcReg, bool IsKill,
                                        int FrameIndex,
                                        const TargetRegisterClass *RC,
                                        Register VReg,
                                        MachineInstr::MIFlag Flags) const {
  // The register allocator calls this for a spill. The store names the slot
  // by frame index; the prologue inserter lays spill slots out with the
  // locals, and eliminateFrameIndex swaps the index for its distance from S.
  //
  // STR (S),disp stores any word register without going through A. It does
  // not move S, so offsets stay valid, unlike STK.
  (void)VReg;
  if (!CPU6::GPRRegClass.hasSubClassEq(RC))
    report_fatal_error("CPU6 can only spill 16-bit registers");

  MachineFunction &MF = *MBB.getParent();
  MachineFrameInfo &MFI = MF.getFrameInfo();
  MachineMemOperand *MMO = MF.getMachineMemOperand(
      MachinePointerInfo::getFixedStack(MF, FrameIndex),
      MachineMemOperand::MOStore, MFI.getObjectSize(FrameIndex),
      MFI.getObjectAlign(FrameIndex));

  BuildMI(MBB, MI, DebugLoc(), get(CPU6::STRidx))
      .addReg(SrcReg, getKillRegState(IsKill))
      .addReg(CPU6::rS)
      .addFrameIndex(FrameIndex)
      .addMemOperand(MMO)
      .setMIFlags(Flags);
}

void CPU6InstrInfo::loadRegFromStackSlot(
    MachineBasicBlock &MBB, MachineBasicBlock::iterator MI, Register DestReg,
    int FrameIndex, const TargetRegisterClass *RC, Register VReg,
    unsigned SubReg, MachineInstr::MIFlag Flags) const {
  // The reload: XFR (S),disp is the indexed load into any word register.
  (void)VReg;
  (void)SubReg;
  if (!CPU6::GPRRegClass.hasSubClassEq(RC))
    report_fatal_error("CPU6 can only reload 16-bit registers");

  MachineFunction &MF = *MBB.getParent();
  MachineFrameInfo &MFI = MF.getFrameInfo();
  MachineMemOperand *MMO = MF.getMachineMemOperand(
      MachinePointerInfo::getFixedStack(MF, FrameIndex),
      MachineMemOperand::MOLoad, MFI.getObjectSize(FrameIndex),
      MFI.getObjectAlign(FrameIndex));

  BuildMI(MBB, MI, DebugLoc(), get(CPU6::XFRidx), DestReg)
      .addReg(CPU6::rS)
      .addFrameIndex(FrameIndex)
      .addMemOperand(MMO)
      .setMIFlags(Flags);
}

// Every frame-slot access has the same operands: the data register, the base
// S, and the frame index as displacement.
static Register frameSlotAccess(const MachineInstr &MI, int &FrameIndex) {
  if (MI.getOperand(1).isReg() && MI.getOperand(1).getReg() == CPU6::rS &&
      MI.getOperand(2).isFI()) {
    FrameIndex = MI.getOperand(2).getIndex();
    return MI.getOperand(0).getReg();
  }
  return Register();
}

Register CPU6InstrInfo::isLoadFromStackSlot(const MachineInstr &MI,
                                            int &FrameIndex) const {
  switch (MI.getOpcode()) {
  case CPU6::XFRidx:
  case CPU6::LDAfi:
    return frameSlotAccess(MI, FrameIndex);
  default:
    return Register();
  }
}

Register CPU6InstrInfo::isStoreToStackSlot(const MachineInstr &MI,
                                           int &FrameIndex) const {
  switch (MI.getOpcode()) {
  case CPU6::STRidx:
  case CPU6::STAfi:
    return frameSlotAccess(MI, FrameIndex);
  default:
    return Register();
  }
}
