//===-- CPU6ISelLowering.cpp - CPU6 DAG Lowering Implementation -*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CPU6ISelLowering.h"
#include "CPU6InstrInfo.h"
#include "CPU6Subtarget.h"
#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "llvm/CodeGen/CallingConvLower.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineMemOperand.h"
#include "llvm/CodeGen/SelectionDAGAddressAnalysis.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/GlobalVariable.h"
#include <algorithm>
#include <optional>

using namespace llvm;

#define GET_CALLING_CONV_IMPL
#include "CPU6GenCallingConv.inc"

// CC_CPU6 promotes an i8 to i16. LocInfo says how, and the register or the
// stack slot is the widened value.
static SDValue extendToLoc(SelectionDAG &DAG, const SDLoc &DL, SDValue Val,
                           const CCValAssign &VA) {
  switch (VA.getLocInfo()) {
  case CCValAssign::Full:
    return Val;
  case CCValAssign::SExt:
    return DAG.getNode(ISD::SIGN_EXTEND, DL, VA.getLocVT(), Val);
  case CCValAssign::ZExt:
    return DAG.getNode(ISD::ZERO_EXTEND, DL, VA.getLocVT(), Val);
  case CCValAssign::AExt:
    return DAG.getNode(ISD::ANY_EXTEND, DL, VA.getLocVT(), Val);
  default:
    llvm_unreachable("unexpected argument promotion");
  }
}

// The widened value arrives in a word. Record the extension, then take the
// original width back.
static SDValue narrowFromLoc(SelectionDAG &DAG, const SDLoc &DL, SDValue Val,
                             const CCValAssign &VA) {
  if (VA.getLocInfo() == CCValAssign::SExt)
    Val = DAG.getNode(ISD::AssertSext, DL, VA.getLocVT(), Val,
                      DAG.getValueType(VA.getValVT()));
  else if (VA.getLocInfo() == CCValAssign::ZExt)
    Val = DAG.getNode(ISD::AssertZext, DL, VA.getLocVT(), Val,
                      DAG.getValueType(VA.getValVT()));
  if (VA.getLocVT() != VA.getValVT())
    Val = DAG.getNode(ISD::TRUNCATE, DL, VA.getValVT(), Val);
  return Val;
}

CPU6TargetLowering::CPU6TargetLowering(const TargetMachine &TM,
                                       const CPU6Subtarget &STI)
    : TargetLowering(TM, STI) {
  // GPR is i16 and GPRB is i8. Registering them makes both legal and tells
  // the legalizer to expand anything wider (so an i32 add is not one
  // instruction) and promote i1 to i8.
  addRegisterClass(MVT::i8, &CPU6::GPRBRegClass);
  addRegisterClass(MVT::i16, &CPU6::GPRRegClass);
  computeRegisterProperties(STI.getRegisterInfo());

  // A byte memory access only fills or reads the byte register; nothing
  // extends on the way in or truncates on the way out. Split an extending
  // load into a byte load plus an extend, and a truncating store into a
  // truncate plus a byte store.
  for (MVT VT : {MVT::i8, MVT::i16})
    setLoadExtAction({ISD::EXTLOAD, ISD::ZEXTLOAD, ISD::SEXTLOAD}, VT, MVT::i1,
                     Promote);
  setLoadExtAction({ISD::EXTLOAD, ISD::ZEXTLOAD, ISD::SEXTLOAD}, MVT::i16,
                   MVT::i8, Expand);
  setTruncStoreAction(MVT::i16, MVT::i8, Expand);
  // The low bit of an ALU opcode's high nibble is what makes it a word
  // operation: ADDB is 0x40 and ADD is 0x50. MUL is 0x77, so the byte slot
  // would be 0x67, and that opcode is the block-memory group (memcpy, memset,
  // and the rest of the 0x47 forms). webCenREE's multiply is the word
  // product, and EtchedPixels implements it as mul16. An i8 multiply is the
  // low byte of the i16 MUL.
  setOperationAction(ISD::MUL, MVT::i8, Promote);
  // i8 mulhu is bits [15:8] of that same product, not an i16 mulhu. Promoting
  // it would take bits [31:16], which are 0 once the bytes have been
  // zero-extended. MULHUb expands to the zero-extend, word MUL, and shift.
  setOperationAction(ISD::MULHU, MVT::i8, Legal);
  // i32 and i64 are illegal, so a multiply of either is split into
  // half-width pieces. The bottom of that split is an i16 umul_lohi, the
  // 16x16->32 product. MULAB is that product in A:B. A plain i16 mul is
  // MULB and only keeps the low half.
  setOperationAction(ISD::UMUL_LOHI, MVT::i16, Legal);
  // The low half of a signed product matches the unsigned one. LowerSmulLoHi
  // corrects the high half. A sign-extended widening multiply selects this
  // rather than the unsigned node.
  setOperationAction(ISD::SMUL_LOHI, MVT::i16, Custom);
  // The high half alone is the second result of the same pair. Left at the
  // default Legal, nothing would select it.
  setOperationAction(ISD::MULHU, MVT::i16, Expand);
  setOperationAction(ISD::MULHS, MVT::i16, Expand);
  // DIV is the word opcode 0x78. There is no byte divide. A byte quotient or
  // remainder is promoted to i16: signed operands are sign-extended, unsigned
  // operands are zero-extended, and the i16 result is truncated. Promoting
  // an i8 urem stops there. It yields an i16 urem, which is not an
  // instruction; the Expand below rewrites that i16 urem.
  setOperationAction({ISD::SDIV, ISD::UDIV, ISD::SREM, ISD::UREM}, MVT::i8,
                     Promote);
  // expandREM prefers a *DIVREM node whenever that node is Legal or Custom.
  // Both default to Legal, and nothing selects them, so leave them Expand.
  // Otherwise an unsigned remainder becomes an unselectable udivrem instead
  // of udiv, mul, and sub.
  for (MVT VT : {MVT::i8, MVT::i16})
    setOperationAction({ISD::SDIVREM, ISD::UDIVREM}, VT, Expand);
  // Unsigned remainder has no opcode. i16 UDIV is the low half of DIV, so
  // expandREM rewrites x % y as x - (x / y) * y. That is also the sequence
  // an i8 urem reaches after promotion.
  setOperationAction(ISD::UREM, MVT::i16, Expand);
  // DIV is unsigned. Signed quotient and remainder are lowered onto it.
  setOperationAction({ISD::SDIV, ISD::SREM}, MVT::i16, Custom);
  setOperationAction(ISD::SIGN_EXTEND_INREG, MVT::i1, Expand);
  // A condition only exists in the flags, as a compare glued to the branch or
  // select that reads it. setcc and select become select_cc, brcond br_cc.
  for (MVT VT : {MVT::i8, MVT::i16}) {
    setOperationAction({ISD::BR_CC, ISD::SELECT_CC}, VT, Custom);
    setOperationAction({ISD::SETCC, ISD::SELECT}, VT, Expand);
    // SLR and SRR take an immediate count, so a constant shift stays a
    // pattern. Returning the node from LowerShift leaves that pattern in
    // place. A variable count has no instruction; the pseudo it matches is
    // a one-bit loop. Expanding a scalar shift is not available here.
    setOperationAction({ISD::SHL, ISD::SRA, ISD::SRL}, VT, Custom);
    // No count-leading-zeros or popcount opcode. Both expand to shifts and
    // adds. Soft-float counts leading zeros of a word and of a widened
    // integer, so leaving either Legal is a node nothing selects.
    setOperationAction({ISD::CTLZ, ISD::CTTZ, ISD::CTPOP}, VT, Expand);
  }
  // A variable shift of an i32 or i64 is custom-lowered while the value is
  // still wide (ReplaceNodeResults), into one N-word loop. A constant still
  // takes ExpandShiftByConstant: that hook returns without a result for a
  // constant count. Parts are the same loop for a node that arrives already
  // split. Left at the default Legal, isel dies on shl_parts.
  setOperationAction({ISD::SHL, ISD::SRL, ISD::SRA}, MVT::i32, Custom);
  setOperationAction({ISD::SHL, ISD::SRL, ISD::SRA}, MVT::i64, Custom);
  setOperationAction({ISD::SHL_PARTS, ISD::SRL_PARTS, ISD::SRA_PARTS}, MVT::i16,
                     Custom);
  setOperationAction(ISD::BRCOND, MVT::Other, Expand);
  // Nothing selects a jump table, so a switch is a tree of compares.
  setMinimumJumpTableEntries(UINT_MAX);
  // S is the stack pointer the prologue adjusts. Callee-saved spills go
  // through it via STK and POP.
  setStackPointerRegisterToSaveRestore(CPU6::rS);
  // A variable-sized alloca is S -= size, then an AND with the negated
  // alignment when that is above one byte; the result is the new S. Slots
  // are then addressed from X (CPU6FrameLowering::getFrameIndexReference),
  // and each call lowers S for its own arguments. stacksave and
  // stackrestore copy S.
  setOperationAction(ISD::DYNAMIC_STACKALLOC, MVT::i16, Expand);
  setOperationAction({ISD::STACKSAVE, ISD::STACKRESTORE}, MVT::Other, Expand);

  // One load and store pair moves up to two bytes. From three bytes on, one
  // MVF or FIL (CPU6SelectionDAGInfo) is shorter and about as fast.
  MaxStoresPerMemcpy = MaxStoresPerMemcpyOptSize = 1;
  MaxStoresPerMemmove = MaxStoresPerMemmoveOptSize = 1;
  MaxStoresPerMemset = MaxStoresPerMemsetOptSize = 1;

  // No atomic instructions and no atomic libcalls. Keep the default of 0
  // explicit so a later change cannot silently grow inline atomics.
  setMaxAtomicSizeInBitsSupported(0);

  setBooleanContents(ZeroOrOneBooleanContent);
  setBooleanVectorContents(ZeroOrOneBooleanContent);
  // Keep the scheduled order close to the IR while the patterns are new.
  setSchedulingPreference(Sched::Source);
  setMinFunctionAlignment(Align(1));

  // Fold i32/i64 mem op trees into 0x46 bignum before they split to i16.
  setTargetDAGCombine(ISD::STORE);
  setTargetDAGCombine(ISD::SETCC);
  // A carry or borrow added to a word becomes a conditional INR or DCR.
  setTargetDAGCombine({ISD::ADD, ISD::SUB});
}

// The base class only resolves a brace name such as "{A}". "r" has to name
// a class or the allocator has nothing to put %0 in. A byte is a byte
// register; a wider value is one GPR per word.
std::pair<unsigned, const TargetRegisterClass *>
CPU6TargetLowering::getRegForInlineAsmConstraint(const TargetRegisterInfo *TRI,
                                                 StringRef Constraint,
                                                 MVT VT) const {
  if (Constraint.size() == 1 && Constraint[0] == 'r') {
    if (VT == MVT::i8 || VT == MVT::i1)
      return std::make_pair(0U, &CPU6::GPRBRegClass);
    return std::make_pair(0U, &CPU6::GPRRegClass);
  }
  return TargetLowering::getRegForInlineAsmConstraint(TRI, Constraint, VT);
}

