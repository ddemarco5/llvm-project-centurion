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
#include "llvm/CodeGen/LivePhysRegs.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineMemOperand.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Target/TargetMachine.h"

#define GET_INSTRINFO_CTOR_DTOR
#include "CPU6GenInstrInfo.inc"

using namespace llvm;

CPU6InstrInfo::CPU6InstrInfo(const CPU6Subtarget &STI)
    : CPU6GenInstrInfo(STI, RI, CPU6::ADJCALLSTACKDOWN, CPU6::ADJCALLSTACKUP),
      RI() {}

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

  // Byte move is XFRB, same operand order. Any byte register can be either
  // side, upper or lower half.
  if (CPU6::GPRBRegClass.contains(DestReg, SrcReg)) {
    BuildMI(MBB, MI, DL, get(CPU6::XFRB), DestReg)
        .addReg(SrcReg, getKillRegState(KillSrc));
    return;
  }

  report_fatal_error("CPU6 cannot copy between a word and a byte register");
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
  // not move S, so offsets stay valid, unlike STK. A byte register has no
  // such store; SPILLB goes through AL after allocation.
  (void)VReg;
  unsigned Opc;
  if (CPU6::GPRRegClass.hasSubClassEq(RC))
    Opc = CPU6::STRidx;
  else if (CPU6::GPRBRegClass.hasSubClassEq(RC))
    Opc = CPU6::SPILLB;
  else
    report_fatal_error("CPU6 cannot spill this register class");

  MachineFunction &MF = *MBB.getParent();
  MachineFrameInfo &MFI = MF.getFrameInfo();
  MachineMemOperand *MMO = MF.getMachineMemOperand(
      MachinePointerInfo::getFixedStack(MF, FrameIndex),
      MachineMemOperand::MOStore, MFI.getObjectSize(FrameIndex),
      MFI.getObjectAlign(FrameIndex));

  BuildMI(MBB, MI, DebugLoc(), get(Opc))
      .addReg(SrcReg, getKillRegState(IsKill))
      .addFrameIndex(FrameIndex)
      .addImm(0)
      .addMemOperand(MMO)
      .setMIFlags(Flags);
}

void CPU6InstrInfo::loadRegFromStackSlot(
    MachineBasicBlock &MBB, MachineBasicBlock::iterator MI, Register DestReg,
    int FrameIndex, const TargetRegisterClass *RC, Register VReg,
    unsigned SubReg, MachineInstr::MIFlag Flags) const {
  // The reload: XFR (S),disp is the indexed load into any word register.
  // RELOADB is the byte reload, expanded after allocation.
  (void)VReg;
  (void)SubReg;
  unsigned Opc;
  if (CPU6::GPRRegClass.hasSubClassEq(RC))
    Opc = CPU6::XFRidx;
  else if (CPU6::GPRBRegClass.hasSubClassEq(RC))
    Opc = CPU6::RELOADB;
  else
    report_fatal_error("CPU6 cannot reload this register class");

  MachineFunction &MF = *MBB.getParent();
  MachineFrameInfo &MFI = MF.getFrameInfo();
  MachineMemOperand *MMO = MF.getMachineMemOperand(
      MachinePointerInfo::getFixedStack(MF, FrameIndex),
      MachineMemOperand::MOLoad, MFI.getObjectSize(FrameIndex),
      MFI.getObjectAlign(FrameIndex));

  BuildMI(MBB, MI, DebugLoc(), get(Opc), DestReg)
      .addFrameIndex(FrameIndex)
      .addImm(0)
      .addMemOperand(MMO)
      .setMIFlags(Flags);
}

// Every frame-slot access is the data register, the frame index as base, and
// a displacement. Only a zero displacement is the slot itself.
static Register frameSlotAccess(const MachineInstr &MI, int &FrameIndex) {
  if (MI.getOperand(1).isFI() && MI.getOperand(2).isImm() &&
      MI.getOperand(2).getImm() == 0) {
    FrameIndex = MI.getOperand(1).getIndex();
    return MI.getOperand(0).getReg();
  }
  return Register();
}

Register CPU6InstrInfo::isLoadFromStackSlot(const MachineInstr &MI,
                                            int &FrameIndex) const {
  switch (MI.getOpcode()) {
  case CPU6::XFRidx:
  case CPU6::LDAfi:
  case CPU6::LDABfi:
  case CPU6::RELOADB:
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
  case CPU6::STABfi:
  case CPU6::SPILLB:
    return frameSlotAccess(MI, FrameIndex);
  default:
    return Register();
  }
}

