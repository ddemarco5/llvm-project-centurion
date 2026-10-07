//===-- CPU6RegisterInfo.cpp - CPU6 Register Information ---------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CPU6RegisterInfo.h"
#include "CPU6FrameLowering.h"
#include "CPU6InstrInfo.h"
#include "CPU6MachineFunctionInfo.h"
#include "MCTargetDesc/CPU6InstPrinter.h"
#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/CodeGen/LiveIntervals.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/RegisterScavenging.h"
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

StringRef CPU6RegisterInfo::getRegAsmName(MCRegister Reg) const {
  return CPU6InstPrinter::getRegisterName(Reg);
}

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

bool CPU6RegisterInfo::requiresRegisterScavenging(
    const MachineFunction &MF) const {
  // Indexed bignum displacements are a signed byte. The scavenger is how an
  // operand past that becomes ADD plus a register. Functions whose slots fit
  // do not walk the scavenger and do not grow a scratch area.
  return static_cast<const CPU6FrameLowering *>(
             MF.getSubtarget().getFrameLowering())
      ->bignumIndexedFrameMayOverflow(MF);
}

namespace {

// Distance from the frame register to this slot, plus the instruction's own
// displacement. S is not the frame register while a call has moved it.
int64_t frameDisp(MachineFunction &MF, int FI, int64_t Extra, int SPAdj,
                  Register &FrameReg) {
  int64_t Offset = MF.getSubtarget()
                       .getFrameLowering()
                       ->getFrameIndexReference(MF, FI, FrameReg)
                       .getFixed() +
                   Extra;
  assert((SPAdj == 0 || FrameReg == CPU6::rX) &&
         "a slot addressed from S while S is adjusted for a call");
  if (!isInt<16>(Offset))
    report_fatal_error("CPU6 frame offset does not fit in the displacement");
  return Offset;
}

enum class BnSideKind { Abs, Idx, Reg };

struct BnSideLoc {
  BnSideKind Kind;
  unsigned Op;
};

// Explicit operands are l, k, then the source tail, then the destination
// tail. An indexed tail is (base, disp).
BnSideLoc bnSideLoc(CPU6BignumMode Mode, bool IsSrc) {
  switch (Mode) {
  case CPU6BignumMode::AA:
    return {BnSideKind::Abs, IsSrc ? 2u : 3u};
  case CPU6BignumMode::AX:
    return IsSrc ? BnSideLoc{BnSideKind::Abs, 2}
                 : BnSideLoc{BnSideKind::Idx, 3};
  case CPU6BignumMode::AR:
    return IsSrc ? BnSideLoc{BnSideKind::Abs, 2}
                 : BnSideLoc{BnSideKind::Reg, 3};
  case CPU6BignumMode::XA:
    return IsSrc ? BnSideLoc{BnSideKind::Idx, 2}
                 : BnSideLoc{BnSideKind::Abs, 4};
  case CPU6BignumMode::XX:
    return IsSrc ? BnSideLoc{BnSideKind::Idx, 2}
                 : BnSideLoc{BnSideKind::Idx, 4};
  case CPU6BignumMode::XR:
    return IsSrc ? BnSideLoc{BnSideKind::Idx, 2}
                 : BnSideLoc{BnSideKind::Reg, 4};
  case CPU6BignumMode::RA:
    return IsSrc ? BnSideLoc{BnSideKind::Reg, 2}
                 : BnSideLoc{BnSideKind::Abs, 3};
  case CPU6BignumMode::RX:
    return IsSrc ? BnSideLoc{BnSideKind::Reg, 2}
                 : BnSideLoc{BnSideKind::Idx, 3};
  case CPU6BignumMode::RR:
    return {BnSideKind::Reg, IsSrc ? 2u : 3u};
  }
  llvm_unreachable("bad bignum mode");
}

CPU6BignumMode bnMode(BnSideKind Src, BnSideKind Dst) {
  if (Src == BnSideKind::Abs && Dst == BnSideKind::Abs)
    return CPU6BignumMode::AA;
  if (Src == BnSideKind::Abs && Dst == BnSideKind::Idx)
    return CPU6BignumMode::AX;
  if (Src == BnSideKind::Abs && Dst == BnSideKind::Reg)
    return CPU6BignumMode::AR;
  if (Src == BnSideKind::Idx && Dst == BnSideKind::Abs)
    return CPU6BignumMode::XA;
  if (Src == BnSideKind::Idx && Dst == BnSideKind::Idx)
    return CPU6BignumMode::XX;
  if (Src == BnSideKind::Idx && Dst == BnSideKind::Reg)
    return CPU6BignumMode::XR;
  if (Src == BnSideKind::Reg && Dst == BnSideKind::Abs)
    return CPU6BignumMode::RA;
  if (Src == BnSideKind::Reg && Dst == BnSideKind::Idx)
    return CPU6BignumMode::RX;
  return CPU6BignumMode::RR;
}

// True when some indexed frame operand does not fit in the signed byte.
// The walk is backwards and deletes this instruction once, so the check
// covers every frame operand, not only the one PEI asked about.
bool bnIndexedOverflows(MachineInstr &MI, int SPAdj) {
  MachineFunction &MF = *MI.getParent()->getParent();
  for (unsigned I = 0, E = MI.getNumOperands(); I + 1 < E; ++I) {
    if (!MI.getOperand(I).isFI())
      continue;
    Register FrameReg;
    int64_t Offset = frameDisp(MF, MI.getOperand(I).getIndex(),
                               MI.getOperand(I + 1).getImm(), SPAdj, FrameReg);
    if (!isInt<8>(Offset))
      return true;
  }
  return false;
}

// rM and rV are reserved, so isRegUsed reports them used or unused from that
// fact alone and never from liveness. A reload is XFR, which writes both.
bool flagLiveAfter(const MachineInstr &MI, Register Flag) {
  const MachineBasicBlock &MBB = *MI.getParent();
  const TargetRegisterInfo &TRI =
      *MBB.getParent()->getSubtarget().getRegisterInfo();
  for (auto I = std::next(MI.getIterator()); I != MBB.end(); ++I) {
    if (I->isDebugInstr())
      continue;
    if (I->readsRegister(Flag, &TRI))
      return true;
    if (I->modifiesRegister(Flag, &TRI))
      return false;
  }
  for (const MachineBasicBlock *Succ : MBB.successors())
    if (Succ->isLiveIn(Flag))
      return true;
  return false;
}

unsigned findFrameIndexOp(MachineInstr &MI) {
  for (unsigned I = 0, E = MI.getNumOperands(); I != E; ++I)
    if (MI.getOperand(I).isFI())
      return I;
  llvm_unreachable("spill has no frame index");
}

// A register the bignum can use as an address, defined by an ADD in front of
// it. A free register needs no spill. Otherwise save one the instruction does
// not itself use, into a far slot, and reload it afterwards. The reload writes
// Minus and Value, so it is not available while those flags are live.
Register obtainBnScratch(const CPU6RegisterInfo &This, MachineInstr &MI,
                         int SPAdj, RegScavenger *RS,
                         SmallVectorImpl<Register> &Taken) {
  MachineFunction &MF = *MI.getParent()->getParent();
  if (!RS)
    report_fatal_error(
        "CPU6 bignum indexed operand is out of range and no scavenger is available");

  auto Already = [&](Register R) {
    return llvm::is_contained(Taken, R);
  };
  Register Free = RS->scavengeRegisterBackwards(
      CPU6::GPRRegClass, MI.getIterator(), /*RestoreAfter=*/false, SPAdj,
      /*AllowSpill=*/false);
  if (Free && !Already(Free)) {
    RS->setRegUsed(Free);
    Taken.push_back(Free);
    return Free;
  }

  if (flagLiveAfter(MI, CPU6::rM) || flagLiveAfter(MI, CPU6::rV))
    report_fatal_error("CPU6 bignum indexed operand is out of range and a "
                       "reload would clobber live flags");

  const TargetRegisterInfo &TRI = *MF.getSubtarget().getRegisterInfo();
  const MachineRegisterInfo &MRI = MF.getRegInfo();
  Register Stolen;
  for (MCPhysReg R : CPU6::GPRRegClass) {
    if (MRI.isReserved(R) || Already(R))
      continue;
    if (MI.readsRegister(R, &TRI) || MI.modifiesRegister(R, &TRI))
      continue;
    Stolen = R;
    break;
  }
  if (!Stolen)
    report_fatal_error(
        "CPU6 bignum indexed operand is out of range and no register is free");

  CPU6FunctionInfo *Info = MF.getInfo<CPU6FunctionInfo>();
  unsigned Slot = Taken.size();
  if (Slot >= 2)
    report_fatal_error("CPU6 bignum address needs a third scratch register");
  int FI = Info->getBignumScratchSlot(Slot);
  if (FI < 0)
    report_fatal_error("CPU6 bignum scratch slot was not reserved");

  const TargetInstrInfo &TII = *MF.getSubtarget().getInstrInfo();
  MachineBasicBlock &MBB = *MI.getParent();
  const TargetRegisterClass *RC = &CPU6::GPRRegClass;
  TII.storeRegToStackSlot(MBB, MI.getIterator(), Stolen, /*IsKill=*/true, FI,
                          RC, Register());
  MachineInstr &Store = *std::prev(MI.getIterator());
  This.eliminateFrameIndex(Store, SPAdj, findFrameIndexOp(Store), RS);

  MachineBasicBlock::iterator ReloadAt = std::next(MI.getIterator());
  TII.loadRegFromStackSlot(MBB, ReloadAt, Stolen, FI, RC, Register());
  MachineInstr &Reload = *std::prev(ReloadAt);
  This.eliminateFrameIndex(Reload, SPAdj, findFrameIndexOp(Reload), RS);

  RS->setRegUsed(Stolen);
  Taken.push_back(Stolen);
  return Stolen;
}

struct BnResolved {
  BnSideKind Kind = BnSideKind::Reg;
  const MachineOperand *Orig = nullptr;
  Register Reg;
  int64_t Disp = 0;
  bool Kill = false;
};

BnResolved resolveBnSide(const CPU6RegisterInfo &This, MachineInstr &MI,
                         CPU6BignumMode Mode, bool IsSrc, int SPAdj,
                         RegScavenger *RS, SmallVectorImpl<Register> &Taken) {
  BnSideLoc Loc = bnSideLoc(Mode, IsSrc);
  BnResolved Out;
  Out.Kind = Loc.Kind;
  if (Loc.Kind != BnSideKind::Idx) {
    Out.Orig = &MI.getOperand(Loc.Op);
    return Out;
  }

  MachineOperand &Base = MI.getOperand(Loc.Op);
  int64_t Disp = MI.getOperand(Loc.Op + 1).getImm();
  if (!Base.isFI()) {
    if (!Base.isReg())
      report_fatal_error(
          "CPU6 bignum index base is not a register or a frame index");
    Out.Reg = Base.getReg();
    Out.Disp = Disp;
    Out.Kill = Base.isKill();
    return Out;
  }

  MachineFunction &MF = *MI.getParent()->getParent();
  Register FrameReg;
  int64_t Offset = frameDisp(MF, Base.getIndex(), Disp, SPAdj, FrameReg);
  // Displacement 0 stays (S),0. Naming S as a bare register is a different
  // opcode, and that rewrite is not done here.
  if (isInt<8>(Offset)) {
    Out.Reg = FrameReg;
    Out.Disp = Offset;
    return Out;
  }

  Out.Kind = BnSideKind::Reg;
  Out.Kill = true;
  Out.Reg = obtainBnScratch(This, MI, SPAdj, RS, Taken);
  const TargetInstrInfo &TII = *MF.getSubtarget().getInstrInfo();
  BuildMI(*MI.getParent(), MI, MI.getDebugLoc(), TII.get(CPU6::ADDimm), Out.Reg)
      .addReg(FrameReg)
      .addImm(Offset);
  return Out;
}

void addBnSide(MachineInstrBuilder &MIB, const BnResolved &Side) {
  if (Side.Orig) {
    MIB.add(*Side.Orig);
    return;
  }
  if (Side.Kind == BnSideKind::Idx) {
    MIB.addReg(Side.Reg, getKillRegState(Side.Kill));
    MIB.addImm(Side.Disp);
    return;
  }
  MIB.addReg(Side.Reg, getKillRegState(Side.Kill));
}

// Replace an indexed bignum that names a slot past the signed byte. Both
// frame operands are resolved here: PEI is walking backwards and treats a
// true return as "this instruction is gone".
bool rewriteOutOfRangeBignum(const CPU6RegisterInfo &This, MachineInstr &MI,
                             CPU6BignumMode Mode, int SPAdj, RegScavenger *RS) {
  SmallVector<Register, 2> Taken;
  BnResolved Src = resolveBnSide(This, MI, Mode, /*IsSrc=*/true, SPAdj, RS, Taken);
  BnResolved Dst =
      resolveBnSide(This, MI, Mode, /*IsSrc=*/false, SPAdj, RS, Taken);
  CPU6BignumMode NewMode = bnMode(Src.Kind, Dst.Kind);
  MachineFunction &MF = *MI.getParent()->getParent();
  const TargetInstrInfo &TII = *MF.getSubtarget().getInstrInfo();
  MachineInstrBuilder MIB =
      BuildMI(*MI.getParent(), MI, MI.getDebugLoc(),
              TII.get(cpu6BignumOpcode(MI.getOpcode(), NewMode)));
  MIB.addImm(MI.getOperand(0).getImm());
  MIB.addImm(MI.getOperand(1).getImm());
  addBnSide(MIB, Src);
  addBnSide(MIB, Dst);
  MIB.cloneMemRefs(MI);
  MIB.setMIFlags(MI.getFlags());
  MI.eraseFromParent();
  return true;
}

} // namespace

