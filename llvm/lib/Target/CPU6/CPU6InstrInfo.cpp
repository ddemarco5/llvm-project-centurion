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
#include "llvm/CodeGen/MachineInstrBuilder.h"

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
  // TODO(cpu6): the register allocator inserts plain COPY instructions. After
  // allocation those copies have to become real CPU6 instructions, or the
  // asm printer will see a COPY opcode it cannot encode.
  //
  // Word move is XFR. Its TableGen operands are (outs dest), (ins src), and
  // the text is "XFR src,dest". BuildMI's destination argument is the out
  // operand; addReg appends the source:
  //
  //   if (CPU6::GPRRegClass.contains(DestReg, SrcReg)) {
  //     BuildMI(MBB, MI, DL, get(CPU6::XFR), DestReg)
  //         .addReg(SrcReg, getKillRegState(KillSrc));
  //     return;
  //   }
  //
  // Byte copies are XFRB, once GPRB is a legal register class. RenamableDest
  // and RenamableSrc can stay unused until the coalescer cares.
  (void)MBB;
  (void)MI;
  (void)DL;
  (void)DestReg;
  (void)SrcReg;
  (void)KillSrc;
  (void)RenamableDest;
  (void)RenamableSrc;
  llvm_unreachable("TODO(cpu6): CPU6InstrInfo::copyPhysReg");
}

void CPU6InstrInfo::storeRegToStackSlot(MachineBasicBlock &MBB,
                                        MachineBasicBlock::iterator MI,
                                        Register SrcReg, bool IsKill,
                                        int FrameIndex,
                                        const TargetRegisterClass *RC,
                                        Register VReg,
                                        MachineInstr::MIFlag Flags) const {
  // TODO(cpu6): emit a store of SrcReg to FrameIndex. Nothing in the first
  // tests spills, so this stays unreachable until the allocator runs out of
  // registers or a callee-saved register has to be saved.
  (void)MBB;
  (void)MI;
  (void)SrcReg;
  (void)IsKill;
  (void)FrameIndex;
  (void)RC;
  (void)VReg;
  (void)Flags;
  llvm_unreachable("TODO(cpu6): CPU6InstrInfo::storeRegToStackSlot");
}

void CPU6InstrInfo::loadRegFromStackSlot(
    MachineBasicBlock &MBB, MachineBasicBlock::iterator MI, Register DestReg,
    int FrameIndex, const TargetRegisterClass *RC, Register VReg,
    unsigned SubReg, MachineInstr::MIFlag Flags) const {
  // TODO(cpu6): the reload paired with storeRegToStackSlot.
  (void)MBB;
  (void)MI;
  (void)DestReg;
  (void)FrameIndex;
  (void)RC;
  (void)VReg;
  (void)SubReg;
  (void)Flags;
  llvm_unreachable("TODO(cpu6): CPU6InstrInfo::loadRegFromStackSlot");
}