namespace {

// Length-1 nibble for a bignum operand. Only i32 and i64 are folded today.
std::optional<unsigned> bignumLenMinus1(EVT VT) {
  if (VT == MVT::i32)
    return 3;
  if (VT == MVT::i64)
    return 7;
  return std::nullopt;
}

// A plain, non-extending load of exactly VT.
LoadSDNode *getBignumLoad(SDValue V, EVT VT) {
  auto *Ld = dyn_cast<LoadSDNode>(V);
  if (!Ld || !Ld->isSimple() || Ld->isIndexed() ||
      Ld->getExtensionType() != ISD::NON_EXTLOAD || Ld->getMemoryVT() != VT)
    return nullptr;
  return Ld;
}

// Byte distance between two accesses, when they are known to share a base.
std::optional<int64_t> addressDelta(const MemSDNode *A, const MemSDNode *B,
                                    const SelectionDAG &DAG) {
  int64_t Off;
  if (BaseIndexOffset::match(A, DAG).equalBaseIndex(
          BaseIndexOffset::match(B, DAG), DAG, Off))
    return Off;
  return std::nullopt;
}

// The bignum instruction runs where the store (or compare) is, so every load
// folded into it must see memory as it is there. Loads that start from one
// chain have no write between them.
bool loadsShareMemoryState(ArrayRef<LoadSDNode *> Loads) {
  return all_of(Loads, [&](LoadSDNode *Ld) {
    return Ld->getChain() == Loads[0]->getChain();
  });
}

// ... and the store's chain adds nothing to that chain but those loads.
bool onlyLoadsJoinChain(SDValue StoreChain, SDValue Root) {
  auto IsRootOrRootLoad = [&](SDValue Op) {
    if (Op == Root)
      return true;
    auto *Ld = dyn_cast<LoadSDNode>(Op.getNode());
    return Ld && Op.getResNo() == 1 && Ld->getChain() == Root;
  };
  if (StoreChain.getOpcode() != ISD::TokenFactor)
    return IsRootOrRootLoad(StoreChain);
  return all_of(StoreChain->op_values(), IsRootOrRootLoad);
}

// How a source access sits against the destination store.
enum class Overlap {
  Same,     // the same bytes
  Disjoint, // proven not to touch
  Unknown,  // different pointers that may or may not be the same at run time
  Partial,  // proven to overlap without being the same bytes
};

Overlap classifyOverlap(const MemSDNode *Src, const StoreSDNode *Dest,
                        SelectionDAG &DAG) {
  int64_t Bytes = Dest->getMemoryVT().getStoreSize().getFixedValue();
  if (std::optional<int64_t> Delta = addressDelta(Src, Dest, DAG)) {
    if (*Delta == 0)
      return Overlap::Same;
    return (*Delta > -Bytes && *Delta < Bytes) ? Overlap::Partial
                                               : Overlap::Disjoint;
  }
  bool IsAlias;
  LocationSize Size = LocationSize::precise(Bytes);
  if (BaseIndexOffset::computeAliasing(Src, Size, Dest, Size, DAG, IsAlias))
    return IsAlias ? Overlap::Partial : Overlap::Disjoint;
  return Overlap::Unknown;
}

} // namespace

// store (load Src), Dest                           -> ZAD
// store (sub 0, (load Src)), Dest                   -> ZSU
// store (add/sub/mul/sdiv (load Dest), (load Src)), Dest -> BNA/BNS/M/D
// store (srem (load Num), (load Den)), Dest         -> DRM
// Each is Dest := Dest op Src, so Src - Dest and Src / Dest are not folded.
// The instruction works a byte at a time, which equals load-then-store when
// Src and Dest are the same bytes or disjoint. Both were run on the machine at
// 4 and 8 bytes, with negative values, for ZAD, BNA, BNS, ZSU, M and D, so
// those fold whether the addresses are equal, apart, or not known to differ.
// A partial overlap never folds.
SDValue CPU6TargetLowering::combineBignumStore(StoreSDNode *St,
                                               SelectionDAG &DAG) const {
  EVT VT = St->getMemoryVT();
  auto Len = bignumLenMinus1(VT);
  if (!Len || !St->isSimple() || St->isIndexed() || St->isTruncatingStore())
    return SDValue();

  SDValue Val = St->getValue();
  if (Val.getOpcode() == ISD::SREM)
    return combineBignumRem(St, DAG);

  unsigned Opc;
  LoadSDNode *Src;
  SmallVector<LoadSDNode *, 2> Loads;
  if (LoadSDNode *Ld = getBignumLoad(Val, VT)) {
    Opc = CPU6ISD::BN_MOV;
    Src = Ld;
    Loads = {Ld};
  } else if (Val.getOpcode() == ISD::SUB && isNullConstant(Val.getOperand(0))) {
    Src = getBignumLoad(Val.getOperand(1), VT);
    if (!Src)
      return SDValue();
    Opc = CPU6ISD::BN_NEG;
    Loads = {Src};
  } else if (Val.getOpcode() == ISD::ADD || Val.getOpcode() == ISD::SUB ||
             Val.getOpcode() == ISD::MUL || Val.getOpcode() == ISD::SDIV) {
    LoadSDNode *L0 = getBignumLoad(Val.getOperand(0), VT);
    LoadSDNode *L1 = getBignumLoad(Val.getOperand(1), VT);
    if (!L0 || !L1)
      return SDValue();
    bool Commutes =
        Val.getOpcode() == ISD::ADD || Val.getOpcode() == ISD::MUL;
    if (addressDelta(L0, St, DAG) == 0)
      Src = L1;
    else if (Commutes && addressDelta(L1, St, DAG) == 0)
      Src = L0;
    else
      return SDValue();
    switch (Val.getOpcode()) {
    case ISD::ADD:
      Opc = CPU6ISD::BN_ADD;
      break;
    case ISD::SUB:
      Opc = CPU6ISD::BN_SUB;
      break;
    case ISD::MUL:
      Opc = CPU6ISD::BN_MUL;
      break;
    default:
      Opc = CPU6ISD::BN_DIV;
      break;
    }
    Loads = {L0, L1};
  } else {
    return SDValue();
  }

  if (!loadsShareMemoryState(Loads) ||
      !onlyLoadsJoinChain(St->getChain(), Loads[0]->getChain()) ||
      classifyOverlap(Src, St, DAG) == Overlap::Partial)
    return SDValue();

  SDLoc DL(St);
  return DAG.getNode(Opc, DL, MVT::Other, St->getChain(), Src->getBasePtr(),
                     St->getBasePtr(),
                     DAG.getTargetConstant(*Len, DL, MVT::i8));
}

// store (srem (load Num), (load Den)), Dest. DRM puts the quotient in its
// destination operand and writes the remainder, after it, through the address
// in A. So A holds Dest, and the quotient goes to a stack temporary after the
// dividend is copied there.
//
// The remainder must not land on the quotient. On the machine, -22 % 7 with
// the remainder written over the quotient's bytes gave +1, not -1 (and
// 22 % -7 gave -1): the quotient's sign fix also hits the remainder. So the
// quotient is never at Dest. The remainder over the divisor gave the right
// answer for every sign combination run, at 4 and 8 bytes, so Dest may be Den.
SDValue CPU6TargetLowering::combineBignumRem(StoreSDNode *St,
                                             SelectionDAG &DAG) const {
  EVT VT = St->getMemoryVT();
  SDValue Val = St->getValue();
  LoadSDNode *Num = getBignumLoad(Val.getOperand(0), VT);
  LoadSDNode *Den = getBignumLoad(Val.getOperand(1), VT);
  if (!Num || !Den || !loadsShareMemoryState({Num, Den}) ||
      !onlyLoadsJoinChain(St->getChain(), Num->getChain()))
    return SDValue();
  if (classifyOverlap(Den, St, DAG) == Overlap::Partial)
    return SDValue();

  SDLoc DL(St);
  SDValue Len = DAG.getTargetConstant(*bignumLenMinus1(VT), DL, MVT::i8);
  SDValue Chain = St->getChain();
  SDValue Quot = DAG.CreateStackTemporary(VT);
  Chain = DAG.getNode(CPU6ISD::BN_MOV, DL, MVT::Other, Chain,
                      Num->getBasePtr(), Quot, Len);
  // The empty glue operand is what gives the copy a glue result.
  SDValue ToA =
      DAG.getCopyToReg(Chain, DL, CPU6::rA, St->getBasePtr(), SDValue());
  return DAG.getNode(CPU6ISD::BN_DRM, DL, MVT::Other, ToA, Den->getBasePtr(),
                     Quot, Len, ToA.getValue(1));
}

// setcc (load A), (load B) -> BNC, then a branch on the flags it sets.
// BNC src,dest sets the flags of Dest - Src, and Link set means no borrow. So
// Dest is the left operand of >= and <, and the right operand of > and <=,
// which are the same tests with the operands swapped. == and != read V.
SDValue CPU6TargetLowering::combineBignumSetCC(SDNode *N,
                                               SelectionDAG &DAG) const {
  EVT VT = N->getOperand(0).getValueType();
  auto Len = bignumLenMinus1(VT);
  if (!Len)
    return SDValue();
  LoadSDNode *LHS = getBignumLoad(N->getOperand(0), VT);
  LoadSDNode *RHS = getBignumLoad(N->getOperand(1), VT);
  if (!LHS || !RHS || !loadsShareMemoryState({LHS, RHS}))
    return SDValue();

  LoadSDNode *Dest = LHS, *Src = RHS;
  unsigned Br;
  switch (cast<CondCodeSDNode>(N->getOperand(2))->get()) {
  case ISD::SETEQ:
    Br = CPU6::BZ;
    break;
  case ISD::SETNE:
    Br = CPU6::BNZ;
    break;
  case ISD::SETUGE:
    Br = CPU6::BL;
    break;
  case ISD::SETULT:
    Br = CPU6::BNL;
    break;
  case ISD::SETULE:
    std::swap(Dest, Src);
    Br = CPU6::BL;
    break;
  case ISD::SETUGT:
    std::swap(Dest, Src);
    Br = CPU6::BNL;
    break;
  default:
    return SDValue();
  }

  SDLoc DL(N);
  SDValue Cmp = DAG.getNode(
      CPU6ISD::BN_CMP, DL, DAG.getVTList(MVT::Other, MVT::Glue),
      LHS->getChain(), Src->getBasePtr(), Dest->getBasePtr(),
      DAG.getTargetConstant(*Len, DL, MVT::i8));
  // Writes after the loads must not move above the compare, so they chain
  // after it now that it stands in for the loads.
  DAG.ReplaceAllUsesOfValueWith(SDValue(LHS, 1), Cmp.getValue(0));
  if (RHS != LHS)
    DAG.ReplaceAllUsesOfValueWith(SDValue(RHS, 1), Cmp.getValue(0));

  SDValue Sel = DAG.getNode(CPU6ISD::SELECT_CC, DL, MVT::i16,
                            DAG.getConstant(1, DL, MVT::i16),
                            DAG.getConstant(0, DL, MVT::i16),
                            DAG.getTargetConstant(Br, DL, MVT::i16),
                            Cmp.getValue(1));
  EVT ResVT = N->getValueType(0);
  return ResVT == MVT::i16 ? Sel : DAG.getNode(ISD::TRUNCATE, DL, ResVT, Sel);
}

// add x, (select_cc 1, 0, B) -> x + 1 unless the opposite branch is taken
// sub x, (select_cc 1, 0, B) -> x - 1 unless the opposite branch is taken
// This is the shape the carry or borrow of a multi-word add or subtract takes
// (setcc ult, then zext, then add). Made as a select, the 0 and 1 are two
// registers that stay live across the compare, and the DAG shares them between
// every carry in a block, so they last the whole function. Here the compare is
// followed by one branch around one INR or DCR (see EmitStepCC), with no
// constants. The select (0, 1) steps when B is not taken.
SDValue CPU6TargetLowering::combineCarryStep(SDNode *N,
                                             SelectionDAG &DAG) const {
  if (N->getValueType(0) != MVT::i16)
    return SDValue();
  bool IsSub = N->getOpcode() == ISD::SUB;
  auto IsOneZeroSelect = [](SDValue V) {
    return V.getOpcode() == CPU6ISD::SELECT_CC && V.hasOneUse() &&
           isa<ConstantSDNode>(V.getOperand(0)) &&
           isa<ConstantSDNode>(V.getOperand(1));
  };
  SDValue Sel = N->getOperand(1);
  SDValue X = N->getOperand(0);
  if (!IsOneZeroSelect(Sel)) {
    // Only an add takes its operands either way round.
    if (IsSub || !IsOneZeroSelect(X))
      return SDValue();
    std::swap(Sel, X);
  }
  uint64_t T = Sel.getConstantOperandVal(0);
  uint64_t F = Sel.getConstantOperandVal(1);
  if (!((T == 1 && F == 0) || (T == 0 && F == 1)))
    return SDValue();
  // X is computed before the compare, which the step is glued to.
  if (Sel.getNode()->isPredecessorOf(X.getNode()))
    return SDValue();

  unsigned Branch = Sel.getConstantOperandVal(2);
  unsigned Skip = T == 1 ? CPU6InstrInfo::getOppositeBranch(Branch) : Branch;
  if (!Skip)
    return SDValue();
  SDLoc DL(N);
  return DAG.getNode(CPU6ISD::STEP_CC, DL, MVT::i16, X,
                     DAG.getSignedTargetConstant(IsSub ? -1 : 1, DL, MVT::i16),
                     DAG.getTargetConstant(Skip, DL, MVT::i16),
                     Sel.getOperand(3));
}

