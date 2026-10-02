//===-- CPU6FrameLowering.cpp - CPU6 Frame Information -----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CPU6FrameLowering.h"
#include "CPU6InstrInfo.h"
#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/MathExtras.h"

using namespace llvm;

// Bytes STK and POP already move. The prologue copy into X happens after
// those pushes, so X holds incoming S minus this many bytes.
static uint64_t calleeSavedBytes(const MachineFunction &MF) {
  const MachineFrameInfo &MFI = MF.getFrameInfo();
  uint64_t CalleeSaved = 0;
  for (const CalleeSavedInfo &CS : MFI.getCalleeSavedInfo()) {
    if (!CS.isSpilledToReg())
      CalleeSaved += static_cast<uint64_t>(MFI.getObjectSize(CS.getFrameIdx()));
  }
  return CalleeSaved;
}

// Bytes of the frame that STK and POP already move. The rest is locals plus
// the reserved outgoing-argument area. The prologue subtracts it from S and
// the epilogue adds it back. Together with the callee-saved area it equals
// getStackSize(), which is what eliminateFrameIndex adds to a slot's offset.
static uint64_t localFrameBytes(const MachineFunction &MF) {
  uint64_t CalleeSaved = calleeSavedBytes(MF);
  uint64_t StackSize = MF.getFrameInfo().getStackSize();
  if (CalleeSaved > StackSize)
    report_fatal_error("CPU6 callee-saved area is larger than the frame");
  return StackSize - CalleeSaved;
}

// S = S op Imm, where op is ADDimm or ANDimm (dst = src op imm16).
static void buildStackPointerOp(MachineBasicBlock &MBB,
                                MachineBasicBlock::iterator MBBI,
                                unsigned Opcode, int64_t Imm,
                                MachineInstr::MIFlag Flag) {
  if (!isInt<16>(Imm))
    report_fatal_error("CPU6 frame adjustment does not fit in an immediate");
  const TargetInstrInfo &TII = *MBB.getParent()->getSubtarget().getInstrInfo();
  DebugLoc DL = MBBI != MBB.end() ? MBBI->getDebugLoc() : DebugLoc();
  BuildMI(MBB, MBBI, DL, TII.get(Opcode), CPU6::rS)
      .addReg(CPU6::rS)
      .addImm(Imm)
      .setMIFlag(Flag);
}

static void buildCopy(MachineBasicBlock &MBB, MachineBasicBlock::iterator MBBI,
                      MCRegister Dst, MCRegister Src,
                      MachineInstr::MIFlag Flag) {
  const TargetInstrInfo &TII = *MBB.getParent()->getSubtarget().getInstrInfo();
  DebugLoc DL = MBBI != MBB.end() ? MBBI->getDebugLoc() : DebugLoc();
  BuildMI(MBB, MBBI, DL, TII.get(CPU6::XFR), Dst)
      .addReg(Src)
      .setMIFlag(Flag);
}

// A slot aligned above the one-byte stack alignment means the prologue
// rounds S down. How far depends on S at run time, so the epilogue cannot
// undo it with a constant. X keeps S from just after the callee-saved pushes.
bool CPU6FrameLowering::hasFPImpl(const MachineFunction &MF) const {
  return MF.getSubtarget().getRegisterInfo()->hasStackRealignment(MF);
}

void CPU6FrameLowering::determineCalleeSaves(MachineFunction &MF,
                                             BitVector &SavedRegs,
                                             RegScavenger *RS) const {
  TargetFrameLowering::determineCalleeSaves(MF, SavedRegs, RS);
  // The caller's X is overwritten by the frame pointer.
  if (hasFP(MF))
    SavedRegs.set(CPU6::rX);
}

void CPU6FrameLowering::emitPrologue(MachineFunction &MF,
                                     MachineBasicBlock &MBB) const {
  // STK is already at the top of the block and has lowered S by the
  // callee-saved area. Lower S the rest of the way for locals, after those
  // STKs, so the saved registers stay nearest the incoming S.
  MachineBasicBlock::iterator MBBI = MBB.begin();
  while (MBBI != MBB.end() && MBBI->getFlag(MachineInstr::FrameSetup))
    ++MBBI;
  bool Realign = hasFP(MF);
  if (Realign) {
    if (!MF.getRegInfo().isReserved(CPU6::rX))
      report_fatal_error("CPU6 frame pointer X was not reserved");
    buildCopy(MBB, MBBI, CPU6::rX, CPU6::rS, MachineInstr::FrameSetup);
  }
  if (int64_t Locals = static_cast<int64_t>(localFrameBytes(MF)))
    buildStackPointerOp(MBB, MBBI, CPU6::ADDimm, -Locals,
                        MachineInstr::FrameSetup);
  // Slot offsets are aligned relative to the top of the frame, and the frame
  // size is a multiple of the largest alignment. Rounding S down to that
  // alignment makes every slot address aligned, and only adds space below
  // the locals.
  if (Realign)
    buildStackPointerOp(
        MBB, MBBI, CPU6::ANDimm,
        -static_cast<int64_t>(MF.getFrameInfo().getMaxAlign().value()),
        MachineInstr::FrameSetup);
}