bool CPU6RegisterInfo::eliminateFrameIndex(MachineBasicBlock::iterator MI,
                                           int SPAdj, unsigned FIOperandNum,
                                           RegScavenger *RS) const {
  // Every frame access is (frame index, displacement), the frame index in the
  // base operand. The default getFrameIndexReference returns the object
  // offset plus the frame size: the distance from S once the prologue has
  // reserved the frame. An incoming stack argument in a realigned function
  // is addressed from X instead, and so is every slot of a function with a
  // variable-sized object. Debug info asks the same hook. Only that second
  // kind of function moves S around a call, and X does not move.
  MachineInstr &Instr = *MI;
  CPU6BignumMode Mode;
  if (classifyCPU6Bignum(Instr.getOpcode(), Mode) &&
      isCPU6BignumIndexed(Mode) && bnIndexedOverflows(Instr, SPAdj))
    return rewriteOutOfRangeBignum(*this, Instr, Mode, SPAdj, RS);

  MachineFunction &MF = *Instr.getParent()->getParent();
  MachineOperand &Disp = Instr.getOperand(FIOperandNum + 1);
  Register FrameReg;
  int64_t Offset = frameDisp(MF, Instr.getOperand(FIOperandNum).getIndex(),
                             Disp.getImm(), SPAdj, FrameReg);

  // XFR, STR, and ADD take a word. The others take a signed byte. A word
  // LDA/STA out of that range is the XFR/STR indexed form instead: same
  // operands and flags, one byte longer, any register. FIL and a one-sided
  // indexed MVF widen to the disp16 opcode the same way. An indexed bignum
  // that does not fit was rewritten above; one that fits is patched here,
  // including a displacement of 0.
  unsigned Opc = Instr.getOpcode();
  bool WordDisp =
      Opc == CPU6::XFRidx || Opc == CPU6::STRidx || Opc == CPU6::ADDimm;
  if (!WordDisp && !isInt<8>(Offset)) {
    const TargetInstrInfo &TII = *MF.getSubtarget().getInstrInfo();
    if (Opc == CPU6::LDAfi)
      Instr.setDesc(TII.get(CPU6::XFRidx));
    else if (Opc == CPU6::STAfi)
      Instr.setDesc(TII.get(CPU6::STRidx));
    else if (Opc == CPU6::FIL_I8)
      Instr.setDesc(TII.get(CPU6::FIL_I16));
    else if (Opc == CPU6::MVF_I8R)
      Instr.setDesc(TII.get(CPU6::MVF_I16R));
    else if (Opc == CPU6::MVF_RI8)
      Instr.setDesc(TII.get(CPU6::MVF_RI16));
    else
      report_fatal_error("CPU6 byte frame access is out of displacement range");
  }
  Instr.getOperand(FIOperandNum).ChangeToRegister(FrameReg, /*isDef=*/false);
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

Register CPU6RegisterInfo::getFrameRegister(const MachineFunction &MF) const {
  // Every slot is addressed from S, including in a realigned function: there
  // X only remembers S for the epilogue, and the distance from X to a slot
  // depends on how far the prologue rounded S down. A variable-sized object
  // moves S at run time, so then every slot is addressed from X.
  return MF.getFrameInfo().hasVarSizedObjects() ? CPU6::rX : CPU6::rS;
}

bool CPU6RegisterInfo::shouldRealignStack(const MachineFunction &MF) const {
  const MachineFrameInfo &MFI = MF.getFrameInfo();
  if (!MFI.hasVarSizedObjects())
    return TargetRegisterInfo::shouldRealignStack(MF);
  Align StackAlign = MF.getSubtarget().getFrameLowering()->getStackAlign();
  for (int FI = 0, E = MFI.getObjectIndexEnd(); FI != E; ++FI)
    if (!MFI.isDeadObjectIndex(FI) && !MFI.isVariableSizedObjectIndex(FI) &&
        MFI.getObjectAlign(FI) > StackAlign)
      return true;
  return false;
}
