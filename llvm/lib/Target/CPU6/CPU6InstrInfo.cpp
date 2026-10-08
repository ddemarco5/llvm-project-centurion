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
#include "llvm/ADT/ArrayRef.h"
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

// One row per selector, columns in CPU6BignumMode order.
struct CPU6BignumFamily {
  unsigned Ops[9];
};

static const CPU6BignumFamily CPU6BignumFamilies[] = {
#define CPU6_BN_ROW(N)                                                         \
  {CPU6::N##_AA, CPU6::N##_AX, CPU6::N##_AR, CPU6::N##_XA, CPU6::N##_XX,      \
   CPU6::N##_XR, CPU6::N##_RA, CPU6::N##_RX, CPU6::N##_RR},
    CPU6_BN_ROW(BNA) CPU6_BN_ROW(BNS) CPU6_BN_ROW(BNC) CPU6_BN_ROW(ZAD)
        CPU6_BN_ROW(ZSU) CPU6_BN_ROW(M) CPU6_BN_ROW(D) CPU6_BN_ROW(DRM)
            CPU6_BN_ROW(CTB) CPU6_BN_ROW(CFB)
#undef CPU6_BN_ROW
};

bool llvm::classifyCPU6Bignum(unsigned Opcode, CPU6BignumMode &Mode) {
  for (const CPU6BignumFamily &Family : CPU6BignumFamilies) {
    for (unsigned I = 0; I < 9; ++I) {
      if (Family.Ops[I] == Opcode) {
        Mode = static_cast<CPU6BignumMode>(I);
        return true;
      }
    }
  }
  return false;
}

unsigned llvm::cpu6BignumOpcode(unsigned Opcode, CPU6BignumMode Mode) {
  for (const CPU6BignumFamily &Family : CPU6BignumFamilies) {
    for (unsigned I = 0; I < 9; ++I) {
      if (Family.Ops[I] == Opcode)
        return Family.Ops[static_cast<unsigned>(Mode)];
    }
  }
  llvm_unreachable("not a CPU6 bignum opcode");
}

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

// Spill code is never read for its flags. The built instruction carries the
// flag implicit-defs of its opcode, and the register allocator asserts that
// every def of a spill it deletes (a redundant one) is dead.
static void markFlagDefsDead(MachineInstrBuilder &MIB) {
  for (MachineOperand &MO : MIB->implicit_operands())
    if (MO.isReg() && MO.isDef())
      MO.setIsDead();
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

  MachineInstrBuilder MIB = BuildMI(MBB, MI, DebugLoc(), get(Opc))
                                .addReg(SrcReg, getKillRegState(IsKill))
                                .addFrameIndex(FrameIndex)
                                .addImm(0)
                                .addMemOperand(MMO)
                                .setMIFlags(Flags);
  markFlagDefsDead(MIB);
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

  MachineInstrBuilder MIB = BuildMI(MBB, MI, DebugLoc(), get(Opc), DestReg)
                                .addFrameIndex(FrameIndex)
                                .addImm(0)
                                .addMemOperand(MMO)
                                .setMIFlags(Flags);
  markFlagDefsDead(MIB);
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
  case CPU6::LDBYTEfi:
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

// SPILLB and RELOADB do not touch AL until they are expanded, so AL is live
// across them exactly when something after them still reads it.
static bool isPhysRegLiveAt(const TargetRegisterInfo &TRI, MachineInstr &MI,
                            MCRegister Reg) {
  MachineBasicBlock &MBB = *MI.getParent();
  LivePhysRegs LiveRegs(TRI);
  LiveRegs.addLiveOuts(MBB);
  for (MachineInstr &I : llvm::reverse(MBB)) {
    if (&I == &MI)
      break;
    LiveRegs.stepBackward(I);
  }
  return LiveRegs.contains(Reg);
}

// LDBYTEfi / LDBYTEabs. webCenREE rrfetchb has no memory mode, so the byte
// comes through LDAB (AL) or LDBB (BL). A destination that is neither is an
// XFRB off whichever accumulator is free. Both live means the same exchange
// RELOADB uses: park AL in the destination, load, and swap back.
static bool expandByteLoad(const CPU6InstrInfo &TII, MachineInstr &MI) {
  MachineBasicBlock &MBB = *MI.getParent();
  const DebugLoc &DL = MI.getDebugLoc();
  const bool Abs = MI.getOpcode() == CPU6::LDBYTEabs;
  const Register Dst = MI.getOperand(0).getReg();
  const Register AL = CPU6::rAL;
  const Register BL = CPU6::rBL;
  const unsigned LdAL = Abs ? CPU6::LDABabs : CPU6::LDABfi;
  const unsigned LdBL = Abs ? CPU6::LDBBabs : CPU6::LDBBfi;

  auto emitLd = [&](unsigned Opc, Register Acc) {
    auto B = BuildMI(MBB, MI, DL, TII.get(Opc), Acc);
    B.add(MI.getOperand(1));
    if (!Abs)
      B.add(MI.getOperand(2));
    B.cloneMemRefs(MI);
  };
  auto copyAcc = [&](Register Acc) {
    BuildMI(MBB, MI, DL, TII.get(CPU6::XFRB), Dst).addReg(Acc, RegState::Kill);
  };

  if (Dst == AL) {
    emitLd(LdAL, AL);
  } else if (Dst == BL) {
    emitLd(LdBL, BL);
  } else if (!isPhysRegLiveAt(TII.getRegisterInfo(), MI, AL)) {
    emitLd(LdAL, AL);
    copyAcc(AL);
  } else if (!isPhysRegLiveAt(TII.getRegisterInfo(), MI, BL)) {
    emitLd(LdBL, BL);
    copyAcc(BL);
  } else {
    BuildMI(MBB, MI, DL, TII.get(CPU6::XFRB), Dst).addReg(AL);
    emitLd(LdAL, AL);
    swapBytes(TII, MBB, MI, DL, Dst, AL);
  }
  MI.eraseFromParent();
  return true;
}

// Writeback opcode for each pseudo. Columns are the A, B, and X forms.
// A byte opcode has no X form. The data register of LDA_I and its twins is
// implicit, so the pseudo exists until allocation has picked a register.
struct IdxMem {
  unsigned Pseudo;
  unsigned A, B, X;
  bool Store;
  bool Pre;
  bool Byte;
};

static const IdxMem IdxMems[] = {
    {CPU6::LDW_POST, CPU6::LDA_5_1, CPU6::LDB_5_1, CPU6::LDX_5_1, false, false,
     false},
    {CPU6::LDW_PRE, CPU6::LDA_5_2, CPU6::LDB_5_2, CPU6::LDX_5_2, false, true,
     false},
    {CPU6::LDB_POST, CPU6::LDAB_5_1, CPU6::LDBB_5_1, 0, false, false, true},
    {CPU6::LDB_PRE, CPU6::LDAB_5_2, CPU6::LDBB_5_2, 0, false, true, true},
    {CPU6::STW_POST, CPU6::STA_5_1, CPU6::STB_5_1, CPU6::STX_5_1, true, false,
     false},
    {CPU6::STW_PRE, CPU6::STA_5_2, CPU6::STB_5_2, CPU6::STX_5_2, true, true,
     false},
    {CPU6::STB_POST, CPU6::STAB_5_1, CPU6::STBB_5_1, 0, true, false, true},
    {CPU6::STB_PRE, CPU6::STAB_5_2, CPU6::STBB_5_2, 0, true, true, true},
};

static Register idxAcc(const IdxMem &M, unsigned Slot) {
  if (M.Byte)
    return Slot ? CPU6::rBL : CPU6::rAL;
  return Slot == 0 ? CPU6::rA : Slot == 1 ? CPU6::rB : CPU6::rX;
}

static unsigned idxOpc(const IdxMem &M, unsigned Slot) {
  return Slot == 0 ? M.A : Slot == 1 ? M.B : M.X;
}

// LDW_POST / LDB_POST and the store and pre-decrement twins. The accumulator
// is the data register, or any other one LivePhysRegs::available reports
// free (a live subregister counts: LDA_I writes all of A). A byte whose
// accumulators are both live uses the same exchange as a byte spill. A word
// with none free is a plain XFR/STR plus INR/DCR, the code before the fold.
static bool expandIndexedMem(const CPU6InstrInfo &TII, MachineInstr &MI) {
  const IdxMem *M = nullptr;
  for (const IdxMem &E : IdxMems)
    if (E.Pseudo == MI.getOpcode())
      M = &E;
  if (!M)
    return false;

  const TargetRegisterInfo &TRI = TII.getRegisterInfo();
  MachineBasicBlock &MBB = *MI.getParent();
  const DebugLoc &DL = MI.getDebugLoc();
  // Load operands are dst, wb, base. Store operands are wb, base, val.
  Register Data =
      M->Store ? MI.getOperand(2).getReg() : MI.getOperand(0).getReg();
  Register WB = MI.getOperand(M->Store ? 0 : 1).getReg();
  Register Base = MI.getOperand(M->Store ? 1 : 2).getReg();
  assert(WB == Base && "indexed writeback is tied to the base");
  // earlyclobber keeps the data register off the pointer. LDA_I (A) would
  // write both results to A.
  if (TRI.regsOverlap(Data, Base))
    report_fatal_error("CPU6 indexed operand overlaps the pointer");

  const unsigned N = M->Byte ? 2 : 3;
  auto xfer = [&](Register Dst, Register Src, bool Kill) {
    BuildMI(MBB, MI, DL, TII.get(M->Byte ? CPU6::XFRB : CPU6::XFR), Dst)
        .addReg(Src, getKillRegState(Kill));
  };
  auto emit = [&](unsigned Slot) {
    BuildMI(MBB, MI, DL, TII.get(idxOpc(*M, Slot)), WB)
        .addReg(Base)
        .cloneMemRefs(MI);
  };

  for (unsigned Slot = 0; Slot < N; ++Slot) {
    if (idxAcc(*M, Slot) != Data)
      continue;
    emit(Slot);
    MI.eraseFromParent();
    return true;
  }

  LivePhysRegs Live(TRI);
  Live.addLiveOuts(MBB);
  for (MachineInstr &I : llvm::reverse(MBB)) {
    if (&I == &MI)
      break;
    Live.stepBackward(I);
  }
  const MachineRegisterInfo &MRI = MI.getMF()->getRegInfo();
  for (unsigned Slot = 0; Slot < N; ++Slot) {
    Register Acc = idxAcc(*M, Slot);
    if (TRI.regsOverlap(Acc, Base) || !Live.available(MRI, Acc))
      continue;
    if (M->Store)
      xfer(Acc, Data, MI.getOperand(2).isKill());
    emit(Slot);
    if (!M->Store && !MI.getOperand(0).isDead())
      xfer(Data, Acc, true);
    MI.eraseFromParent();
    return true;
  }

  // Park the accumulator that is not the pointer. swapBytes restores it.
  if (M->Byte) {
    unsigned Slot = TRI.regsOverlap(Base, CPU6::rA) ? 1 : 0;
    Register Acc = idxAcc(*M, Slot);
    if (TRI.regsOverlap(Data, Acc))
      report_fatal_error("CPU6 indexed byte op has no accumulator");
    if (M->Store)
      swapBytes(TII, MBB, MI, DL, Data, Acc);
    else
      xfer(Data, Acc, false);
    emit(Slot);
    swapBytes(TII, MBB, MI, DL, Data, Acc);
    MI.eraseFromParent();
    return true;
  }

  // INR/DCR's count nibble is the distance minus one. A word steps by 2.
  // Pre-decrement steps first so the access sees the new address. The data
  // register is not the pointer, so the stored value survives the step.
  auto step = [&](bool Pre) {
    BuildMI(MBB, MI, DL, TII.get(Pre ? CPU6::DCR : CPU6::INR), WB)
        .addReg(Base)
        .addImm(1);
  };
  if (M->Pre)
    step(true);
  if (M->Store)
    BuildMI(MBB, MI, DL, TII.get(CPU6::STRidx))
        .addReg(Data, getKillRegState(MI.getOperand(2).isKill()))
        .addReg(Base)
        .addImm(0)
        .cloneMemRefs(MI);
  else
    BuildMI(MBB, MI, DL, TII.get(CPU6::XFRidx), Data)
        .addReg(Base)
        .addImm(0)
        .cloneMemRefs(MI);
  if (!M->Pre)
    step(false);
  MI.eraseFromParent();
  return true;
}

bool CPU6InstrInfo::expandPostRAPseudo(MachineInstr &MI) const {
  // Frame indices are already displacements here; the prologue inserter ran
  // first. A byte load result is any byte register (LDBYTE). A spill still
  // goes through AL, and an exchange keeps a live AL intact.
  unsigned Opc = MI.getOpcode();
  if (Opc == CPU6::LDBYTEfi || Opc == CPU6::LDBYTEabs)
    return expandByteLoad(*this, MI);
  if (expandIndexedMem(*this, MI))
    return true;
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
    } else if (!isPhysRegLiveAt(RI, MI, AL)) {
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
    } else if (!isPhysRegLiveAt(RI, MI, AL)) {
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

bool CPU6InstrInfo::isReMaterializableImpl(const MachineInstr &MI) const {
  // The generic check rejects every physreg def. XFRimm's only extra defs
  // are Minus and Value, and a dead one is not a value anyone reads.
  if (MI.getOpcode() == CPU6::XFRimm) {
    for (const MachineOperand &MO : MI.implicit_operands())
      if (MO.isReg() && MO.isDef() && !MO.isDead())
        return false;
    return true;
  }
  return TargetInstrInfo::isReMaterializableImpl(MI);
}

unsigned CPU6InstrInfo::getOppositeBranch(unsigned Opc) {
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