//===-- CPU6InstrInfo.h - CPU6 Instruction Information ----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_CPU6_CPU6INSTRINFO_H
#define LLVM_LIB_TARGET_CPU6_CPU6INSTRINFO_H

#include "CPU6RegisterInfo.h"
#include "llvm/CodeGen/TargetInstrInfo.h"

#define GET_INSTRINFO_HEADER
#include "CPU6GenInstrInfo.inc"

namespace llvm {

class CPU6Subtarget;

// Addressing mode of a 0x46 instruction. The order is the operand-layout
// order used by cpu6BignumOpcode's table.
enum class CPU6BignumMode {
  AA,
  AX,
  AR,
  XA,
  XX,
  XR,
  RA,
  RX,
  RR
};

// True when Opc is one selector of 0x46. Mode is which addressing form.
bool classifyCPU6Bignum(unsigned Opcode, CPU6BignumMode &Mode);

// The same selector as Opcode, in Mode.
unsigned cpu6BignumOpcode(unsigned Opcode, CPU6BignumMode Mode);

inline bool isCPU6BignumIndexed(CPU6BignumMode Mode) {
  switch (Mode) {
  case CPU6BignumMode::AX:
  case CPU6BignumMode::XA:
  case CPU6BignumMode::XX:
  case CPU6BignumMode::XR:
  case CPU6BignumMode::RX:
    return true;
  default:
    return false;
  }
}

class CPU6InstrInfo : public CPU6GenInstrInfo {
  const CPU6RegisterInfo RI;

public:
  explicit CPU6InstrInfo(const CPU6Subtarget &STI);

  // The flag test taken exactly when Opc is not taken, or 0 if Opc is not one.
  static unsigned getOppositeBranch(unsigned Opc);

  const CPU6RegisterInfo &getRegisterInfo() const { return RI; }

  void copyPhysReg(MachineBasicBlock &MBB, MachineBasicBlock::iterator MI,
                   const DebugLoc &DL, Register DestReg, Register SrcReg,
                   bool KillSrc, bool RenamableDest = false,
                   bool RenamableSrc = false) const override;

  void storeRegToStackSlot(MachineBasicBlock &MBB,
                           MachineBasicBlock::iterator MI, Register SrcReg,
                           bool IsKill, int FrameIndex,
                           const TargetRegisterClass *RC, Register VReg,
                           MachineInstr::MIFlag Flags =
                               MachineInstr::NoFlags) const override;

  void loadRegFromStackSlot(MachineBasicBlock &MBB,
                            MachineBasicBlock::iterator MI, Register DestReg,
                            int FrameIndex, const TargetRegisterClass *RC,
                            Register VReg, unsigned SubReg = 0,
                            MachineInstr::MIFlag Flags =
                                MachineInstr::NoFlags) const override;

  Register isLoadFromStackSlot(const MachineInstr &MI,
                               int &FrameIndex) const override;
  Register isStoreToStackSlot(const MachineInstr &MI,
                              int &FrameIndex) const override;

  bool expandPostRAPseudo(MachineInstr &MI) const override;

  unsigned getInstSizeInBytes(const MachineInstr &MI) const override;

  bool isReMaterializableImpl(const MachineInstr &MI) const override;

  bool analyzeBranch(MachineBasicBlock &MBB, MachineBasicBlock *&TBB,
                     MachineBasicBlock *&FBB,
                     SmallVectorImpl<MachineOperand> &Cond,
                     bool AllowModify = false) const override;
  unsigned removeBranch(MachineBasicBlock &MBB,
                        int *BytesRemoved = nullptr) const override;
  unsigned insertBranch(MachineBasicBlock &MBB, MachineBasicBlock *TBB,
                        MachineBasicBlock *FBB, ArrayRef<MachineOperand> Cond,
                        const DebugLoc &DL,
                        int *BytesAdded = nullptr) const override;
  bool
  reverseBranchCondition(SmallVectorImpl<MachineOperand> &Cond) const override;

  MachineBasicBlock *getBranchDestBlock(const MachineInstr &MI) const override;
  bool isBranchOffsetInRange(unsigned BranchOpc,
                             int64_t BrOffset) const override;
  void insertIndirectBranch(MachineBasicBlock &MBB,
                            MachineBasicBlock &NewDestBB,
                            MachineBasicBlock &RestoreBB, const DebugLoc &DL,
                            int64_t BrOffset = 0,
                            RegScavenger *RS = nullptr) const override;
};

} // namespace llvm

#endif