SDValue CPU6TargetLowering::PerformDAGCombine(SDNode *N,
                                              DAGCombinerInfo &DCI) const {
  SelectionDAG &DAG = DCI.DAG;
  switch (N->getOpcode()) {
  case ISD::STORE:
    return combineBignumStore(cast<StoreSDNode>(N), DAG);
  case ISD::SETCC:
    return combineBignumSetCC(N, DAG);
  case ISD::ADD:
  case ISD::SUB:
    return combineCarryStep(N, DAG);
  default:
    break;
  }
  return SDValue();
}

SDValue CPU6TargetLowering::LowerFormalArguments(
    SDValue Chain, CallingConv::ID CallConv, bool IsVarArg,
    const SmallVectorImpl<ISD::InputArg> &Ins, const SDLoc &DL,
    SelectionDAG &DAG, SmallVectorImpl<SDValue> &InVals) const {
  // A function with no arguments still has to hand the entry chain back.
  // `ret void` and `ret i16 42` both land here with Ins empty.
  if (IsVarArg)
    report_fatal_error("CPU6 varargs are not supported");
  if (Ins.empty())
    return Chain;

  // assign each incoming value and push one SDValue per argument
  // into InVals, in order.
  MachineFunction &MF = DAG.getMachineFunction();
  MachineFrameInfo &MFI = MF.getFrameInfo();
  SmallVector<CCValAssign, 8> ArgLocs;
  CCState CCInfo(CallConv, IsVarArg, MF, ArgLocs, *DAG.getContext());
  CCInfo.AnalyzeFormalArguments(Ins, CC_CPU6);

  SmallVector<SDValue, 4> LoadChains;
  for (unsigned I = 0, E = ArgLocs.size(); I != E; ++I) {
    CCValAssign &VA = ArgLocs[I];
    SDValue Arg;
    if (VA.isRegLoc()) {
      // addLiveIn records the register as live into the entry block. Without
      // it the register looks undefined, and the prologue's STK would treat an
      // argument in Y or Z as dead.
      Register VReg = MF.addLiveIn(VA.getLocReg(), &CPU6::GPRRegClass);
      Arg = DAG.getCopyFromReg(Chain, DL, VReg, VA.getLocVT());
    } else {
      assert(VA.isMemLoc() && "argument is neither a register nor a stack slot");
      if (Ins[I].Flags.isByVal())
        report_fatal_error("CPU6 byval arguments are not supported");
      // webCenREE f_jsr does stackw(X) before setting X to the return PC, so
      // incoming S points at that saved word. The caller's stack offset is
      // two bytes above it.
      int FI = MFI.CreateFixedObject(VA.getLocVT().getStoreSize(),
                                    VA.getLocMemOffset() + 2, /*IsImmutable=*/true);
      SDValue FIN = DAG.getFrameIndex(FI, MVT::i16);
      SDValue Load = DAG.getLoad(
          VA.getLocVT(), DL, Chain, FIN,
          MachinePointerInfo::getFixedStack(MF, FI));
      Arg = Load;
      LoadChains.push_back(Load.getValue(1));
    }
    // A promoted byte arrives as a word. Record what the caller promised
    // about the upper half, then take the low byte.
    InVals.push_back(narrowFromLoc(DAG, DL, Arg, VA));
  }
  if (!LoadChains.empty()) {
    LoadChains.push_back(Chain);
    Chain = DAG.getNode(ISD::TokenFactor, DL, MVT::Other, LoadChains);
  }
  return Chain;
}

SDValue CPU6TargetLowering::LowerReturn(
    SDValue Chain, CallingConv::ID CallConv, bool IsVarArg,
    const SmallVectorImpl<ISD::OutputArg> &Outs,
    const SmallVectorImpl<SDValue> &OutVals, const SDLoc &DL,
    SelectionDAG &DAG) const {
  // `ret void` has an empty Outs. CPU6InstrPatterns.td matches this node to RSR.
  if (Outs.empty())
    return DAG.getNode(CPU6ISD::RET_GLUE, DL, MVT::Other, Chain);

  // a returned value has to be copied into the register RetCC_CPU6
  // assigns before the RET_GLUE node. Glue keeps the copy attached to the
  // return so nothing can sink between them. Uncomment for load-imm.ll.

    SmallVector<CCValAssign, 4> RVLocs;
    CCState CCInfo(CallConv, IsVarArg, DAG.getMachineFunction(), RVLocs,
                   *DAG.getContext());
    CCInfo.AnalyzeReturn(Outs, RetCC_CPU6);
  
    SDValue Glue;
    SmallVector<SDValue, 4> RetOps(1, Chain);
    for (unsigned I = 0, E = RVLocs.size(); I != E; ++I) {
      CCValAssign &VA = RVLocs[I];
      assert(VA.isRegLoc() && "return value needs a register in RetCC_CPU6");
      SDValue Val = OutVals[I];
      switch (VA.getLocInfo()) {
      case CCValAssign::Full:
        break;
      case CCValAssign::SExt:
        Val = DAG.getNode(ISD::SIGN_EXTEND, DL, VA.getLocVT(), Val);
        break;
      case CCValAssign::ZExt:
        Val = DAG.getNode(ISD::ZERO_EXTEND, DL, VA.getLocVT(), Val);
        break;
      case CCValAssign::AExt:
        Val = DAG.getNode(ISD::ANY_EXTEND, DL, VA.getLocVT(), Val);
        break;
      default:
        llvm_unreachable("unexpected return value promotion");
      }
      Chain = DAG.getCopyToReg(Chain, DL, VA.getLocReg(), Val, Glue);
      Glue = Chain.getValue(1);
      RetOps.push_back(DAG.getRegister(VA.getLocReg(), VA.getLocVT()));
    }
    RetOps[0] = Chain;
    if (Glue.getNode())
      RetOps.push_back(Glue);
    return DAG.getNode(CPU6ISD::RET_GLUE, DL, MVT::Other, RetOps);
}

SDValue CPU6TargetLowering::LowerCallResult(
    SDValue Chain, SDValue InGlue, CallingConv::ID CallConv, bool IsVarArg,
    const SmallVectorImpl<ISD::InputArg> &Ins, const SDLoc &DL,
    SelectionDAG &DAG, SmallVectorImpl<SDValue> &InVals) const {
  SmallVector<CCValAssign, 4> RVLocs;
  CCState CCInfo(CallConv, IsVarArg, DAG.getMachineFunction(), RVLocs,
                 *DAG.getContext());
  CCInfo.AnalyzeCallResult(Ins, RetCC_CPU6);

  for (unsigned I = 0, E = RVLocs.size(); I != E; ++I) {
    CCValAssign &VA = RVLocs[I];
    assert(VA.isRegLoc() && "return value needs a register in RetCC_CPU6");
    SDValue Ret = DAG.getCopyFromReg(Chain, DL, VA.getLocReg(), VA.getLocVT(),
                                     InGlue);
    Chain = Ret.getValue(1);
    InGlue = Ret.getValue(2);
    InVals.push_back(narrowFromLoc(DAG, DL, Ret, VA));
  }
  return Chain;
}

// A direct call whose arguments fit in A, B, Y, and Z. JMP leaves X holding
// the return address JSR put there on entry, so the callee's RSR returns to
// our caller. Y and Z are callee-saved, and the epilogue POP is inserted in
// front of the jump, so an argument in either register has to be the value
// that POP reloads: the incoming one. A stack argument would have to be
// written at incoming S, on top of this function's own stack arguments.
static bool isEligibleForTailCall(const CPU6TargetLowering &TLI,
                                  const TargetLowering::CallLoweringInfo &CLI,
                                  CCState &CCInfo,
                                  const SmallVectorImpl<CCValAssign> &ArgLocs) {
  if (!CLI.IsTailCall)
    return false;
  if (auto *G = dyn_cast<GlobalAddressSDNode>(CLI.Callee)) {
    if (G->getOffset() != 0)
      return false;
    if (const auto *Callee = dyn_cast<Function>(G->getGlobal())) {
      if (Callee->getCallingConv() != CLI.CallConv)
        return false;
    }
  } else if (!isa<ExternalSymbolSDNode>(CLI.Callee)) {
    return false;
  }
  if (CCInfo.getStackSize() != 0)
    return false;
  for (const CCValAssign &VA : ArgLocs)
    if (!VA.isRegLoc())
      return false;
  const MachineFunction &MF = CLI.DAG.getMachineFunction();
  const uint32_t *Mask = MF.getSubtarget().getRegisterInfo()->getCallPreservedMask(
      MF, CLI.CallConv);
  return TLI.parametersInCSRMatch(MF.getRegInfo(), Mask, ArgLocs, CLI.OutVals);
}

SDValue
CPU6TargetLowering::LowerCall(CallLoweringInfo &CLI,
                              SmallVectorImpl<SDValue> &InVals) const {
  SelectionDAG &DAG = CLI.DAG;
  SDLoc DL = CLI.DL;
  SmallVector<CCValAssign, 16> ArgLocs;
  CCState CCInfo(CLI.CallConv, CLI.IsVarArg, DAG.getMachineFunction(), ArgLocs,
                 *DAG.getContext());
  if (CLI.IsVarArg)
    report_fatal_error("CPU6 varargs are not supported");
  CCInfo.AnalyzeCallOperands(CLI.Outs, CC_CPU6);

  bool Tail = isEligibleForTailCall(*this, CLI, CCInfo, ArgLocs);
  if (CLI.CB && CLI.CB->isMustTailCall() && !Tail)
    report_fatal_error("CPU6 cannot guarantee this tail call");
  CLI.IsTailCall = Tail;

  // Bytes the caller writes above S. JSR's push of X is not part of this:
  // RSR pops it, and the callee finds the first word at incoming S + 2.
  // A tail call has no stack arguments and does not return, so it has no
  // call frame.
  unsigned NumBytes = CCInfo.getStackSize();
  SDValue Chain = CLI.Chain;
  if (!Tail)
    Chain = DAG.getCALLSEQ_START(Chain, NumBytes, 0, DL);

  SmallVector<std::pair<unsigned, SDValue>, 4> RegsToPass;
  SmallVector<SDValue, 8> MemOpChains;
  for (unsigned I = 0, E = ArgLocs.size(); I != E; ++I) {
    CCValAssign &VA = ArgLocs[I];
    SDValue Arg = extendToLoc(DAG, DL, CLI.OutVals[I], VA);
    if (VA.isRegLoc()) {
      RegsToPass.emplace_back(VA.getLocReg(), Arg);
      continue;
    }
    assert(VA.isMemLoc() && "argument is neither a register nor a stack slot");
    if (CLI.Outs[I].Flags.isByVal())
      report_fatal_error("CPU6 byval arguments are not supported");
    if (!isInt<16>(VA.getLocMemOffset()))
      report_fatal_error("CPU6 stack argument offset does not fit");
    // STR src,(S),disp. The displacement is the caller's offset, so the word
    // lands where the callee's incoming S + offset + 2 load reads it.
    // The chain is the last operand: EmitMachineNode looks for it there.
    SDValue Ops[] = {Arg, DAG.getRegister(CPU6::rS, MVT::i16),
                     DAG.getTargetConstant(VA.getLocMemOffset(), DL, MVT::i16),
                     Chain};
    MachineSDNode *Store =
        DAG.getMachineNode(CPU6::STRidx, DL, MVT::Other, Ops);
    MachineFunction &MF = DAG.getMachineFunction();
    MachineMemOperand *MMO = MF.getMachineMemOperand(
        MachinePointerInfo::getStack(MF, VA.getLocMemOffset()),
        MachineMemOperand::MOStore, VA.getLocVT().getStoreSize(), Align(1));
    DAG.setNodeMemRefs(Store, {MMO});
    MemOpChains.push_back(SDValue(Store, 0));
  }
  if (!MemOpChains.empty())
    Chain = DAG.getNode(ISD::TokenFactor, DL, MVT::Other, MemOpChains);

  SDValue Glue;
  for (const auto &[Reg, Val] : RegsToPass) {
    Chain = DAG.getCopyToReg(Chain, DL, Reg, Val, Glue);
    Glue = Chain.getValue(1);
  }

  SDValue Callee = CLI.Callee;
  if (GlobalAddressSDNode *G = dyn_cast<GlobalAddressSDNode>(Callee))
    Callee = DAG.getTargetGlobalAddress(G->getGlobal(), DL, MVT::i16,
                                        G->getOffset());
  else if (ExternalSymbolSDNode *E = dyn_cast<ExternalSymbolSDNode>(Callee))
    Callee = DAG.getTargetExternalSymbol(E->getSymbol(), MVT::i16);

  SmallVector<SDValue, 8> Ops;
  Ops.push_back(Chain);
  Ops.push_back(Callee);
  for (const auto &[Reg, Val] : RegsToPass)
    Ops.push_back(DAG.getRegister(Reg, Val.getValueType()));
  if (Tail) {
    // No register mask. The jump does not return, and the epilogue has
    // already handed Y and Z back. The physreg operands keep the arguments
    // live into the jump.
    if (Glue)
      Ops.push_back(Glue);
    return DAG.getNode(CPU6ISD::TC_RETURN, DL, MVT::Other, Ops);
  }
  const TargetRegisterInfo *TRI = DAG.getSubtarget().getRegisterInfo();
  Ops.push_back(DAG.getRegisterMask(
      TRI->getCallPreservedMask(DAG.getMachineFunction(), CLI.CallConv)));
  if (Glue)
    Ops.push_back(Glue);

  SDVTList NodeTys = DAG.getVTList(MVT::Other, MVT::Glue);
  Chain = DAG.getNode(CPU6ISD::CALL, DL, NodeTys, Ops);
  Glue = Chain.getValue(1);
  Chain = DAG.getCALLSEQ_END(Chain, NumBytes, 0, Glue, DL);
  Glue = Chain.getValue(1);
  return LowerCallResult(Chain, Glue, CLI.CallConv, CLI.IsVarArg, CLI.Ins, DL,
                         DAG, InVals);
}

