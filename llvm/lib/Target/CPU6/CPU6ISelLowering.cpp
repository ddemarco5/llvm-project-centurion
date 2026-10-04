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
  }
  setOperationAction(ISD::BRCOND, MVT::Other, Expand);
  // Nothing selects a jump table, so a switch is a tree of compares.
  setMinimumJumpTableEntries(UINT_MAX);
  // S is the stack pointer the prologue adjusts. Callee-saved spills go
  // through it via STK and POP.
  setStackPointerRegisterToSaveRestore(CPU6::rS);

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

} // namespace

// store (load Src), Dest            -> ZAD
// store (add/sub (load Dest), (load Src)), Dest  -> BNA / BNS
// The result is Dest := Dest op Src, so Src - Dest is not folded.
SDValue CPU6TargetLowering::combineBignumStore(StoreSDNode *St,
                                               SelectionDAG &DAG) const {
  EVT VT = St->getMemoryVT();
  auto Len = bignumLenMinus1(VT);
  if (!Len || !St->isSimple() || St->isIndexed() || St->isTruncatingStore())
    return SDValue();

  SDValue Val = St->getValue();
  unsigned Opc;
  LoadSDNode *Src;
  SmallVector<LoadSDNode *, 2> Loads;
  if (LoadSDNode *Ld = getBignumLoad(Val, VT)) {
    Opc = CPU6ISD::BN_MOV;
    Src = Ld;
    Loads = {Ld};
  } else if (Val.getOpcode() == ISD::ADD || Val.getOpcode() == ISD::SUB) {
    LoadSDNode *L0 = getBignumLoad(Val.getOperand(0), VT);
    LoadSDNode *L1 = getBignumLoad(Val.getOperand(1), VT);
    if (!L0 || !L1)
      return SDValue();
    bool IsAdd = Val.getOpcode() == ISD::ADD;
    if (addressDelta(L0, St, DAG) == 0)
      Src = L1;
    else if (IsAdd && addressDelta(L1, St, DAG) == 0)
      Src = L0;
    else
      return SDValue();
    Opc = IsAdd ? CPU6ISD::BN_ADD : CPU6ISD::BN_SUB;
    Loads = {L0, L1};
  } else {
    return SDValue();
  }

  if (!loadsShareMemoryState(Loads) ||
      !onlyLoadsJoinChain(St->getChain(), Loads[0]->getChain()))
    return SDValue();

  // The instruction works a byte at a time. That equals load-then-store unless
  // Src and Dest overlap partly, which two accesses off one base can show.
  // Unrelated pointers are taken to be identical or disjoint, as for memcpy.
  int64_t Bytes = VT.getStoreSize().getFixedValue();
  std::optional<int64_t> Delta = addressDelta(Src, St, DAG);
  if (Delta && *Delta != 0 && *Delta > -Bytes && *Delta < Bytes)
    return SDValue();

  SDLoc DL(St);
  return DAG.getNode(Opc, DL, MVT::Other, St->getChain(), Src->getBasePtr(),
                     St->getBasePtr(),
                     DAG.getTargetConstant(*Len, DL, MVT::i8));
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

SDValue CPU6TargetLowering::PerformDAGCombine(SDNode *N,
                                              DAGCombinerInfo &DCI) const {
  SelectionDAG &DAG = DCI.DAG;
  switch (N->getOpcode()) {
  case ISD::STORE:
    return combineBignumStore(cast<StoreSDNode>(N), DAG);
  case ISD::SETCC:
    return combineBignumSetCC(N, DAG);
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

MachineBasicBlock *
CPU6TargetLowering::EmitInstrWithCustomInserter(MachineInstr &MI,
                                                MachineBasicBlock *BB) const {
  switch (MI.getOpcode()) {
  case CPU6::SELECT:
  case CPU6::SELECTB:
    return EmitSelect(MI, BB);
  case CPU6::MULHUb:
    return EmitMulhu(MI, BB);
  case CPU6::MULrr:
    return EmitMulLow(MI, BB);
  case CPU6::DIVrr:
    return EmitDiv(MI, BB);
  case CPU6::MULlohi:
    return EmitMulLoHi(MI, BB);
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
