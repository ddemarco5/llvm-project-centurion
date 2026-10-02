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
#include "llvm/CodeGen/MachineMemOperand.h"

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

  // Bytes the caller writes above S. JSR's push of X is not part of this:
  // RSR pops it, and the callee finds the first word at incoming S + 2.
  unsigned NumBytes = CCInfo.getStackSize();
  SDValue Chain = DAG.getCALLSEQ_START(CLI.Chain, NumBytes, 0, DL);

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

  SDVTList NodeTys = DAG.getVTList(MVT::Other, MVT::Glue);
  SmallVector<SDValue, 8> Ops;
  Ops.push_back(Chain);
  Ops.push_back(Callee);
  for (const auto &[Reg, Val] : RegsToPass)
    Ops.push_back(DAG.getRegister(Reg, Val.getValueType()));
  const TargetRegisterInfo *TRI = DAG.getSubtarget().getRegisterInfo();
  Ops.push_back(DAG.getRegisterMask(
      TRI->getCallPreservedMask(DAG.getMachineFunction(), CLI.CallConv)));
  if (Glue)
    Ops.push_back(Glue);

  Chain = DAG.getNode(CPU6ISD::CALL, DL, NodeTys, Ops);
  Glue = Chain.getValue(1);
  Chain = DAG.getCALLSEQ_END(Chain, NumBytes, 0, Glue, DL);
  Glue = Chain.getValue(1);
  return LowerCallResult(Chain, Glue, CLI.CallConv, CLI.IsVarArg, CLI.Ins, DL,
                         DAG, InVals);
}