// Emits the compare for LHS CC RHS and returns its glue. Opc is the branch
// taken exactly when the condition holds, so every condition is one branch.
// After SUB a,b (flags_a16vmfl(a, b, 1)) Value is a == b and Link is
// a >= b unsigned: no borrow. Minus is the sign of a - b, which is a < b only
// without overflow, so BM, BP, BGZ, and BLE only test a value against zero.
// Any other signed compare flips both sign bits and compares unsigned.
static SDValue emitCmp(SDValue LHS, SDValue RHS, ISD::CondCode CC,
                       unsigned &Opc, const SDLoc &DL, SelectionDAG &DAG) {
  EVT VT = LHS.getValueType();
  if (auto *C = dyn_cast<ConstantSDNode>(RHS)) {
    if ((CC == ISD::SETLT && C->isOne()) ||
        (CC == ISD::SETGT && C->isAllOnes())) {
      CC = CC == ISD::SETLT ? ISD::SETLE : ISD::SETGE;
      RHS = DAG.getConstant(0, DL, VT);
    }
  }
  if (isNullConstant(RHS)) {
    switch (CC) {
    case ISD::SETEQ:
    case ISD::SETULE:
      Opc = CPU6::BZ;
      break;
    case ISD::SETNE:
    case ISD::SETUGT:
      Opc = CPU6::BNZ;
      break;
    case ISD::SETLT:
      Opc = CPU6::BM;
      break;
    case ISD::SETGE:
      Opc = CPU6::BP;
      break;
    case ISD::SETGT:
      Opc = CPU6::BGZ;
      break;
    case ISD::SETLE:
      Opc = CPU6::BLE;
      break;
    default:
      Opc = 0;
      break;
    }
    if (Opc)
      return DAG.getNode(CPU6ISD::TST, DL, MVT::Glue, LHS);
  }
  if (ISD::isSignedIntSetCC(CC)) {
    SDValue Bias =
        DAG.getConstant(APInt::getSignMask(VT.getSizeInBits()), DL, VT);
    LHS = DAG.getNode(ISD::XOR, DL, VT, LHS, Bias);
    RHS = DAG.getNode(ISD::XOR, DL, VT, RHS, Bias);
    CC = CC == ISD::SETLT   ? ISD::SETULT
         : CC == ISD::SETLE ? ISD::SETULE
         : CC == ISD::SETGT ? ISD::SETUGT
                            : ISD::SETUGE;
  }
  // Link answers a >= b and a < b; a <= b and a > b swap the operands. A word
  // constant goes first, into the SUB literal form (imm - r). A byte constant
  // stays second, in the register CMPB overwrites. Moving the constant by one
  // gives a condition that keeps it there.
  if (auto *C = dyn_cast<ConstantSDNode>(RHS)) {
    const APInt &V = C->getAPIntValue();
    if (VT == MVT::i16) {
      if ((CC == ISD::SETUGE || CC == ISD::SETULT) && !V.isZero()) {
        CC = CC == ISD::SETUGE ? ISD::SETUGT : ISD::SETULE;
        RHS = DAG.getConstant(V - 1, DL, VT);
      }
      if (CC != ISD::SETUGE && CC != ISD::SETULT) {
        std::swap(LHS, RHS);
        CC = ISD::getSetCCSwappedOperands(CC);
      }
    } else if ((CC == ISD::SETULE || CC == ISD::SETUGT) && !V.isMaxValue()) {
      CC = CC == ISD::SETULE ? ISD::SETULT : ISD::SETUGE;
      RHS = DAG.getConstant(V + 1, DL, VT);
    }
  }
  if (CC == ISD::SETULE || CC == ISD::SETUGT) {
    std::swap(LHS, RHS);
    CC = ISD::getSetCCSwappedOperands(CC);
  }
  switch (CC) {
  case ISD::SETEQ:
    Opc = CPU6::BZ;
    break;
  case ISD::SETNE:
    Opc = CPU6::BNZ;
    break;
  case ISD::SETUGE:
    Opc = CPU6::BL;
    break;
  case ISD::SETULT:
    Opc = CPU6::BNL;
    break;
  default:
    llvm_unreachable("not an integer condition");
  }
  return DAG.getNode(CPU6ISD::CMP, DL, DAG.getVTList(VT, MVT::Glue), LHS, RHS)
      .getValue(1);
}

// SRR sign-fills, and there is no logical right shift of more than one bit
// in a single instruction. A constant in range is left for the SRR-plus-mask
// pattern. Rewriting it here to an arithmetic shift and an AND makes the
// combiner rebuild the logical shift, and legalization never finishes. Zero
// and an amount past the width never match the 1..width-1 patterns. A
// variable count is returned unchanged so the one-bit loop can match it.
SDValue CPU6TargetLowering::LowerShift(SDValue Op, SelectionDAG &DAG) const {
  SDValue Amt = Op.getOperand(1);
  auto *C = dyn_cast<ConstantSDNode>(Amt);
  if (!C)
    return Op;
  EVT VT = Op.getValueType();
  unsigned Bits = VT.getSizeInBits();
  uint64_t N = C->getZExtValue();
  if (N == 0)
    return Op.getOperand(0);
  if (N >= Bits) {
    // The IR leaves this undefined. Shifting all the bits out is the result
    // a longer arithmetic or logical shift produces, and a left shift of the
    // whole width is zero.
    SDLoc DL(Op);
    if (Op.getOpcode() == ISD::SRA)
      return DAG.getNode(ISD::SRA, DL, VT, Op.getOperand(0),
                         DAG.getConstant(Bits - 1, DL, Amt.getValueType()));
    return DAG.getConstant(0, DL, VT);
  }
  return Op;
}

// 0 is a left shift, 1 a logical right shift, 2 an arithmetic right shift.
// EmitWideShift reads the same immediate off the pseudo.
enum { WShiftLeft = 0, WShiftLRight = 1, WShiftARight = 2 };

static unsigned wideShiftKind(unsigned Opc) {
  if (Opc == ISD::SHL || Opc == ISD::SHL_PARTS)
    return WShiftLeft;
  if (Opc == ISD::SRL || Opc == ISD::SRL_PARTS)
    return WShiftLRight;
  return WShiftARight;
}

// Low word first. An i32 is two i16s and an i64 is four. SplitScalar is an
// extract, so this does not build another shift of the wide value.
static void collectShiftWords(SDValue V, SmallVectorImpl<SDValue> &Words,
                              SelectionDAG &DAG, const SDLoc &DL) {
  if (V.getValueType() == MVT::i16) {
    Words.push_back(V);
    return;
  }
  EVT LoVT, HiVT;
  std::tie(LoVT, HiVT) = DAG.GetSplitDestVTs(V.getValueType());
  SDValue Lo, Hi;
  std::tie(Lo, Hi) = DAG.SplitScalar(V, DL, LoVT, HiVT);
  collectShiftWords(Lo, Words, DAG, DL);
  collectShiftWords(Hi, Words, DAG, DL);
}

// Pair the words back into the original width. BUILD_PAIR's first operand is
// the low half, which is also the order collectShiftWords produced.
static SDValue buildShiftResult(ArrayRef<SDValue> In, SelectionDAG &DAG,
                                const SDLoc &DL) {
  SmallVector<SDValue, 4> Cur(In.begin(), In.end());
  while (Cur.size() > 1) {
    SmallVector<SDValue, 4> Up;
    for (unsigned I = 0; I < Cur.size(); I += 2) {
      unsigned Bits =
          Cur[I].getValueSizeInBits() + Cur[I + 1].getValueSizeInBits();
      EVT VT = EVT::getIntegerVT(*DAG.getContext(), Bits);
      Up.push_back(DAG.getNode(ISD::BUILD_PAIR, DL, VT, Cur[I], Cur[I + 1]));
    }
    Cur = std::move(Up);
  }
  return Cur[0];
}

static SDValue makeWideShift(ArrayRef<SDValue> Words, SDValue Amt,
                             unsigned Kind, const SDLoc &DL,
                             SelectionDAG &DAG) {
  if (Amt.getValueType() != MVT::i16)
    Amt = DAG.getZExtOrTrunc(Amt, DL, MVT::i16);
  SmallVector<EVT, 4> VTs(Words.size(), MVT::i16);
  SmallVector<SDValue, 8> Ops(Words.begin(), Words.end());
  Ops.push_back(Amt);
  Ops.push_back(DAG.getTargetConstant(Kind, DL, MVT::i16));
  return DAG.getNode(CPU6ISD::WSHIFT, DL, DAG.getVTList(VTs), Ops);
}

// The type legalizer asks before it splits a variable i32 or i64 shift into
// parts. A constant is left for ExpandShiftByConstant, which is a word move
// plus an immediate SLR or SRR. Anything else is one WSHIFT of every word.
void CPU6TargetLowering::ReplaceNodeResults(
    SDNode *N, SmallVectorImpl<SDValue> &Results, SelectionDAG &DAG) const {
  unsigned Opc = N->getOpcode();
  if (Opc != ISD::SHL && Opc != ISD::SRL && Opc != ISD::SRA)
    return;
  EVT VT = N->getValueType(0);
  if (VT != MVT::i32 && VT != MVT::i64)
    return;
  if (isa<ConstantSDNode>(N->getOperand(1)))
    return;

  SDLoc DL(N);
  SmallVector<SDValue, 4> Words;
  collectShiftWords(N->getOperand(0), Words, DAG, DL);
  SDValue Parts =
      makeWideShift(Words, N->getOperand(1), wideShiftKind(Opc), DL, DAG);
  SmallVector<SDValue, 4> Out;
  for (unsigned I = 0, E = Words.size(); I != E; ++I)
    Out.push_back(Parts.getValue(I));
  Results.push_back(buildShiftResult(Out, DAG, DL));
}

