//===-- CPU6ISelLowering.cpp - CPU6 DAG Lowering Implementation -*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CPU6ISelLowering.h"
#include "CPU6Subtarget.h"
#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "llvm/CodeGen/CallingConvLower.h"

using namespace llvm;

#define GET_CALLING_CONV_IMPL
#include "CPU6GenCallingConv.inc"

CPU6TargetLowering::CPU6TargetLowering(const TargetMachine &TM,
                                       const CPU6Subtarget &STI)
    : TargetLowering(TM, STI) {
  // GPR is i16. Registering it makes i16 legal and tells the legalizer to
  // expand anything wider (so an i32 add is not one instruction). i8 is left
  // illegal on purpose: it gets promoted to i16 until GPRB is registered.
  addRegisterClass(MVT::i16, &CPU6::GPRRegClass);
  computeRegisterProperties(STI.getRegisterInfo());

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
  if (Ins.empty())
    return Chain;

  // assign each incoming value and push one SDValue per argument
  // into InVals, in order.
  MachineFunction &MF = DAG.getMachineFunction();
  SmallVector<CCValAssign, 8> ArgLocs;
  CCState CCInfo(CallConv, IsVarArg, MF, ArgLocs, *DAG.getContext());
  CCInfo.AnalyzeFormalArguments(Ins, CC_CPU6);

  for (unsigned I = 0, E = ArgLocs.size(); I != E; ++I) {
    CCValAssign &VA = ArgLocs[I];
    if (!VA.isRegLoc())
      llvm_unreachable("stack arguments need a frame load");
    InVals.push_back(
        DAG.getCopyFromReg(Chain, DL, VA.getLocReg(), VA.getLocVT()));
  }
  return Chain;
  
  // CC_CPU6 comes from CPU6CallingConv.td. Include the generated function
  // with `#define GET_CALLING_CONV_IMPL` / `#include "CPU6GenCallingConv.inc"`
  // in this file. The register you name there is where the caller is expected
  // to have left the argument; this function only copies it into a virtual
  // register the body can use.
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
      Chain = DAG.getCopyToReg(Chain, DL, VA.getLocReg(), OutVals[I], Glue);
      Glue = Chain.getValue(1);
      RetOps.push_back(DAG.getRegister(VA.getLocReg(), VA.getLocVT()));
    }
    RetOps[0] = Chain;
    if (Glue.getNode())
      RetOps.push_back(Glue);
    return DAG.getNode(CPU6ISD::RET_GLUE, DL, MVT::Other, RetOps);
}

SDValue
CPU6TargetLowering::LowerCall(CallLoweringInfo &CLI,
                              SmallVectorImpl<SDValue> &InVals) const {
  // TODO(cpu6): a call. Not on the path for a leaf that only loads an
  // immediate and adds.
  (void)CLI;
  (void)InVals;
  llvm_unreachable("TODO(cpu6): CPU6TargetLowering::LowerCall");
}
