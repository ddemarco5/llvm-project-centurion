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
#include "llvm/IR/Function.h"

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
  setOperationAction(ISD::SIGN_EXTEND_INREG, MVT::i1, Expand);
  // A condition only exists in the flags, as a compare glued to the branch or
  // select that reads it. setcc and select become select_cc, brcond br_cc.
  for (MVT VT : {MVT::i8, MVT::i16}) {
    setOperationAction({ISD::BR_CC, ISD::SELECT_CC}, VT, Custom);
    setOperationAction({ISD::SETCC, ISD::SELECT}, VT, Expand);
  }
  setOperationAction(ISD::BRCOND, MVT::Other, Expand);
  // Nothing selects a jump table, so a switch is a tree of compares.
  setMinimumJumpTableEntries(UINT_MAX);
  // S is the stack pointer the prologue adjusts. Callee-saved spills go
  // through it via STK and POP.
  setStackPointerRegisterToSaveRestore(CPU6::rS);

  setBooleanContents(ZeroOrOneBooleanContent);
  setBooleanVectorContents(ZeroOrOneBooleanContent);
  // Keep the scheduled order close to the IR while the patterns are new.
  setSchedulingPreference(Sched::Source);
  setMinFunctionAlignment(Align(1));
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

SDValue CPU6TargetLowering::LowerOperation(SDValue Op,
                                           SelectionDAG &DAG) const {
  SDLoc DL(Op);
  unsigned Opc;
  switch (Op.getOpcode()) {
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
CPU6TargetLowering::EmitInstrWithCustomInserter(MachineInstr &MI,
                                                MachineBasicBlock *BB) const {
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