// Already split into two i16 halves. The same node as ReplaceNodeResults.
SDValue CPU6TargetLowering::LowerShiftParts(SDValue Op,
                                            SelectionDAG &DAG) const {
  SDLoc DL(Op);
  SDValue Parts = makeWideShift({Op.getOperand(0), Op.getOperand(1)},
                                Op.getOperand(2), wideShiftKind(Op.getOpcode()),
                                DL, DAG);
  return DAG.getMergeValues({Parts, Parts.getValue(1)}, DL);
}

// C division truncates toward zero, and the remainder takes the dividend's
// sign. DIV is unsigned. Magnitudes use an unsigned negate so that INT16_MIN
// (0x8000) becomes 32768, which still fits in the word; a signed negate of
// that value does not. The quotient is negated when the signs differ. The
// remainder magnitude is |n| - quot * |d|, negated when the dividend is
// negative.
SDValue CPU6TargetLowering::LowerDivRem(SDValue Op, SelectionDAG &DAG) const {
  SDLoc DL(Op);
  EVT VT = Op.getValueType();
  SDValue N = Op.getOperand(0);
  SDValue D = Op.getOperand(1);
  SDValue Zero = DAG.getConstant(0, DL, VT);
  auto Magnitude = [&](SDValue V) {
    SDValue Neg = DAG.getNode(ISD::SUB, DL, VT, Zero, V);
    return DAG.getSelectCC(DL, V, Zero, Neg, V, ISD::SETLT);
  };
  SDValue UN = Magnitude(N);
  SDValue UD = Magnitude(D);
  SDValue UQ = DAG.getNode(ISD::UDIV, DL, VT, UN, UD);
  if (Op.getOpcode() == ISD::SDIV) {
    SDValue NNeg = DAG.getSetCC(DL, VT, N, Zero, ISD::SETLT);
    SDValue DNeg = DAG.getSetCC(DL, VT, D, Zero, ISD::SETLT);
    SDValue NQ = DAG.getNode(ISD::SUB, DL, VT, Zero, UQ);
    return DAG.getSelectCC(DL, NNeg, DNeg, NQ, UQ, ISD::SETNE);
  }
  SDValue UR =
      DAG.getNode(ISD::SUB, DL, VT, UN, DAG.getNode(ISD::MUL, DL, VT, UQ, UD));
  SDValue NR = DAG.getNode(ISD::SUB, DL, VT, Zero, UR);
  return DAG.getSelectCC(DL, N, Zero, NR, UR, ISD::SETLT);
}

// Unsigned 16x16->32, then the signed correction on the high half only:
// hi -= b when a < 0, and hi -= a when b < 0. The low half is the same
// for a signed and an unsigned product.
SDValue CPU6TargetLowering::LowerSmulLoHi(SDValue Op,
                                          SelectionDAG &DAG) const {
  SDLoc DL(Op);
  SDValue A = Op.getOperand(0);
  SDValue B = Op.getOperand(1);
  EVT VT = A.getValueType();
  SDValue Prod = DAG.getNode(ISD::UMUL_LOHI, DL, DAG.getVTList(VT, VT), A, B);
  SDValue Lo = Prod;
  SDValue Hi = Prod.getValue(1);
  SDValue Zero = DAG.getConstant(0, DL, VT);
  SDValue HiMinusB = DAG.getNode(ISD::SUB, DL, VT, Hi, B);
  Hi = DAG.getSelectCC(DL, A, Zero, HiMinusB, Hi, ISD::SETLT);
  SDValue HiMinusA = DAG.getNode(ISD::SUB, DL, VT, Hi, A);
  Hi = DAG.getSelectCC(DL, B, Zero, HiMinusA, Hi, ISD::SETLT);
  return DAG.getMergeValues({Lo, Hi}, DL);
}

SDValue CPU6TargetLowering::LowerOperation(SDValue Op,
                                           SelectionDAG &DAG) const {
  SDLoc DL(Op);
  unsigned Opc;
  switch (Op.getOpcode()) {
  case ISD::SHL:
  case ISD::SRA:
  case ISD::SRL:
    return LowerShift(Op, DAG);
  case ISD::SHL_PARTS:
  case ISD::SRL_PARTS:
  case ISD::SRA_PARTS:
    return LowerShiftParts(Op, DAG);
  case ISD::SDIV:
  case ISD::SREM:
    return LowerDivRem(Op, DAG);
  case ISD::SMUL_LOHI:
    return LowerSmulLoHi(Op, DAG);
  case ISD::BR_CC: {
    SDValue Glue =
        emitCmp(Op.getOperand(2), Op.getOperand(3),
                cast<CondCodeSDNode>(Op.getOperand(1))->get(), Opc, DL, DAG);
    return DAG.getNode(CPU6ISD::BR_CC, DL, MVT::Other, Op.getOperand(0),
                       Op.getOperand(4), DAG.getTargetConstant(Opc, DL, MVT::i16),
                       Glue);
  }
  case ISD::SELECT_CC: {
    SDValue Glue =
        emitCmp(Op.getOperand(0), Op.getOperand(1),
                cast<CondCodeSDNode>(Op.getOperand(4))->get(), Opc, DL, DAG);
    return DAG.getNode(CPU6ISD::SELECT_CC, DL, Op.getValueType(),
                       Op.getOperand(2), Op.getOperand(3),
                       DAG.getTargetConstant(Opc, DL, MVT::i16), Glue);
  }
  }
  llvm_unreachable("unexpected custom lowering");
}

// SELECT and SELECTB. The compare glued to the pseudo is right before it, so
// once the rest of the block moves to Join it ends the block, followed by
// the branch to Join. False is empty and falls through to Join.
MachineBasicBlock *
CPU6TargetLowering::EmitSelect(MachineInstr &MI, MachineBasicBlock *BB) const {
  MachineFunction *MF = BB->getParent();
  const TargetInstrInfo &TII = *MF->getSubtarget().getInstrInfo();
  const DebugLoc &DL = MI.getDebugLoc();
  MachineFunction::iterator It = std::next(BB->getIterator());
  MachineBasicBlock *False = MF->CreateMachineBasicBlock(BB->getBasicBlock());
  MachineBasicBlock *Join = MF->CreateMachineBasicBlock(BB->getBasicBlock());
  MF->insert(It, False);
  MF->insert(It, Join);
  Join->splice(Join->begin(), BB, std::next(MI.getIterator()), BB->end());
  Join->transferSuccessorsAndUpdatePHIs(BB);
  BB->addSuccessor(False);
  BB->addSuccessor(Join);
  False->addSuccessor(Join);

  BuildMI(BB, DL, TII.get(MI.getOperand(3).getImm())).addMBB(Join);
  BuildMI(*Join, Join->begin(), DL, TII.get(TargetOpcode::PHI),
          MI.getOperand(0).getReg())
      .addReg(MI.getOperand(1).getReg())
      .addMBB(BB)
      .addReg(MI.getOperand(2).getReg())
      .addMBB(False);
  MI.eraseFromParent();
  return Join;
}

// STEPCC: dst = x + delta unless the branch is taken. The compare glued to the
// pseudo is right before it, so it ends BB, followed by the branch to Join.
// Step holds the ADDimm (an INR or DCR once x and dst share a register) and
// falls through to Join. Its flag writes are dead: the flags are only read by
// the branch.
MachineBasicBlock *
CPU6TargetLowering::EmitStepCC(MachineInstr &MI, MachineBasicBlock *BB) const {
  MachineFunction *MF = BB->getParent();
  const TargetInstrInfo &TII = *MF->getSubtarget().getInstrInfo();
  const DebugLoc &DL = MI.getDebugLoc();
  MachineFunction::iterator It = std::next(BB->getIterator());
  MachineBasicBlock *Step = MF->CreateMachineBasicBlock(BB->getBasicBlock());
  MachineBasicBlock *Join = MF->CreateMachineBasicBlock(BB->getBasicBlock());
  MF->insert(It, Step);
  MF->insert(It, Join);
  Join->splice(Join->begin(), BB, std::next(MI.getIterator()), BB->end());
  Join->transferSuccessorsAndUpdatePHIs(BB);
  BB->addSuccessor(Step);
  BB->addSuccessor(Join);
  Step->addSuccessor(Join);

  Register X = MI.getOperand(1).getReg();
  BuildMI(BB, DL, TII.get(MI.getOperand(3).getImm())).addMBB(Join);

  Register Stepped =
      MF->getRegInfo().createVirtualRegister(&CPU6::GPRRegClass);
  MachineInstrBuilder Add = BuildMI(*Step, Step->end(), DL,
                                    TII.get(CPU6::ADDimm), Stepped)
                                .addReg(X)
                                .addImm(MI.getOperand(2).getImm());
  for (MachineOperand &MO : Add->operands())
    if (MO.isReg() && MO.isImplicit() && MO.isDef())
      MO.setIsDead();

  BuildMI(*Join, Join->begin(), DL, TII.get(TargetOpcode::PHI),
          MI.getOperand(0).getReg())
      .addReg(X)
      .addMBB(BB)
      .addReg(Stepped)
      .addMBB(Step);
  MI.eraseFromParent();
  return Join;
}

MachineBasicBlock *
CPU6TargetLowering::EmitInstrWithCustomInserter(MachineInstr &MI,
                                                MachineBasicBlock *BB) const {
  switch (MI.getOpcode()) {
  case CPU6::SELECT:
  case CPU6::SELECTB:
    return EmitSelect(MI, BB);
  case CPU6::STEPCC:
    return EmitStepCC(MI, BB);
  case CPU6::MULHUb:
    return EmitMulhu(MI, BB);
  case CPU6::MULrr:
    return EmitMulLow(MI, BB);
  case CPU6::DIVrr:
    return EmitDiv(MI, BB);
  case CPU6::MULlohi:
    return EmitMulLoHi(MI, BB);
  case CPU6::MEMCPYLOOP:
  case CPU6::MEMMOVELOOP:
  case CPU6::MEMSETLOOP:
    return EmitMemLoop(MI, BB);
  case CPU6::WSHIFT2:
  case CPU6::WSHIFT4:
    return EmitWideShift(MI, BB);
  default:
    return EmitShift(MI, BB);
  }
}

// i8 mulhu. Both bytes are zero-extended, so the 16-bit product fits in the
// low half of the word MUL. SRR's count nibble is the distance minus one, so
// 7 shifts by 8 and the low byte is bits [15:8]. The sign bits SRR writes
// above that are discarded with the byte extract.
MachineBasicBlock *
CPU6TargetLowering::EmitMulhu(MachineInstr &MI, MachineBasicBlock *BB) const {
  MachineFunction *MF = BB->getParent();
  MachineRegisterInfo &MRI = MF->getRegInfo();
  const TargetInstrInfo &TII = *MF->getSubtarget().getInstrInfo();
  const DebugLoc &DL = MI.getDebugLoc();
  Register Dst = MI.getOperand(0).getReg();

  // SUBREG_TO_REG only asserts that the high byte is already zero. Clear it.
  auto ZExt = [&](Register Byte) {
    Register Undef = MRI.createVirtualRegister(&CPU6::GPRBRegClass);
    Register Word = MRI.createVirtualRegister(&CPU6::GPRRegClass);
    Register Cleared = MRI.createVirtualRegister(&CPU6::GPRRegClass);
    BuildMI(*BB, MI, DL, TII.get(TargetOpcode::IMPLICIT_DEF), Undef);
    BuildMI(*BB, MI, DL, TII.get(TargetOpcode::REG_SEQUENCE), Word)
        .addReg(Byte)
        .addImm(CPU6::sub_lo)
        .addReg(Undef)
        .addImm(CPU6::sub_hi);
    BuildMI(*BB, MI, DL, TII.get(CPU6::ANDimm), Cleared).addReg(Word).addImm(255);
    return Cleared;
  };

  Register L = ZExt(MI.getOperand(1).getReg());
  Register RWide = ZExt(MI.getOperand(2).getReg());
  Register R = MRI.createVirtualRegister(&CPU6::MulLoRegClass);
  BuildMI(*BB, MI, DL, TII.get(TargetOpcode::COPY), R).addReg(RWide);

  Register Prod = MRI.createVirtualRegister(&CPU6::MulLoRegClass);
  BuildMI(*BB, MI, DL, TII.get(CPU6::MULlo), Prod).addReg(L).addReg(R);

  Register Wide = MRI.createVirtualRegister(&CPU6::GPRRegClass);
  BuildMI(*BB, MI, DL, TII.get(TargetOpcode::COPY), Wide).addReg(Prod);
  Register Shifted = MRI.createVirtualRegister(&CPU6::GPRRegClass);
  BuildMI(*BB, MI, DL, TII.get(CPU6::SRR), Shifted).addReg(Wide).addImm(7);
  BuildMI(*BB, MI, DL, TII.get(TargetOpcode::COPY), Dst)
      .addReg(Shifted, RegState::NoFlags, CPU6::sub_lo);

  MI.eraseFromParent();
  return BB;
}