void CPU6FrameLowering::emitEpilogue(MachineFunction &MF,
                                     MachineBasicBlock &MBB) const {
  // Raise S back over the locals before POP gives back the callee-saved area.
  MachineBasicBlock::iterator Insert = MBB.getFirstTerminator();
  while (Insert != MBB.begin()) {
    MachineBasicBlock::iterator Prev = std::prev(Insert);
    if (!Prev->getFlag(MachineInstr::FrameDestroy))
      break;
    Insert = Prev;
  }
  if (hasFP(MF)) {
    buildCopy(MBB, Insert, CPU6::rS, CPU6::rX, MachineInstr::FrameDestroy);
    return;
  }
  if (int64_t Locals = static_cast<int64_t>(localFrameBytes(MF)))
    buildStackPointerOp(MBB, Insert, CPU6::ADDimm, Locals,
                        MachineInstr::FrameDestroy);
}

bool CPU6FrameLowering::hasReservedCallFrame(const MachineFunction &MF) const {
  // Outgoing stack arguments are stored at the live S. Reserving the area in
  // the prologue keeps locals above those stores, and ADJCALLSTACKDOWN/UP
  // delete instead of moving S, so a frame index never sees a non-zero SPAdj.
  // A variable-sized alloca would move S after the prologue; nothing selects
  // that yet.
  if (MF.getFrameInfo().hasVarSizedObjects())
    report_fatal_error("CPU6 variable-sized stack objects are not supported");
  return true;
}

MachineBasicBlock::iterator CPU6FrameLowering::eliminateCallFramePseudoInstr(
    MachineFunction &MF, MachineBasicBlock &MBB,
    MachineBasicBlock::iterator MI) const {
  // JSR pushes the caller's X on its own and RSR pops it. The argument words
  // above that push are the reserved area, so the pseudos have nothing to do.
  (void)MF;
  return MBB.erase(MI);
}

StackOffset
CPU6FrameLowering::getFrameIndexReference(const MachineFunction &MF, int FI,
                                          Register &FrameReg) const {
  const MachineFrameInfo &MFI = MF.getFrameInfo();
  // JSR leaves S pointing at the saved X. An incoming argument is a positive
  // offset from that S. After a realignment the epilogue's X is the only
  // register that still holds it: X was copied just after the pushes, and the
  // AND may have lowered S by a runtime amount.
  if (hasFP(MF) && MFI.isFixedObjectIndex(FI) && MFI.getObjectOffset(FI) >= 0) {
    FrameReg = CPU6::rX;
    return StackOffset::getFixed(MFI.getObjectOffset(FI) +
                                 static_cast<int64_t>(calleeSavedBytes(MF)));
  }
  return TargetFrameLowering::getFrameIndexReference(MF, FI, FrameReg);
}

// A register the function already reads (an argument in Y or Z) must stay
// live across the STK. One it only clobbers is dead after the value is saved.
static RegState killIfIncomingIsDead(MachineBasicBlock &MBB, MCRegister Reg) {
  if (MBB.isLiveIn(Reg))
    return RegState::NoFlags;
  MBB.addLiveIn(Reg);
  return RegState::Kill;
}

// Bit 0 is X, bit 1 is Y, bit 2 is Z. Each saved word owns a 2-byte slot, and
// one STK covers a contiguous stretch of those bits. A gap (X and Z, not Y)
// is two instructions: pushing Y as well would move S by more than the slots.
static unsigned savedRegMask(MachineFunction &MF,
                             ArrayRef<CalleeSavedInfo> CSI) {
  const MachineFrameInfo &MFI = MF.getFrameInfo();
  unsigned Mask = 0;
  uint64_t Reserved = 0;
  for (const CalleeSavedInfo &CS : CSI) {
    if (CS.isSpilledToReg())
      report_fatal_error("CPU6 callee-saved register spilled to a register");
    Register Reg = CS.getReg();
    if (Reg == CPU6::rX)
      Mask |= 1u;
    else if (Reg == CPU6::rY)
      Mask |= 2u;
    else if (Reg == CPU6::rZ)
      Mask |= 4u;
    else
      report_fatal_error("CPU6 can only save X, Y, and Z");
    Reserved += static_cast<uint64_t>(MFI.getObjectSize(CS.getFrameIdx()));
  }
  // popcount is the number of words. Two bytes each must match the slots,
  // which is also what localFrameBytes later subtracts from the frame.
  if (Reserved != 2 * static_cast<uint64_t>(llvm::popcount(Mask)))
    report_fatal_error("CPU6 STK size does not match the callee-saved slots");
  return Mask;
}