// OREB src,dst is dst ^= src. Three of them exchange two byte registers
// without a third.
static void swapBytes(const CPU6InstrInfo &TII, MachineBasicBlock &MBB,
                      MachineBasicBlock::iterator I, const DebugLoc &DL,
                      Register R1, Register R2) {
  BuildMI(MBB, I, DL, TII.get(CPU6::OREB), R2).addReg(R1).addReg(R2);
  BuildMI(MBB, I, DL, TII.get(CPU6::OREB), R1).addReg(R2).addReg(R1);
  BuildMI(MBB, I, DL, TII.get(CPU6::OREB), R2).addReg(R1).addReg(R2);
}

// SPILLB and RELOADB do not touch AL, so AL is live across them exactly when
// something after them still reads it.
static bool isALLiveAt(const TargetRegisterInfo &TRI, MachineInstr &MI) {
  MachineBasicBlock &MBB = *MI.getParent();
  LivePhysRegs LiveRegs(TRI);
  LiveRegs.addLiveOuts(MBB);
  for (MachineInstr &I : llvm::reverse(MBB)) {
    if (&I == &MI)
      break;
    LiveRegs.stepBackward(I);
  }
  return LiveRegs.contains(CPU6::rAL);
}

bool CPU6InstrInfo::expandPostRAPseudo(MachineInstr &MI) const {
  // Frame indices are already displacements here; the prologue inserter ran
  // first. Only AL can be stored or loaded with an arbitrary displacement
  // from S, so the byte goes through AL. If AL holds a live value, exchange
  // it with the byte register around the access instead of clobbering it.
  unsigned Opc = MI.getOpcode();
  if (Opc != CPU6::SPILLB && Opc != CPU6::RELOADB)
    return false;

  MachineBasicBlock &MBB = *MI.getParent();
  const DebugLoc &DL = MI.getDebugLoc();
  Register Reg = MI.getOperand(0).getReg();
  const MachineOperand &Base = MI.getOperand(1);
  const MachineOperand &Disp = MI.getOperand(2);
  const Register AL = CPU6::rAL;

  auto storeAL = [&](bool Kill) {
    BuildMI(MBB, MI, DL, get(CPU6::STABfi))
        .addReg(AL, getKillRegState(Kill))
        .add(Base)
        .add(Disp)
        .cloneMemRefs(MI);
  };
  auto loadAL = [&]() {
    BuildMI(MBB, MI, DL, get(CPU6::LDABfi), AL)
        .add(Base)
        .add(Disp)
        .cloneMemRefs(MI);
  };

  if (Opc == CPU6::SPILLB) {
    bool Kill = MI.getOperand(0).isKill();
    if (Reg == AL) {
      storeAL(Kill);
    } else if (!isALLiveAt(RI, MI)) {
      BuildMI(MBB, MI, DL, get(CPU6::XFRB), AL)
          .addReg(Reg, getKillRegState(Kill));
      storeAL(true);
    } else {
      swapBytes(*this, MBB, MI, DL, Reg, AL);
      storeAL(false);
      swapBytes(*this, MBB, MI, DL, Reg, AL);
    }
  } else {
    if (Reg == AL) {
      loadAL();
    } else if (!isALLiveAt(RI, MI)) {
      loadAL();
      BuildMI(MBB, MI, DL, get(CPU6::XFRB), Reg).addReg(AL, RegState::Kill);
    } else {
      // Park AL in the destination, load AL, then exchange.
      BuildMI(MBB, MI, DL, get(CPU6::XFRB), Reg).addReg(AL);
      loadAL();
      swapBytes(*this, MBB, MI, DL, Reg, AL);
    }
  }
  MI.eraseFromParent();
  return true;
}

unsigned CPU6InstrInfo::getInstSizeInBytes(const MachineInstr &MI) const {
  if (MI.isInlineAsm())
    return getInlineAsmLength(MI.getOperand(0).getSymbolName(),
                              MI.getMF()->getTarget().getMCAsmInfo());
  return MI.getDesc().getSize();
}

// The flag test taken exactly when Opc is not taken, or 0 if Opc is not one.
static unsigned getOppositeBranch(unsigned Opc) {
  switch (Opc) {
  case CPU6::BL:
    return CPU6::BNL;
  case CPU6::BNL:
    return CPU6::BL;
  case CPU6::BF:
    return CPU6::BNF;
  case CPU6::BNF:
    return CPU6::BF;
  case CPU6::BZ:
    return CPU6::BNZ;
  case CPU6::BNZ:
    return CPU6::BZ;
  case CPU6::BM:
    return CPU6::BP;
  case CPU6::BP:
    return CPU6::BM;
  case CPU6::BGZ:
    return CPU6::BLE;
  case CPU6::BLE:
    return CPU6::BGZ;
  default:
    return 0;
  }
}