// i16 udiv. The dividend is copied into B. DIVB divides B by the divisor
// and writes the quotient back to B. A pair destination would leave the
// remainder there instead. A is not written.
MachineBasicBlock *
CPU6TargetLowering::EmitDiv(MachineInstr &MI, MachineBasicBlock *BB) const {
  const TargetInstrInfo &TII = *BB->getParent()->getSubtarget().getInstrInfo();
  const DebugLoc &DL = MI.getDebugLoc();
  Register Dst = MI.getOperand(0).getReg();
  Register Dividend = MI.getOperand(1).getReg();
  Register Divisor = MI.getOperand(2).getReg();

  BuildMI(*BB, MI, DL, TII.get(TargetOpcode::COPY), CPU6::rB).addReg(Dividend);
  BuildMI(*BB, MI, DL, TII.get(CPU6::DIVB)).addReg(Divisor);
  BuildMI(*BB, MI, DL, TII.get(TargetOpcode::COPY), Dst).addReg(CPU6::rB);
  MI.eraseFromParent();
  return BB;
}

// i16 mul. One operand is copied into B. MULB multiplies B by the other
// operand and writes the low half back to B. A is not written.
MachineBasicBlock *
CPU6TargetLowering::EmitMulLow(MachineInstr &MI, MachineBasicBlock *BB) const {
  const TargetInstrInfo &TII = *BB->getParent()->getSubtarget().getInstrInfo();
  const DebugLoc &DL = MI.getDebugLoc();
  Register Dst = MI.getOperand(0).getReg();
  Register A = MI.getOperand(1).getReg();
  Register B = MI.getOperand(2).getReg();

  BuildMI(*BB, MI, DL, TII.get(TargetOpcode::COPY), CPU6::rB).addReg(B);
  BuildMI(*BB, MI, DL, TII.get(CPU6::MULB)).addReg(A);
  BuildMI(*BB, MI, DL, TII.get(TargetOpcode::COPY), Dst).addReg(CPU6::rB);
  MI.eraseFromParent();
  return BB;
}

// i16 umul_lohi. One operand is copied into A. MULAB multiplies A by the
// other operand, writes the high half back to A, and writes the low half
// to B. A and B are fixed registers, so a 32-bit or 64-bit multiply can
// use several of these in one function without a pair register class.
// The low half is copied out of B before the high half is copied out of A.
MachineBasicBlock *
CPU6TargetLowering::EmitMulLoHi(MachineInstr &MI,
                                MachineBasicBlock *BB) const {
  const TargetInstrInfo &TII = *BB->getParent()->getSubtarget().getInstrInfo();
  const DebugLoc &DL = MI.getDebugLoc();
  Register Lo = MI.getOperand(0).getReg();
  Register Hi = MI.getOperand(1).getReg();
  Register A = MI.getOperand(2).getReg();
  Register B = MI.getOperand(3).getReg();

  BuildMI(*BB, MI, DL, TII.get(TargetOpcode::COPY), CPU6::rA).addReg(A);
  BuildMI(*BB, MI, DL, TII.get(CPU6::MULAB)).addReg(B);
  BuildMI(*BB, MI, DL, TII.get(TargetOpcode::COPY), Lo).addReg(CPU6::rB);
  BuildMI(*BB, MI, DL, TII.get(TargetOpcode::COPY), Hi).addReg(CPU6::rA);

  MI.eraseFromParent();
  return BB;
}

// memcpy, memmove, and memset. A constant size is one MVF or FIL per 256
// bytes. A run-time size, or a constant past MaxBlocks of them, is the
// MEMCPY_LOOP or MEMSET_LOOP pseudo (EmitMemLoop). Copies of one or two bytes
// never get here: MaxStoresPerMemcpy and friends leave them to a load and a
// store.

// MVF and FIL take count-1 in a byte.
static constexpr uint64_t BlockBytes = 256;
// Each MVF is four bytes and FIL five, plus an ADD to form each address past
// the first block. The loop is about 30 bytes.
static constexpr uint64_t MaxBlocks = 4;

static bool fitsInBlocks(uint64_t Size) {
  return Size <= MaxBlocks * BlockBytes;
}

// The copy runs from the lowest address up, one byte at a time, so a
// destination one byte above the source repeats the first byte. memset
// depends on that.
static SDValue copyBlocks(SelectionDAG &DAG, const SDLoc &DL, SDValue Chain,
                          SDValue Src, SDValue Dst, uint64_t Size) {
  for (uint64_t Off = 0; Off < Size; Off += BlockBytes) {
    uint64_t N = std::min(BlockBytes, Size - Off);
    SDValue S = DAG.getMemBasePlusOffset(Src, TypeSize::getFixed(Off), DL);
    SDValue D = DAG.getMemBasePlusOffset(Dst, TypeSize::getFixed(Off), DL);
    Chain = DAG.getNode(CPU6ISD::BLK_COPY, DL, MVT::Other, Chain, S, D,
                        DAG.getTargetConstant(N - 1, DL, MVT::i8));
  }
  return Chain;
}

static SDValue fillBlocks(SelectionDAG &DAG, const SDLoc &DL, SDValue Chain,
                          uint8_t Byte, SDValue Dst, uint64_t Size) {
  for (uint64_t Off = 0; Off < Size; Off += BlockBytes) {
    uint64_t N = std::min(BlockBytes, Size - Off);
    SDValue D = DAG.getMemBasePlusOffset(Dst, TypeSize::getFixed(Off), DL);
    Chain = DAG.getNode(CPU6ISD::BLK_FILL, DL, MVT::Other, Chain,
                        DAG.getTargetConstant(Byte, DL, MVT::i8), D,
                        DAG.getTargetConstant(N - 1, DL, MVT::i8));
  }
  return Chain;
}

SDValue CPU6SelectionDAGInfo::EmitTargetCodeForMemcpy(
    SelectionDAG &DAG, const SDLoc &DL, SDValue Chain, SDValue Dst,
    SDValue Src, SDValue Size, Align, Align, bool, bool, MachinePointerInfo,
    MachinePointerInfo) const {
  if (auto *C = dyn_cast<ConstantSDNode>(Size))
    if (fitsInBlocks(C->getZExtValue()))
      return copyBlocks(DAG, DL, Chain, Src, Dst, C->getZExtValue());
  return DAG.getNode(CPU6ISD::MEMCPY_LOOP, DL, MVT::Other, Chain, Src, Dst,
                     DAG.getZExtOrTrunc(Size, DL, MVT::i16));
}

// A pointer as a base and a constant offset from it.
static std::pair<SDValue, int64_t> splitConstantOffset(SDValue Ptr,
                                                       SelectionDAG &DAG) {
  int64_t Off = 0;
  while (DAG.isBaseWithConstantOffset(Ptr)) {
    Off += cast<ConstantSDNode>(Ptr.getOperand(1))->getSExtValue();
    Ptr = Ptr.getOperand(0);
  }
  return {Ptr, Off};
}

// Two different stack slots, or two different global variables, never
// share a byte.
static bool distinctObjects(SDValue A, SDValue B) {
  if (auto *FA = dyn_cast<FrameIndexSDNode>(A))
    if (auto *FB = dyn_cast<FrameIndexSDNode>(B))
      return FA->getIndex() != FB->getIndex();
  auto *GA = dyn_cast<GlobalAddressSDNode>(A);
  auto *GB = dyn_cast<GlobalAddressSDNode>(B);
  return GA && GB && GA->getGlobal() != GB->getGlobal() &&
         isa<GlobalVariable>(GA->getGlobal()) &&
         isa<GlobalVariable>(GB->getGlobal());
}

// An ascending copy is a memmove when the destination does not start above
// the source inside it: the same base with the destination at or below the
// source, or two objects that cannot overlap. Otherwise MEMMOVE_LOOP picks
// the direction at run time. There is no memmove to call.
SDValue CPU6SelectionDAGInfo::EmitTargetCodeForMemmove(
    SelectionDAG &DAG, const SDLoc &DL, SDValue Chain, SDValue Dst,
    SDValue Src, SDValue Size, Align DstAlign, Align SrcAlign,
    bool IsVolatile, MachinePointerInfo DstPtrInfo,
    MachinePointerInfo SrcPtrInfo) const {
  auto [DstBase, DstOff] = splitConstantOffset(Dst, DAG);
  auto [SrcBase, SrcOff] = splitConstantOffset(Src, DAG);
  bool Forward = DstBase == SrcBase ? DstOff <= SrcOff
                                    : distinctObjects(DstBase, SrcBase);
  if (!Forward)
    return DAG.getNode(CPU6ISD::MEMMOVE_LOOP, DL, MVT::Other, Chain, Src, Dst,
                       DAG.getZExtOrTrunc(Size, DL, MVT::i16));
  return EmitTargetCodeForMemcpy(DAG, DL, Chain, Dst, Src, Size, DstAlign,
                                 SrcAlign, IsVolatile, /*AlwaysInline=*/false,
                                 DstPtrInfo, SrcPtrInfo);
}

// A constant byte is FIL. Otherwise the byte is stored at Dst and copied
// forward from Dst to Dst + 1.
SDValue CPU6SelectionDAGInfo::EmitTargetCodeForMemset(
    SelectionDAG &DAG, const SDLoc &DL, SDValue Chain, SDValue Dst,
    SDValue Val, SDValue Size, Align, bool, bool,
    MachinePointerInfo DstPtrInfo) const {
  Val = DAG.getZExtOrTrunc(Val, DL, MVT::i8);
  auto *C = dyn_cast<ConstantSDNode>(Size);
  if (!C || !fitsInBlocks(C->getZExtValue()))
    return DAG.getNode(CPU6ISD::MEMSET_LOOP, DL, MVT::Other, Chain, Dst, Val,
                       DAG.getZExtOrTrunc(Size, DL, MVT::i16));
  uint64_t N = C->getZExtValue();
  if (auto *B = dyn_cast<ConstantSDNode>(Val))
    return fillBlocks(DAG, DL, Chain, B->getZExtValue(), Dst, N);
  Chain = DAG.getStore(Chain, DL, Val, Dst, DstPtrInfo);
  if (N == 1)
    return Chain;
  SDValue Next = DAG.getMemBasePlusOffset(Dst, TypeSize::getFixed(1), DL);
  return copyBlocks(DAG, DL, Chain, Dst, Next, N - 1);
}