struct StackRun {
  MCRegister First;
  unsigned CountMinus1;
  MCRegister Extra1;
  MCRegister Extra2;
};

// Where each word lands has to match the slots LLVM assigned. CSR lists Z,
// Y, X, so Z's slot is nearest the incoming S and X's is lowest. One STK
// already leaves the run that way. For the gap, Z has to be pushed before X.
// One register pushes 2 bytes (operand 1), two push 4 (operand 3), all three
// push 6 (operand 5).
static unsigned runsFor(unsigned Mask, StackRun Out[2]) {
  unsigned N = 0;
  auto Add = [&](MCRegister First, unsigned CountMinus1, MCRegister Extra1 = {},
                 MCRegister Extra2 = {}) {
    Out[N++] = {First, CountMinus1, Extra1, Extra2};
  };
  switch (Mask) {
  case 0b001:
    Add(CPU6::rX, 1);
    break;
  case 0b010:
    Add(CPU6::rY, 1);
    break;
  case 0b100:
    Add(CPU6::rZ, 1);
    break;
  case 0b011:
    Add(CPU6::rX, 3, CPU6::rY);
    break;
  case 0b110:
    Add(CPU6::rY, 3, CPU6::rZ);
    break;
  case 0b111:
    Add(CPU6::rX, 5, CPU6::rY, CPU6::rZ);
    break;
  case 0b101:
    Add(CPU6::rZ, 1);
    Add(CPU6::rX, 1);
    break;
  default:
    llvm_unreachable("not a set of X, Y, Z");
  }
  return N;
}

static void emitRun(MachineBasicBlock &MBB, MachineBasicBlock::iterator MI,
                    const DebugLoc &DL, const TargetInstrInfo &TII,
                    bool IsSpill, const StackRun &Run) {
  MachineInstrBuilder MIB;
  if (IsSpill) {
    MIB = BuildMI(MBB, MI, DL, TII.get(CPU6::STK))
              .addReg(Run.First, killIfIncomingIsDead(MBB, Run.First))
              .addImm(Run.CountMinus1)
              .setMIFlag(MachineInstr::FrameSetup);
    for (MCRegister Extra : {Run.Extra1, Run.Extra2})
      if (Extra.isValid())
        MIB.addReg(Extra, RegState::Implicit | killIfIncomingIsDead(MBB, Extra));
    return;
  }
  MIB = BuildMI(MBB, MI, DL, TII.get(CPU6::POP), Run.First)
            .addImm(Run.CountMinus1)
            .setMIFlag(MachineInstr::FrameDestroy);
  for (MCRegister Extra : {Run.Extra1, Run.Extra2})
    if (Extra.isValid())
      MIB.addReg(Extra, RegState::ImplicitDefine);
}

static void emitSaves(MachineBasicBlock &MBB, MachineBasicBlock::iterator MI,
                      ArrayRef<CalleeSavedInfo> CSI, bool IsSpill) {
  MachineFunction &MF = *MBB.getParent();
  unsigned Mask = savedRegMask(MF, CSI);
  StackRun Runs[2];
  unsigned N = runsFor(Mask, Runs);
  const TargetInstrInfo &TII = *MF.getSubtarget().getInstrInfo();
  DebugLoc DL = MBB.findDebugLoc(MI);
  // POP undoes STK, so the last push is popped first. Each BuildMI inserts
  // at MI, which is the terminator, and inserting the last run first leaves
  // that POP nearest the return.
  if (IsSpill) {
    for (unsigned I = 0; I < N; ++I)
      emitRun(MBB, MI, DL, TII, true, Runs[I]);
  } else {
    for (unsigned I = N; I-- > 0;)
      emitRun(MBB, MI, DL, TII, false, Runs[I]);
  }
}

bool CPU6FrameLowering::spillCalleeSavedRegisters(
    MachineBasicBlock &MBB, MachineBasicBlock::iterator MI,
    ArrayRef<CalleeSavedInfo> CSI, const TargetRegisterInfo *) const {
  emitSaves(MBB, MI, CSI, /*IsSpill=*/true);
  return true;
}

bool CPU6FrameLowering::restoreCalleeSavedRegisters(
    MachineBasicBlock &MBB, MachineBasicBlock::iterator MI,
    MutableArrayRef<CalleeSavedInfo> CSI, const TargetRegisterInfo *) const {
  emitSaves(MBB, MI, CSI, /*IsSpill=*/false);
  return true;
}