// Cond is the flag test's opcode. The compare before it is a terminator (see
// CPU6InstrPatterns.td) that removeBranch keeps and insertBranch builds
// after, so it stays the flags' last writer.
bool CPU6InstrInfo::analyzeBranch(MachineBasicBlock &MBB,
                                  MachineBasicBlock *&TBB,
                                  MachineBasicBlock *&FBB,
                                  SmallVectorImpl<MachineOperand> &Cond,
                                  bool AllowModify) const {
  TBB = FBB = nullptr;
  Cond.clear();
  MachineBasicBlock::iterator I = MBB.end();
  while (I != MBB.begin()) {
    --I;
    if (I->isDebugInstr())
      continue;
    if (!I->isTerminator())
      break;
    // A compare with no branch after it may still set flags a successor
    // reads; tail merging can split the branch into its own block.
    if (I->isCompare())
      return Cond.empty();
    if (!I->isBranch() || !I->getOperand(0).isMBB())
      return true;
    unsigned Opc = I->getOpcode();
    if (Opc == CPU6::JMP_3 || Opc == CPU6::JMP_1) {
      // Anything after an unconditional jump is dead.
      if (AllowModify)
        MBB.erase(std::next(I), MBB.end());
      Cond.clear();
      FBB = nullptr;
      // A jump to the next block is a fallthrough. Drop it so later passes
      // can merge the blocks; same as MSP430.
      if (AllowModify && MBB.isLayoutSuccessor(I->getOperand(0).getMBB())) {
        TBB = nullptr;
        I->eraseFromParent();
        I = MBB.end();
        continue;
      }
      TBB = I->getOperand(0).getMBB();
      continue;
    }
    if (!getOppositeBranch(Opc) || !Cond.empty())
      return true;
    FBB = TBB;
    TBB = I->getOperand(0).getMBB();
    Cond.push_back(MachineOperand::CreateImm(Opc));
  }
  return false;
}

unsigned CPU6InstrInfo::removeBranch(MachineBasicBlock &MBB,
                                     int *BytesRemoved) const {
  unsigned Count = 0;
  int Bytes = 0;
  MachineBasicBlock::iterator I = MBB.end();
  while (I != MBB.begin()) {
    --I;
    if (I->isDebugInstr())
      continue;
    if (!I->isBranch() || I->isIndirectBranch())
      break;
    Bytes += getInstSizeInBytes(*I);
    I->eraseFromParent();
    I = MBB.end();
    ++Count;
  }
  if (BytesRemoved)
    *BytesRemoved = Bytes;
  return Count;
}

// Both are two bytes; branch relaxation lengthens a jump that does not reach.
unsigned CPU6InstrInfo::insertBranch(MachineBasicBlock &MBB,
                                     MachineBasicBlock *TBB,
                                     MachineBasicBlock *FBB,
                                     ArrayRef<MachineOperand> Cond,
                                     const DebugLoc &DL,
                                     int *BytesAdded) const {
  assert(TBB && "insertBranch must not be told to insert a fallthrough");
  assert(Cond.size() <= 1 && "CPU6 branch conditions are one opcode");
  if (Cond.empty()) {
    assert(!FBB && "unconditional branch with two destinations");
    BuildMI(&MBB, DL, get(CPU6::JMP_3)).addMBB(TBB);
    if (BytesAdded)
      *BytesAdded = 2;
    return 1;
  }
  BuildMI(&MBB, DL, get(Cond[0].getImm())).addMBB(TBB);
  unsigned Count = 1;
  if (FBB) {
    BuildMI(&MBB, DL, get(CPU6::JMP_3)).addMBB(FBB);
    ++Count;
  }
  if (BytesAdded)
    *BytesAdded = 2 * Count;
  return Count;
}

bool CPU6InstrInfo::reverseBranchCondition(
    SmallVectorImpl<MachineOperand> &Cond) const {
  unsigned Opp = getOppositeBranch(Cond[0].getImm());
  assert(Opp && "not a reversible CPU6 branch");
  Cond[0].setImm(Opp);
  return false;
}

MachineBasicBlock *
CPU6InstrInfo::getBranchDestBlock(const MachineInstr &MI) const {
  return MI.getOperand(0).getMBB();
}

// BrOffset is from the branch's first byte. The displacement byte counts from
// the next instruction, two bytes on.
bool CPU6InstrInfo::isBranchOffsetInRange(unsigned BranchOpc,
                                          int64_t BrOffset) const {
  return BranchOpc == CPU6::JMP_1 || isInt<8>(BrOffset - 2);
}

// JMP (addr) reaches the whole address space and needs no register.
void CPU6InstrInfo::insertIndirectBranch(MachineBasicBlock &MBB,
                                         MachineBasicBlock &NewDestBB,
                                         MachineBasicBlock &RestoreBB,
                                         const DebugLoc &DL, int64_t BrOffset,
                                         RegScavenger *RS) const {
  (void)RestoreBB;
  (void)BrOffset;
  (void)RS;
  BuildMI(&MBB, DL, get(CPU6::JMP_1)).addMBB(&NewDestBB);
}