// Copies N bytes from Src to Dst, lowest address first, between Pre and Exit.
// Pre ends with the zero test. MVFR copies AL + 1 bytes and leaves its
// registers alone, so each pass sets AL, then steps both pointers by 256:
//
//   Pre:  TST n; BZ Exit
//   Loop: SUB n,256 (flags of 256 - n); BL Last
//   Big:  AL = 255; MVFR s,d; s += 256; d += 256; n -= 256; JMP Loop
//   Last: AL = n - 1; MVFR s,d
//
// Under optsize it is a byte loop instead, about 12 bytes against 30, at
// roughly 73 microcycles a byte against 8:
//
//   Pre:  TST n; BZ Exit
//   Loop: LDAB_I (s); STAB_I (d); DCR n; TST n; BNZ Loop
//
// TestZero is false when the caller already knows n is not zero.
static void emitCopyLoop(MachineBasicBlock *Pre, MachineBasicBlock *Exit,
                         Register Src, Register Dst, Register N,
                         const DebugLoc &DL, bool TestZero = true) {
  MachineFunction *MF = Pre->getParent();
  MachineRegisterInfo &MRI = MF->getRegInfo();
  const TargetInstrInfo &TII = *MF->getSubtarget().getInstrInfo();
  auto NewReg = [&] { return MRI.createVirtualRegister(&CPU6::GPRRegClass); };
  auto NewBlock = [&] {
    MachineBasicBlock *B = MF->CreateMachineBasicBlock(Pre->getBasicBlock());
    MF->insert(Exit->getIterator(), B);
    return B;
  };

  // TST is a terminator, so a later copy cannot land between it and the branch.
  if (TestZero) {
    BuildMI(Pre, DL, TII.get(CPU6::TST)).addReg(N);
    BuildMI(Pre, DL, TII.get(CPU6::BZ)).addMBB(Exit);
    Pre->addSuccessor(Exit);
  }
  MachineBasicBlock *Loop = NewBlock();
  Pre->addSuccessor(Loop);
  Register S = NewReg(), D = NewReg(), M = NewReg();

  if (MF->getFunction().hasOptSize()) {
    Register S2 = NewReg(), D2 = NewReg(), M2 = NewReg();
    BuildMI(Loop, DL, TII.get(TargetOpcode::PHI), S)
        .addReg(Src).addMBB(Pre).addReg(S2).addMBB(Loop);
    BuildMI(Loop, DL, TII.get(TargetOpcode::PHI), D)
        .addReg(Dst).addMBB(Pre).addReg(D2).addMBB(Loop);
    BuildMI(Loop, DL, TII.get(TargetOpcode::PHI), M)
        .addReg(N).addMBB(Pre).addReg(M2).addMBB(Loop);
    BuildMI(Loop, DL, TII.get(CPU6::LDAB_5_1), S2).addReg(S);
    BuildMI(Loop, DL, TII.get(CPU6::STAB_5_1), D2).addReg(D);
    BuildMI(Loop, DL, TII.get(CPU6::DCR), M2).addReg(M).addImm(0);
    BuildMI(Loop, DL, TII.get(CPU6::TST)).addReg(M2);
    BuildMI(Loop, DL, TII.get(CPU6::BNZ)).addMBB(Loop);
    Loop->addSuccessor(Loop);
    Loop->addSuccessor(Exit);
    return;
  }

  MachineBasicBlock *Big = NewBlock();
  MachineBasicBlock *Last = NewBlock();
  Register S2 = NewReg(), D2 = NewReg(), M2 = NewReg();
  BuildMI(Loop, DL, TII.get(TargetOpcode::PHI), S)
      .addReg(Src).addMBB(Pre).addReg(S2).addMBB(Big);
  BuildMI(Loop, DL, TII.get(TargetOpcode::PHI), D)
      .addReg(Dst).addMBB(Pre).addReg(D2).addMBB(Big);
  BuildMI(Loop, DL, TII.get(TargetOpcode::PHI), M)
      .addReg(N).addMBB(Pre).addReg(M2).addMBB(Big);
  // Link set is no borrow: n <= 256 fits in one MVFR.
  BuildMI(Loop, DL, TII.get(CPU6::CMPimm), NewReg()).addReg(M).addImm(256);
  BuildMI(Loop, DL, TII.get(CPU6::BL)).addMBB(Last);
  Loop->addSuccessor(Big);
  Loop->addSuccessor(Last);

  Register Full = NewReg();
  BuildMI(Big, DL, TII.get(CPU6::XFRimm), Full).addImm(255);
  BuildMI(Big, DL, TII.get(TargetOpcode::COPY), CPU6::rA).addReg(Full);
  BuildMI(Big, DL, TII.get(CPU6::MVFR)).addReg(S).addReg(D);
  BuildMI(Big, DL, TII.get(CPU6::ADDimm), S2).addReg(S).addImm(256);
  BuildMI(Big, DL, TII.get(CPU6::ADDimm), D2).addReg(D).addImm(256);
  BuildMI(Big, DL, TII.get(CPU6::ADDimm), M2).addReg(M).addImm(-256);
  BuildMI(Big, DL, TII.get(CPU6::JMP_3)).addMBB(Loop);
  Big->addSuccessor(Loop);

  Register Count = NewReg();
  BuildMI(Last, DL, TII.get(CPU6::ADDimm), Count).addReg(M).addImm(-1);
  BuildMI(Last, DL, TII.get(TargetOpcode::COPY), CPU6::rA).addReg(Count);
  BuildMI(Last, DL, TII.get(CPU6::MVFR)).addReg(S).addReg(D);
  Last->addSuccessor(Exit);
}

// A memmove whose destination may start inside the source, above it:
//
//   BB:   TST n; BZ Exit
//   Dir:  CMP s,d; BL Fwd (s >= d)
//   Bwd:  s += n; d += n
//   Back: LDAB_D (s); STAB_D (d); DCR n; TST n; BNZ Back; JMP Exit
//   Fwd:  the copy loop
static void emitMoveLoop(MachineBasicBlock *BB, MachineBasicBlock *Exit,
                         Register Src, Register Dst, Register N,
                         const DebugLoc &DL) {
  MachineFunction *MF = BB->getParent();
  MachineRegisterInfo &MRI = MF->getRegInfo();
  const TargetInstrInfo &TII = *MF->getSubtarget().getInstrInfo();
  auto NewReg = [&] { return MRI.createVirtualRegister(&CPU6::GPRRegClass); };
  auto NewBlock = [&] {
    MachineBasicBlock *B = MF->CreateMachineBasicBlock(BB->getBasicBlock());
    MF->insert(Exit->getIterator(), B);
    return B;
  };
  MachineBasicBlock *Dir = NewBlock();
  MachineBasicBlock *Bwd = NewBlock();
  MachineBasicBlock *Back = NewBlock();
  MachineBasicBlock *Fwd = NewBlock();

  BuildMI(BB, DL, TII.get(CPU6::TST)).addReg(N);
  BuildMI(BB, DL, TII.get(CPU6::BZ)).addMBB(Exit);
  BB->addSuccessor(Dir);
  BB->addSuccessor(Exit);

  // Link set is no borrow: s >= d, so the ascending copy reads every byte
  // before it is overwritten.
  BuildMI(Dir, DL, TII.get(CPU6::CMP), NewReg()).addReg(Src).addReg(Dst);
  BuildMI(Dir, DL, TII.get(CPU6::BL)).addMBB(Fwd);
  Dir->addSuccessor(Bwd);
  Dir->addSuccessor(Fwd);

  Register SEnd = NewReg(), DEnd = NewReg();
  BuildMI(Bwd, DL, TII.get(CPU6::ADD), SEnd).addReg(N).addReg(Src);
  BuildMI(Bwd, DL, TII.get(CPU6::ADD), DEnd).addReg(N).addReg(Dst);
  Bwd->addSuccessor(Back);

  Register S = NewReg(), D = NewReg(), M = NewReg();
  Register S2 = NewReg(), D2 = NewReg(), M2 = NewReg();
  BuildMI(Back, DL, TII.get(TargetOpcode::PHI), S)
      .addReg(SEnd).addMBB(Bwd).addReg(S2).addMBB(Back);
  BuildMI(Back, DL, TII.get(TargetOpcode::PHI), D)
      .addReg(DEnd).addMBB(Bwd).addReg(D2).addMBB(Back);
  BuildMI(Back, DL, TII.get(TargetOpcode::PHI), M)
      .addReg(N).addMBB(Bwd).addReg(M2).addMBB(Back);
  BuildMI(Back, DL, TII.get(CPU6::LDAB_5_2), S2).addReg(S);
  BuildMI(Back, DL, TII.get(CPU6::STAB_5_2), D2).addReg(D);
  BuildMI(Back, DL, TII.get(CPU6::DCR), M2).addReg(M).addImm(0);
  BuildMI(Back, DL, TII.get(CPU6::TST)).addReg(M2);
  BuildMI(Back, DL, TII.get(CPU6::BNZ)).addMBB(Back);
  BuildMI(Back, DL, TII.get(CPU6::JMP_3)).addMBB(Exit);
  Back->addSuccessor(Back);
  Back->addSuccessor(Exit);

  emitCopyLoop(Fwd, Exit, Src, Dst, N, DL, /*TestZero=*/false);
}

// MEMCPYLOOP src,dst,n, MEMMOVELOOP src,dst,n, and MEMSETLOOP dst,byte,n.
// memset with n != 0 stores the byte at dst, then copies n - 1 bytes from dst
// to dst + 1: the copy reads each byte after it was written, so the first one
// repeats.
MachineBasicBlock *
CPU6TargetLowering::EmitMemLoop(MachineInstr &MI, MachineBasicBlock *BB) const {
  MachineFunction *MF = BB->getParent();
  MachineRegisterInfo &MRI = MF->getRegInfo();
  const TargetInstrInfo &TII = *MF->getSubtarget().getInstrInfo();
  const DebugLoc &DL = MI.getDebugLoc();

  MachineBasicBlock *Exit = MF->CreateMachineBasicBlock(BB->getBasicBlock());
  MF->insert(std::next(BB->getIterator()), Exit);
  Exit->splice(Exit->begin(), BB, std::next(MI.getIterator()), BB->end());
  Exit->transferSuccessorsAndUpdatePHIs(BB);

  if (MI.getOpcode() != CPU6::MEMSETLOOP) {
    Register Src = MI.getOperand(0).getReg();
    Register Dst = MI.getOperand(1).getReg();
    Register N = MI.getOperand(2).getReg();
    if (MI.getOpcode() == CPU6::MEMCPYLOOP)
      emitCopyLoop(BB, Exit, Src, Dst, N, DL);
    else
      emitMoveLoop(BB, Exit, Src, Dst, N, DL);
    MI.eraseFromParent();
    return Exit;
  }

  Register Dst = MI.getOperand(0).getReg();
  Register N = MI.getOperand(2).getReg();
  BuildMI(BB, DL, TII.get(CPU6::TST)).addReg(N);
  BuildMI(BB, DL, TII.get(CPU6::BZ)).addMBB(Exit);
  MachineBasicBlock *Head = MF->CreateMachineBasicBlock(BB->getBasicBlock());
  MF->insert(Exit->getIterator(), Head);
  BB->addSuccessor(Head);
  BB->addSuccessor(Exit);

  Register Byte = MRI.createVirtualRegister(&CPU6::AccBRegClass);
  BuildMI(Head, DL, TII.get(TargetOpcode::COPY), Byte)
      .addReg(MI.getOperand(1).getReg());
  BuildMI(Head, DL, TII.get(CPU6::STABfi))
      .addReg(Byte)
      .addReg(Dst)
      .addImm(0);
  Register Next = MRI.createVirtualRegister(&CPU6::GPRRegClass);
  Register Rest = MRI.createVirtualRegister(&CPU6::GPRRegClass);
  BuildMI(Head, DL, TII.get(CPU6::ADDimm), Next).addReg(Dst).addImm(1);
  BuildMI(Head, DL, TII.get(CPU6::ADDimm), Rest).addReg(N).addImm(-1);
  emitCopyLoop(Head, Exit, Dst, Next, Rest, DL);
  MI.eraseFromParent();
  return Exit;
}

// A variable shift of N words. N is the number of explicit defs, so an i32
// and an i64 (and any later width with the same operand shape) share this.
// Whole words move first, at most N - 1 times, and the leftover 0..15 bits
// are a Link-carry loop. RLR and RRR shift the old Link in and the bit that
// leaves the word into Link. SLR and SRR do not read Link, so they cannot
// carry into the next word; SRR is only the sign-filling step of an
// arithmetic shift, and the bit it writes to Link is what the following RRR
// shifts in. XFR leaves Link alone, so the two-address copy in front of a
// rotate does not drop the carry. DCR replaces Link, so the count steps
// after the chain.
MachineBasicBlock *
CPU6TargetLowering::EmitWideShift(MachineInstr &MI,
                                  MachineBasicBlock *BB) const {
  MachineFunction *MF = BB->getParent();
  MachineRegisterInfo &MRI = MF->getRegInfo();
  const TargetInstrInfo &TII = *MF->getSubtarget().getInstrInfo();
  const DebugLoc &DL = MI.getDebugLoc();
  const TargetRegisterClass *RC = &CPU6::GPRRegClass;

  unsigned N = MI.getNumExplicitDefs();
  unsigned Kind = MI.getOperand(2 * N + 1).getImm();
  bool Left = Kind == WShiftLeft;
  bool Arith = Kind == WShiftARight;
  Register Cnt = MI.getOperand(2 * N).getReg();

  SmallVector<Register, 4> Src(N), Dst(N);
  for (unsigned I = 0; I != N; ++I) {
    Dst[I] = MI.getOperand(I).getReg();
    Src[I] = MI.getOperand(N + I).getReg();
  }

  auto VReg = [&]() { return MRI.createVirtualRegister(RC); };
  auto Phi = [&](MachineBasicBlock *At, Register R, Register A,
                 MachineBasicBlock *FromA, Register B, MachineBasicBlock *FromB) {
    BuildMI(*At, At->begin(), DL, TII.get(TargetOpcode::PHI), R)
        .addReg(A)
        .addMBB(FromA)
        .addReg(B)
        .addMBB(FromB);
  };

  Register Masked = VReg();
  Register Bits = VReg();
  Register Words = VReg();
  BuildMI(*BB, MI, DL, TII.get(CPU6::ANDimm), Masked)
      .addReg(Cnt)
      .addImm((N * 16) - 1);
  BuildMI(*BB, MI, DL, TII.get(CPU6::ANDimm), Bits).addReg(Masked).addImm(15);
  // SRR's count nibble is the distance minus one, so 3 shifts by 4.
  BuildMI(*BB, MI, DL, TII.get(CPU6::SRR), Words).addReg(Masked).addImm(3);

  Register Sign;
  if (Arith) {
    Sign = VReg();
    // 14 shifts by 15 and leaves the sign in every bit.
    BuildMI(*BB, MI, DL, TII.get(CPU6::SRR), Sign).addReg(Src[N - 1]).addImm(14);
  }

  MachineFunction::iterator It = std::next(BB->getIterator());
  MachineBasicBlock *Word = MF->CreateMachineBasicBlock(BB->getBasicBlock());
  MachineBasicBlock *Join = MF->CreateMachineBasicBlock(BB->getBasicBlock());
  MachineBasicBlock *Bit = MF->CreateMachineBasicBlock(BB->getBasicBlock());
  MachineBasicBlock *Exit = MF->CreateMachineBasicBlock(BB->getBasicBlock());
  MF->insert(It, Word);
  MF->insert(It, Join);
  MF->insert(It, Bit);
  MF->insert(It, Exit);
  Exit->splice(Exit->begin(), BB, std::next(MI.getIterator()), BB->end());
  Exit->transferSuccessorsAndUpdatePHIs(BB);
  BB->addSuccessor(Word);
  BB->addSuccessor(Join);
  Word->addSuccessor(Word);
  Word->addSuccessor(Join);
  Join->addSuccessor(Bit);
  Join->addSuccessor(Exit);
  Bit->addSuccessor(Bit);
  Bit->addSuccessor(Exit);

  // A word count of zero falls through the bit join. The bit count does the
  // same for the exit. TST is a terminator, so it stays the last instruction.
  BuildMI(*BB, MI, DL, TII.get(CPU6::TST)).addReg(Words);
  BuildMI(*BB, MI, DL, TII.get(CPU6::BZ)).addMBB(Join);

  SmallVector<Register, 4> WCur(N), WNext(N), AtJoin(N), BCur(N), BNext(N);
  Register WordsPhi = VReg();
  Register WordsDec = VReg();
  for (unsigned I = 0; I != N; ++I) {
    WCur[I] = VReg();
    WNext[I] = VReg();
    AtJoin[I] = VReg();
    BCur[I] = VReg();
    BNext[I] = VReg();
    Phi(Word, WCur[I], Src[I], BB, WNext[I], Word);
    Phi(Join, AtJoin[I], Src[I], BB, WNext[I], Word);
    Phi(Bit, BCur[I], AtJoin[I], Join, BNext[I], Bit);
    Phi(Exit, Dst[I], AtJoin[I], Join, BNext[I], Bit);
  }
  Phi(Word, WordsPhi, Words, BB, WordsDec, Word);

  // High index first on a left move, so the word shifted out dies before the
  // hole at the low end is filled. A right move writes the low index first.
  if (Left) {
    for (unsigned I = N; I-- > 1;)
      BuildMI(Word, DL, TII.get(TargetOpcode::COPY), WNext[I]).addReg(WCur[I - 1]);
    BuildMI(Word, DL, TII.get(CPU6::CLR), WNext[0]).addImm(0);
  } else {
    for (unsigned I = 0; I + 1 < N; ++I)
      BuildMI(Word, DL, TII.get(TargetOpcode::COPY), WNext[I]).addReg(WCur[I + 1]);
    if (Arith)
      BuildMI(Word, DL, TII.get(TargetOpcode::COPY), WNext[N - 1]).addReg(Sign);
    else
      BuildMI(Word, DL, TII.get(CPU6::CLR), WNext[N - 1]).addImm(0);
  }
  BuildMI(Word, DL, TII.get(CPU6::DCR), WordsDec).addReg(WordsPhi).addImm(0);
  BuildMI(Word, DL, TII.get(CPU6::TST)).addReg(WordsDec);
  BuildMI(Word, DL, TII.get(CPU6::BNZ)).addMBB(Word);

  BuildMI(Join, DL, TII.get(CPU6::TST)).addReg(Bits);
  BuildMI(Join, DL, TII.get(CPU6::BZ)).addMBB(Exit);

  Register BitsPhi = VReg();
  Register BitsDec = VReg();
  Phi(Bit, BitsPhi, Bits, Join, BitsDec, Bit);

  // Carry travels low to high on a left shift and high to low on a right
  // shift. RL clears Link so the end word shifts a zero in. An arithmetic
  // step sign-fills that word with SRR, which also plants its old low bit
  // in Link for the RRR that follows.
  if (!Arith)
    BuildMI(Bit, DL, TII.get(CPU6::RL));
  if (Left) {
    for (unsigned I = 0; I != N; ++I)
      BuildMI(Bit, DL, TII.get(CPU6::RLR), BNext[I]).addReg(BCur[I]).addImm(0);
  } else {
    unsigned Top = N - 1;
    BuildMI(Bit, DL, TII.get(Arith ? CPU6::SRR : CPU6::RRR), BNext[Top])
        .addReg(BCur[Top])
        .addImm(0);
    for (unsigned I = Top; I-- > 0;)
      BuildMI(Bit, DL, TII.get(CPU6::RRR), BNext[I]).addReg(BCur[I]).addImm(0);
  }
  BuildMI(Bit, DL, TII.get(CPU6::DCR), BitsDec).addReg(BitsPhi).addImm(0);
  BuildMI(Bit, DL, TII.get(CPU6::TST)).addReg(BitsDec);
  BuildMI(Bit, DL, TII.get(CPU6::BNZ)).addMBB(Bit);

  MI.eraseFromParent();
  return Exit;
}

// A variable shift. The count is a nibble in the instruction, so SLR, SRR,
// and RRR cannot take a register, and the pseudo becomes a one-bit loop. A
// constant count never reaches here: it is one SLR or SRR, or, for a logical
// right shift, one SRR plus a mask. A longer RRR rotates the shifted-out bits
// back through Link, so only a one-bit rotate with Link clear is logical.
MachineBasicBlock *
CPU6TargetLowering::EmitShift(MachineInstr &MI, MachineBasicBlock *BB) const {
  MachineFunction *MF = BB->getParent();
  MachineRegisterInfo &MRI = MF->getRegInfo();
  const TargetInstrInfo &TII = *MF->getSubtarget().getInstrInfo();
  const DebugLoc &DL = MI.getDebugLoc();
  Register Dst = MI.getOperand(0).getReg();
  Register Src = MI.getOperand(1).getReg();
  Register Cnt = MI.getOperand(2).getReg();

  // A count nibble of 0 is a shift of one. A logical step is RRR or RRRB:
  // with Link clear, that shifts a zero in.
  bool Byte = false;
  bool Logical = false;
  unsigned ShiftOpc = 0;
  switch (MI.getOpcode()) {
  case CPU6::SHLrr:
    ShiftOpc = CPU6::SLR;
    break;
  case CPU6::SRArr:
    ShiftOpc = CPU6::SRR;
    break;
  case CPU6::SRLrr:
    ShiftOpc = CPU6::RRR;
    Logical = true;
    break;
  case CPU6::SHLbr:
    ShiftOpc = CPU6::SLRB;
    Byte = true;
    break;
  case CPU6::SRAbr:
    ShiftOpc = CPU6::SRRB;
    Byte = true;
    break;
  case CPU6::SRLbr:
    ShiftOpc = CPU6::RRRB;
    Byte = true;
    Logical = true;
    break;
  default:
    llvm_unreachable("not a CPU6 shift pseudo");
  }

  const TargetRegisterClass *ValRC =
      Byte ? &CPU6::GPRBRegClass : &CPU6::GPRRegClass;
  Register ValPhi = MRI.createVirtualRegister(ValRC);
  Register CntPhi = MRI.createVirtualRegister(&CPU6::GPRRegClass);
  Register CntDec = MRI.createVirtualRegister(&CPU6::GPRRegClass);
  Register ValNext = MRI.createVirtualRegister(ValRC);

  // The block falls into the loop when the count is not zero, and the loop
  // falls out to Rem when the decremented count is. Rem keeps whatever
  // followed the pseudo.
  MachineFunction::iterator It = std::next(BB->getIterator());
  MachineBasicBlock *Loop = MF->CreateMachineBasicBlock(BB->getBasicBlock());
  MachineBasicBlock *Rem = MF->CreateMachineBasicBlock(BB->getBasicBlock());
  MF->insert(It, Loop);
  MF->insert(It, Rem);
  Rem->splice(Rem->begin(), BB, std::next(MI.getIterator()), BB->end());
  Rem->transferSuccessorsAndUpdatePHIs(BB);
  BB->addSuccessor(Loop);
  BB->addSuccessor(Rem);
  Loop->addSuccessor(Loop);
  Loop->addSuccessor(Rem);

  // TST is a terminator, so a later copy cannot land between it and the branch.
  BuildMI(BB, DL, TII.get(CPU6::TST)).addReg(Cnt);
  BuildMI(BB, DL, TII.get(CPU6::BZ)).addMBB(Rem);

  BuildMI(Loop, DL, TII.get(TargetOpcode::PHI), ValPhi)
      .addReg(Src)
      .addMBB(BB)
      .addReg(ValNext)
      .addMBB(Loop);
  BuildMI(Loop, DL, TII.get(TargetOpcode::PHI), CntPhi)
      .addReg(Cnt)
      .addMBB(BB)
      .addReg(CntDec)
      .addMBB(Loop);

  // RL clears Link so the rotate shifts in a zero. It has to sit in front of
  // RRR: DCR replaces Link, and a copy writes only Minus and Value, so one
  // can land between them without setting the bit the rotate shifts in.
  if (Logical)
    BuildMI(Loop, DL, TII.get(CPU6::RL));
  BuildMI(Loop, DL, TII.get(ShiftOpc), ValNext).addReg(ValPhi).addImm(0);

  // The shift replaced the flags, so the loop test is a TST of the new count,
  // again a terminator glued to its branch.
  BuildMI(Loop, DL, TII.get(CPU6::DCR), CntDec).addReg(CntPhi).addImm(0);
  BuildMI(Loop, DL, TII.get(CPU6::TST)).addReg(CntDec);
  BuildMI(Loop, DL, TII.get(CPU6::BNZ)).addMBB(Loop);

  // A count of zero skips the loop, so the result is the original value.
  // Otherwise it is the last one-bit step.
  BuildMI(*Rem, Rem->begin(), DL, TII.get(TargetOpcode::PHI), Dst)
      .addReg(Src)
      .addMBB(BB)
      .addReg(ValNext)
      .addMBB(Loop);
  MI.eraseFromParent();
  return Rem;
}
